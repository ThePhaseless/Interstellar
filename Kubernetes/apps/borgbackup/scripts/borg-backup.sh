#!/bin/sh
# Drives `borg create` / `borg prune` / `borg compact` against one shared repo.
#
# Required env (from borg-secrets): BORG_PASSPHRASE, BORG_REPO, BORG_SERVER_HOST.
# BORG_BACKUP_TARGETS takes one `prefix:path1 path2 ...` per line, so a single
# CronJob can back up several targets in one run.
#
# Optional env:
#   BORG_LEGACY_GLOBS     — space-separated extra `--glob-archives` patterns to
#                           keep pruning (for archive families renamed or split
#                           away). Example: "immich-*"
#   BORG_EXCLUDES         — space-separated extra exclude patterns applied to
#                           every target in this CronJob.
#   BORG_PATTERNS         — newline-separated `--patterns-from` lines (sh: style,
#                           first match wins). Unlike BORG_EXCLUDES this supports
#                           `+` include prefixes, e.g. "back up only X/safe under
#                           X": "+ X/safe + X/safe/** - X/**". Patterns match the
#                           archived paths, so no leading slash: the target
#                           /photos is archived as "photos/...".
#
# The pod must also mount /root/.cache/borg as an emptyDir for the borg cache.
set -eu

info() { printf '\n%s %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }

: "${BORG_PASSPHRASE:?BORG_PASSPHRASE required}"
: "${BORG_REPO:?BORG_REPO required}"
: "${BORG_SERVER_HOST:?BORG_SERVER_HOST required}"
: "${BORG_BACKUP_TARGETS:?BORG_BACKUP_TARGETS required (one 'prefix:path1 path2 ...' per line)}"

info "Installing borgbackup..."
apk add --no-cache borgbackup openssh-client >/dev/null 2>&1
borg --version

info "Configuring SSH..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cp /secrets/ssh/id_ed25519 ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
ssh-keyscan -p 23 "$BORG_SERVER_HOST" >>~/.ssh/known_hosts 2>/dev/null
chmod 644 ~/.ssh/known_hosts

cat >~/.ssh/config <<EOF
Host ${BORG_SERVER_HOST}
    Port 23
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
    ServerAliveInterval 30
    ServerAliveCountMax 5
EOF
chmod 600 ~/.ssh/config

export BORG_RSH="ssh -p 23 -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30"

# Every backup CronJob shares one repo, so an overrunning job holds the lock
# while the next one starts. Borg's default wait is 1s, which turns that
# overlap into a failed Job even though the archive itself succeeded.
export BORG_LOCK_WAIT="${BORG_LOCK_WAIT:-1800}"

BORG_USER=$(echo "$BORG_REPO" | sed -n 's|ssh://\([^@]*\)@.*|\1|p')
BORG_PATH=$(echo "$BORG_REPO" | sed -n 's|.*:23/\./||p')
BORG_DIR=$(dirname "$BORG_PATH")
info "Ensuring remote backup directory exists (user: ${BORG_USER})..."
ssh -p 23 -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new "${BORG_USER}@${BORG_SERVER_HOST}" "mkdir -p ${BORG_DIR}" 2>/dev/null || true

info "Checking borg repository..."
if ! borg info "$BORG_REPO" >/dev/null 2>&1; then
    info "Repository not found — initializing..."
    borg init --encryption=repokey "$BORG_REPO"
    borg config "$BORG_REPO" additional_free_space 2G
    info "Repository initialized"
else
    info "Repository exists"
fi

BACKUP_EXIT=0
SEEN=""
EXCLUDE_FILE=$(mktemp)
for exclude in ${BORG_EXCLUDES:-}; do
    printf '%s\n' "$exclude" >>"$EXCLUDE_FILE"
done

PATTERNS_ARGS=""
if [ -n "${BORG_PATTERNS:-}" ]; then
    PATTERNS_FILE=$(mktemp)
    # Newline-separated: word-splitting would break "+ path" pairs apart.
    printf '%s\n' "$BORG_PATTERNS" >"$PATTERNS_FILE"
    PATTERNS_ARGS="--patterns-from $PATTERNS_FILE"
fi

# Heredoc loop keeps variable updates in the current shell (no subshell).
while IFS= read -r target; do
    case "$target" in
        ''|\#*) continue ;;
    esac
    prefix=${target%%:*}
    paths=${target#*:}
    paths=${paths# }
    if [ -z "$prefix" ] || [ -z "$paths" ]; then
        info "Skipping malformed target: '$target'"
        continue
    fi
    info "Backing up '$prefix' from: $paths"
    # shellcheck disable=SC2086
    if borg create \
        --verbose \
        --filter AME \
        --list \
        --stats \
        --show-rc \
        --compression zstd,3 \
        --exclude-caches \
        --exclude '*.tmp' \
        --exclude '*.log' \
        --exclude-from "$EXCLUDE_FILE" \
        $PATTERNS_ARGS \
        \
        ::"${prefix}-{now:%Y-%m-%dT%H:%M:%S}" \
        $paths; then
        rc=0
    else
        rc=$?
    fi
    if [ "$rc" -gt "$BACKUP_EXIT" ]; then
        BACKUP_EXIT=$rc
    fi
    SEEN="$SEEN $prefix"
done <<EOF
$BORG_BACKUP_TARGETS
EOF

PRUNE_EXIT=0
for prefix in $SEEN; do
    info "Pruning '${prefix}-*' archives..."
    if borg prune \
        --list \
        --glob-archives "${prefix}-*" \
        --show-rc \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 6; then
        rc=0
    else
        rc=$?
    fi
    if [ "$rc" -gt "$PRUNE_EXIT" ]; then
        PRUNE_EXIT=$rc
    fi
done

if [ -n "${BORG_LEGACY_GLOBS:-}" ]; then
    for glob in $BORG_LEGACY_GLOBS; do
        info "Pruning legacy '$glob' archives..."
        if borg prune \
            --list \
            --glob-archives "$glob" \
            --show-rc \
            --keep-daily 7 \
            --keep-weekly 4 \
            --keep-monthly 6; then
            rc=0
        else
            rc=$?
        fi
        if [ "$rc" -gt "$PRUNE_EXIT" ]; then
            PRUNE_EXIT=$rc
        fi
    done
fi

info "Compacting repository..."
if borg compact; then
    COMPACT_EXIT=0
else
    COMPACT_EXIT=$?
fi

GLOBAL=$((BACKUP_EXIT > PRUNE_EXIT ? BACKUP_EXIT : PRUNE_EXIT))
GLOBAL=$((COMPACT_EXIT > GLOBAL ? COMPACT_EXIT : GLOBAL))

if [ "$GLOBAL" -eq 0 ]; then
    info "Backup, Prune, and Compact finished successfully"
elif [ "$GLOBAL" -eq 1 ]; then
    info "Backup, Prune, and/or Compact finished with warnings"
    # borg exits 1 when a file changed or vanished mid-read, which a live data
    # directory does constantly (Loki rotates its WAL as we read). The archive is
    # still complete, so propagating it would only fail a good backup.
    GLOBAL=0
else
    info "Backup, Prune, and/or Compact finished with errors"
fi

exit "$GLOBAL"
