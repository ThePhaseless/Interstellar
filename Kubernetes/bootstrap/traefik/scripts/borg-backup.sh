#!/bin/sh
# BORG_PATTERNS (--patterns-from) takes `+` re-includes, which BORG_EXCLUDES (--exclude-from) cannot.
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

cat >~/.ssh/config <<EOF
Host ${BORG_SERVER_HOST}
    Port 23
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
    ServerAliveInterval 30
    ServerAliveCountMax 5
EOF
chmod 600 ~/.ssh/config

BORG_USER=$(echo "$BORG_REPO" | sed -n 's|ssh://\([^@]*\)@.*|\1|p')
BORG_PATH=$(echo "$BORG_REPO" | sed -n 's|.*:23/\./||p')
BORG_DIR=$(dirname "$BORG_PATH")
info "Ensuring remote backup directory exists (user: ${BORG_USER})..."
ssh "${BORG_USER}@${BORG_SERVER_HOST}" "mkdir -p ${BORG_DIR}" 2>/dev/null || true

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
        --compression zstd \
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
    # borg exits 1 when live data (Loki's WAL) changes or vanishes mid-read; the archive is still complete.
    GLOBAL=0
else
    info "Backup, Prune, and/or Compact finished with errors"
fi

exit "$GLOBAL"
