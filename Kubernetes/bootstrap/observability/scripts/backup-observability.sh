#!/bin/sh
set -e

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

info "Checking borg repository..."
if ! borg info "$BORG_REPO" >/dev/null 2>&1; then
    info "Repository not found — initializing..."
    borg init --encryption=repokey "$BORG_REPO"
    borg config "$BORG_REPO" additional_free_space 2G
    info "Repository initialized"
else
    info "Repository exists"
fi

TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')
BACKUP_EXIT=0

for service in mimir grafana loki; do
    case $service in
        mimir)   src=/data ;;
        grafana) src=/grafana ;;
        loki)    src=/loki ;;
    esac

    info "Backing up $service from $src..."
    if [ -d "$src" ]; then
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
            ::"observability-${service}-${TIMESTAMP}" \
            "$src"
        rc=$?
        if [ $rc -gt $BACKUP_EXIT ]; then
            BACKUP_EXIT=$rc
        fi
    else
        info "WARNING: $src does not exist, skipping $service"
    fi
done

info "Pruning repository..."
PRUNE_EXIT=0
for service in mimir grafana loki; do
    borg prune \
        --list \
        --glob-archives "observability-${service}-*" \
        --show-rc \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 6
    rc=$?
    if [ $rc -gt $PRUNE_EXIT ]; then
        PRUNE_EXIT=$rc
    fi
done

info "Compacting repository..."
borg compact
COMPACT_EXIT=$?

GLOBAL_EXIT=$((BACKUP_EXIT > PRUNE_EXIT ? BACKUP_EXIT : PRUNE_EXIT))
GLOBAL_EXIT=$((COMPACT_EXIT > GLOBAL_EXIT ? COMPACT_EXIT : GLOBAL_EXIT))

if [ ${GLOBAL_EXIT} -eq 0 ]; then
    info "Backup, Prune, and Compact finished successfully"
elif [ ${GLOBAL_EXIT} -eq 1 ]; then
    info "Backup, Prune, and/or Compact finished with warnings"
else
    info "Backup, Prune, and/or Compact finished with errors"
fi

exit ${GLOBAL_EXIT}
