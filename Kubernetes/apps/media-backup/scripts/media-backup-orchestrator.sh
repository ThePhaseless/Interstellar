#!/bin/sh
set -eu

NAMESPACE="${POD_NAMESPACE:-media}"
BACKUP_SELECTOR="${BACKUP_SELECTOR:-backup.interstellar/enabled=true}"
JOB_TIMEOUT_SECONDS="${JOB_TIMEOUT_SECONDS:-7200}"
BACKUP_IMAGE="${BACKUP_IMAGE:-alpine:3.23}"

info() { printf '\n%s %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }

info "Installing kubectl and jq..."
apk add --no-cache kubectl jq >/dev/null 2>&1

backup_pvcs=$(kubectl get pvc -n "$NAMESPACE" -l "$BACKUP_SELECTOR" -o json)
pvc_count=$(printf '%s' "$backup_pvcs" | jq '.items | length')

if [ "$pvc_count" -eq 0 ]; then
    info "No backup-enabled PVCs found in namespace '$NAMESPACE'"
    exit 1
fi

run_job() {
    claim="$1"
    prefix="$2"
    mount_path="$3"
    app_selector="$4"
    excludes="$5"
    legacy_globs="$6"

    node_name=$(
        kubectl get pods -n "$NAMESPACE" -l "$app_selector" -o json |
            jq -r --arg claim "$claim" '
              .items[]
              | select(.status.phase == "Running")
              | select(any(.spec.volumes[]?; .persistentVolumeClaim.claimName == $claim))
              | .spec.nodeName
            ' |
            sed -n '1p'
    )

    job="media-backup-${prefix}-$(date '+%Y%m%d%H%M%S')"
    job_file="/tmp/${job}.yaml"

    info "Creating backup job '$job' for PVC '$claim'"
    if [ -n "$node_name" ]; then
        info "Running app pod found on node '$node_name'; pinning backup job there"
        node_line="      nodeName: ${node_name}"
    else
        info "No running app pod found for '$claim'; leaving backup job schedulable"
        node_line=""
    fi

    cat >"$job_file" <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: media-backup
    app.kubernetes.io/component: worker
    backup.interstellar/archive-prefix: ${prefix}
spec:
  ttlSecondsAfterFinished: 120
  backoffLimit: 0
  template:
    spec:
${node_line}
      restartPolicy: Never
      containers:
        - name: borgbackup
          image: ${BACKUP_IMAGE}
          command: ["/bin/sh", "/scripts/borg-backup.sh"]
          env:
            - name: BORG_PASSPHRASE
              valueFrom:
                secretKeyRef:
                  name: borg-secrets
                  key: passphrase
            - name: BORG_REPO
              valueFrom:
                secretKeyRef:
                  name: borg-secrets
                  key: repo-url
            - name: BORG_SERVER_HOST
              valueFrom:
                secretKeyRef:
                  name: borg-secrets
                  key: server-host
            - name: BORG_BACKUP_TARGETS
              value: |
                ${prefix}:${mount_path}
            - name: BORG_EXCLUDES
              value: "${excludes}"
            - name: BORG_LEGACY_GLOBS
              value: "${legacy_globs}"
          volumeMounts:
            - name: app-data
              mountPath: ${mount_path}
              readOnly: true
            - name: borg-ssh-key
              mountPath: /secrets/ssh
              readOnly: true
            - name: backup-script
              mountPath: /scripts
              readOnly: true
            - name: borg-cache
              mountPath: /root/.cache/borg
          resources:
            requests: { cpu: 200m, memory: 512Mi }
            limits: { cpu: 2000m, memory: 2Gi }
      volumes:
        - name: app-data
          persistentVolumeClaim:
            claimName: ${claim}
        - name: borg-ssh-key
          secret:
            secretName: borg-secrets
            items:
              - key: ssh-private-key
                path: id_ed25519
                mode: 0600
            defaultMode: 0600
        - name: backup-script
          configMap:
            name: media-backup-script
            defaultMode: 0755
        - name: borg-cache
          emptyDir:
            sizeLimit: 2Gi
EOF

    kubectl create -f "$job_file"

    start_time=$(date +%s)
    while :; do
        status=$(
            kubectl get job "$job" -n "$NAMESPACE" -o json |
                jq -r '
                  if (.status.succeeded // 0) > 0 then "succeeded"
                  elif (.status.failed // 0) > 0 then "failed"
                  else "running"
                  end
                '
        )

        case "$status" in
            succeeded)
                info "Backup job '$job' completed successfully"
                kubectl logs -n "$NAMESPACE" "job/${job}" || true
                return 0
                ;;
            failed)
                info "Backup job '$job' failed"
                kubectl logs -n "$NAMESPACE" "job/${job}" || true
                return 1
                ;;
        esac

        now=$(date +%s)
        if [ $((now - start_time)) -ge "$JOB_TIMEOUT_SECONDS" ]; then
            info "Backup job '$job' timed out after ${JOB_TIMEOUT_SECONDS}s"
            kubectl logs -n "$NAMESPACE" "job/${job}" || true
            return 1
        fi

        sleep 10
    done
}

FAILED=0
PIDS=""
targets_file=$(mktemp)

printf '%s' "$backup_pvcs" | jq -r '
  .items[]
  | [
      .metadata.name,
      (.metadata.annotations["backup.interstellar/archive-prefix"] // (.metadata.name | sub("-config$"; ""))),
      (.metadata.annotations["backup.interstellar/mount-path"] // ("/" + (.metadata.name | sub("-config$"; "")))),
      (.metadata.annotations["backup.interstellar/app-selector"] // ("app=" + (.metadata.name | sub("-config$"; "")))),
      (.metadata.annotations["backup.interstellar/excludes"] // ""),
      (.metadata.annotations["backup.interstellar/legacy-globs"] // "")
    ]
  | @tsv
' >"$targets_file"

while IFS="$(printf '\t')" read -r claim prefix mount_path app_selector excludes legacy_globs; do
    (
        if ! run_job "$claim" "$prefix" "$mount_path" "$app_selector" "$excludes" "$legacy_globs"; then
            exit 1
        fi
    ) &
    pid=$!
    PIDS="$PIDS $pid"
done <"$targets_file"

FAILED=0
for pid in $PIDS; do
    if ! wait "$pid"; then
        FAILED=1
    fi
done

exit "$FAILED"
