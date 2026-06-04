#!/bin/sh
# Generic BorgBackup runner.
#
# Drives `borg create` / `borg prune` / `borg compact` against a single
# shared repository, parameterized by environment variables. One CronJob
# may declare multiple targets by listing one `prefix:path1 path2 ...` per
# line in BORG_BACKUP_TARGETS (e.g. observability backs up mimir/grafana/loki
# in a single daily run).
#
# Required env:
#   BORG_PASSPHRASE       — repo encryption passphrase (from borg-secrets)
#   BORG_REPO             — repo URL (from borg-secrets)
#   BORG_SERVER_HOST      — SSH host for known_hosts (from borg-secrets)
#   BORG_BACKUP_TARGETS   — one `prefix:paths` per line, paths space-separated
#
# Optional env:
#   BORG_LEGACY_GLOBS     — space-separated extra `--glob-archives` patterns
#                           to keep pruning (for archive families renamed or
#                           split away). Example: "immich-*"
#
# Pod layout expected:
#   /secrets/ssh/id_ed25519  (mode 0600)   — SSH private key
#   /root/.cache/borg        (emptyDir)    — borg cache
#   /scripts/borg-backup.sh  (ConfigMap)   — this script
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

# Heredoc loop keeps variable updates in the current shell (no subshell).
while IFS= read -r target; do
    case "$target" in
        ''|\#*) continue ;;  # skip blank lines and comments
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
    borg create \
        --verbose \
        --filter AME \
        --list \
        --stats \
        --show-rc \
        --compression zstd,3 \
        --exclude-caches \
        --exclude '*.tmp' \
        --exclude '*.log' \
        \
        ::"${prefix}-{now:%Y-%m-%dT%H:%M:%S}" \
        $paths
    rc=$?
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
    borg prune \
        --list \
        --glob-archives "${prefix}-*" \
        --show-rc \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 6
    rc=$?
    if [ "$rc" -gt "$PRUNE_EXIT" ]; then
        PRUNE_EXIT=$rc
    fi
done

if [ -n "${BORG_LEGACY_GLOBS:-}" ]; then
    for glob in $BORG_LEGACY_GLOBS; do
        info "Pruning legacy '$glob' archives..."
        borg prune \
            --list \
            --glob-archives "$glob" \
            --show-rc \
            --keep-daily 7 \
            --keep-weekly 4 \
            --keep-monthly 6
        rc=$?
        if [ "$rc" -gt "$PRUNE_EXIT" ]; then
            PRUNE_EXIT=$rc
        fi
    done
fi

info "Compacting repository..."
borg compact
COMPACT_EXIT=$?

GLOBAL=$((BACKUP_EXIT > PRUNE_EXIT ? BACKUP_EXIT : PRUNE_EXIT))
GLOBAL=$((COMPACT_EXIT > GLOBAL ? COMPACT_EXIT : GLOBAL))

if [ "$GLOBAL" -eq 0 ]; then
    info "Backup, Prune, and Compact finished successfully"
elif [ "$GLOBAL" -eq 1 ]; then
    info "Backup, Prune, and/or Compact finished with warnings"
else
    info "Backup, Prune, and/or Compact finished with errors"
fi

exit "$GLOBAL"
