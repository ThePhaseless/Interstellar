#!/bin/sh
# Home backup orchestrator.
#
# AdGuard uses a ReadWriteOnce PVC, so the backup worker cannot mount it while
# AdGuard is running. This orchestrator scales AdGuard down, creates a
# short-lived Job that mounts the PVC and runs borg-backup.sh, waits for it to
# finish, then scales AdGuard back up.
set -eu

info() { printf '\n%s %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }

ADGUARD_NS="home"
ADGUARD_NAME="adguard"
WORKER_JOB="home-backup-run"

info "Installing kubectl..."
apk add --no-cache curl >/dev/null 2>&1
KUBECTL_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl

cleanup() {
    info "Cleanup: scaling ${ADGUARD_NAME} back up and removing worker job..."
    kubectl scale deployment "${ADGUARD_NAME}" --replicas=1 -n "${ADGUARD_NS}" >/dev/null 2>&1 || true
    kubectl delete job "${WORKER_JOB}" -n "${ADGUARD_NS}" --force >/dev/null 2>&1 || true
}
trap cleanup EXIT

info "Scaling ${ADGUARD_NAME} down for backup..."
kubectl scale deployment "${ADGUARD_NAME}" --replicas=0 -n "${ADGUARD_NS}"
kubectl wait --for=delete pod -l app="${ADGUARD_NAME}" -n "${ADGUARD_NS}" --timeout=300s

info "Creating worker job ${WORKER_JOB}..."
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${WORKER_JOB}
  namespace: ${ADGUARD_NS}
spec:
  ttlSecondsAfterFinished: 120
  backoffLimit: 2
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: borgbackup
          image: alpine:3.24
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
                home:/adguard
          volumeMounts:
            - name: adguard-data
              mountPath: /adguard
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
            requests: { cpu: 100m, memory: 256Mi }
            limits: { cpu: 1000m, memory: 1Gi }
      volumes:
        - name: adguard-data
          persistentVolumeClaim:
            claimName: adguard-data
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
            name: home-backup-script
            defaultMode: 0755
        - name: borg-cache
          emptyDir:
            sizeLimit: 2Gi
EOF

info "Waiting for worker job ${WORKER_JOB} to complete..."
kubectl wait --for=condition=complete --timeout=3600s job "${WORKER_JOB}" -n "${ADGUARD_NS}"

info "Worker job completed successfully."
