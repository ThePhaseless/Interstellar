#!/bin/sh
set -e

BACKUP_NAME="media-hsi"
BACKUP_PATHS="/bazarr /qbittorrent /seerr"

info() { printf "\n%s %s\n\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }

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
info "Ensuring remote backup directory exists (user: ${BORG_USER})..."
ssh -p 23 -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new "${BORG_USER}@${BORG_SERVER_HOST}" "mkdir -p backups/utilities" 2>/dev/null || true

info "Checking borg repository..."
if ! borg info "$BORG_REPO" >/dev/null 2>&1; then
    info "Repository not found — initializing..."
    borg init --encryption=repokey "$BORG_REPO"
    borg config "$BORG_REPO" additional_free_space 2G
    info "Repository initialized"
else
    info "Repository exists"
fi

info "Starting backup for ${BACKUP_NAME}..."
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
    ::"${BACKUP_NAME}-{now:%Y-%m-%dT%H:%M:%S}" \
    $BACKUP_PATHS

backup_exit=$?

info "Pruning ${BACKUP_NAME} archives..."
borg prune \
    --list \
    --glob-archives "${BACKUP_NAME}-*" \
    --show-rc \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6

# Legacy: prune old media-* archives from before the per-node split
borg prune \
    --list \
    --glob-archives 'media-*' \
    --show-rc \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6

prune_exit=$?

info "Compacting repository..."
borg compact
compact_exit=$?

global_exit=$((backup_exit > prune_exit ? backup_exit : prune_exit))
global_exit=$((compact_exit > global_exit ? compact_exit : global_exit))

if [ ${global_exit} -eq 0 ]; then
    info "Backup, Prune, and Compact finished successfully"
elif [ ${global_exit} -eq 1 ]; then
    info "Backup, Prune, and/or Compact finished with warnings"
else
    info "Backup, Prune, and/or Compact finished with errors"
fi

exit ${global_exit}
