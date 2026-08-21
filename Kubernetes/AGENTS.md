# Kubernetes Manifest Conventions

## App Directory Structure

Each app lives in `Kubernetes/apps/<name>/` with at minimum:

- `kustomization.yaml` — namespace, resources list, labels block
- `deployment.yaml` — container spec, probes, resources
- `service.yaml` — ClusterIP by default

Optional files: `ingress.yaml` (Traefik IngressRoute), `pvc.yaml`, `externalsecret.yaml`, `middleware.yaml`

**Register new apps** by adding the directory to `Kubernetes/apps/kustomization.yaml` resources list.

## Kustomization Pattern

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: media # media | utilities | home

resources:
  - deployment.yaml
  - service.yaml

labels:
  - pairs:
      app: <name>
    includeSelectors: true
```

- Always set `includeSelectors: true` in the labels block
- Use `configMapGenerator` with `disableNameSuffixHash: true` when adding config files
- Namespaces are declared in `Kubernetes/apps/namespaces.yaml` — don't create new ones in app dirs

## Traefik IngressRoute (not standard Ingress)

This project uses `traefik.io/v1alpha1` IngressRoute CRD. Never use `networking.k8s.io/v1 Ingress`.

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: <app>
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`<subdomain>.nerine.dev`)
      kind: Rule
      services:
        - name: <service>
          port: <port>
      middlewares:
        - name: public-chain
          namespace: traefik
        - name: authentik # Add for SSO-protected routes
          namespace: traefik
  tls:
    certResolver: letsencrypt
    domains:
      - main: nerine.dev
        sans:
          - "*.nerine.dev"
```

**Middleware rules:**

- Global middlewares (`public-chain`, `authentik`, `streaming-chain`) live in `traefik` namespace — always include `namespace: traefik`
- App-specific middlewares go in the app's own namespace
- Streaming apps (Jellyfin) use `streaming-chain` instead of `public-chain` + `authentik`

## ExternalSecrets

Two `ClusterSecretStore` sources:

- `bitwarden-store` — manual secrets (OAuth creds, API tokens, webhooks)
- `bitwarden-store-generated` — Terraform-created secrets (passwords, OIDC clients, API keys)

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: <app>-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: bitwarden-store-generated # or bitwarden-store for manual
    kind: ClusterSecretStore
  target:
    name: <app>-secrets
    creationPolicy: Owner
  data:
    - secretKey: <local-key>
      remoteRef:
        key: <bitwarden-secret-key> # kebab-case name in Bitwarden
```

For template transformations (mapping remote keys to different local keys):

```yaml
target:
  template:
    data:
      local-name: "{{ .remote_ref }}"
data:
  - secretKey: remote_ref
    remoteRef:
      key: bitwarden-key-name
```

## Deployments

### Required elements

- Named ports (`name: http`) — referenced by services and probes
- Resource requests AND limits on every container
- Liveness and readiness probes with appropriate delays
- `TZ: UTC` env var for timezone-aware apps

### Strategy

- `type: Recreate` for stateful apps, GPU apps, or anything with exclusive volume access
- Default (RollingUpdate) only for truly stateless services

### Common annotations

```yaml
annotations:
  reloader.stakater.com/auto: "true" # Restart on ConfigMap/Secret change
  prometheus.io/scrape: "true" # Enable metrics scraping
  prometheus.io/port: "9707" # Metrics port
  ignore-check.kube-linter.io/<check>: "..." # Suppress specific kube-linter checks
```

### GPU workloads

Schedule on GPU node with nodeSelector + resource requests:

```yaml
nodeSelector:
  intel.feature.node.kubernetes.io/gpu: "true"
resources:
  requests:
    gpu.intel.com/xe: "1"
  limits:
    gpu.intel.com/xe: "1"
```

### Servarr apps (Sonarr, Radarr, Prowlarr)

- Init container sets `<AuthenticationMethod>External</AuthenticationMethod>` in `config.xml`
- Sidecar `api-extractor` reads API key from config → updates Bitwarden secret
- Sidecar `exportarr` exposes Prometheus metrics
- Uses `serviceAccountName: arr-configurator` (RBAC in `common/rbac.yaml`)
- Mounts shared scripts from `arr-scripts` ConfigMap (in `common/`)

## Services

```yaml
# ClusterIP (default, internal access)
spec:
  type: ClusterIP
  ports:
    - name: http
      port: <port>
      targetPort: http

# MetalLB LoadBalancer (LAN static IP)
metadata:
  annotations:
    metallb.io/loadBalancerIPs: "192.168.1.X"
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local

# Tailscale mesh exposure
metadata:
  annotations:
    tailscale.com/expose: "true"
    tailscale.com/hostname: "<app>"
spec:
  type: LoadBalancer
  loadBalancerClass: tailscale
  externalTrafficPolicy: Local
```

## Storage

### Longhorn PVC (app config, databases)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <app>-config
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: longhorn
  resources:
    requests:
      storage: 2Gi # Size appropriately: 2Gi config, 3-4Gi databases
```

### NFS shared storage

NFS PVs are defined in `Kubernetes/apps/common/media-pv.yaml`. Mount options: `nfsvers=4.2,noatime`, reclaim: `Retain`, access: `ReadWriteMany`.

The NFS server IP uses placeholder `REPLACED_BY_KUSTOMIZE` — the root `Kubernetes/kustomization.yaml` performs the replacement. Never hardcode the NFS IP.

Reference existing PVCs (`media-pvc`, `downloads-pvc`, `personal-pvc`) in deployments — don't create new NFS PVs unless adding a new share.

## Volumes pattern

```yaml
volumes:
  - name: config
    persistentVolumeClaim:
      claimName: <app>-config # Longhorn
  - name: media
    persistentVolumeClaim:
      claimName: media-pvc # Shared NFS
  - name: cache
    emptyDir:
      sizeLimit: 10Gi # Ephemeral cache
  - name: scripts
    configMap:
      name: arr-scripts
      defaultMode: 0755 # Executable scripts
  - name: secrets
    secret:
      secretName: <app>-secrets
```

## Key Gotchas

- **Recyclarr `qualities:` order is preference order (first = most preferred) and drives manual-search sort + cutoff in Radarr/Sonarr, but the v4 API returns profile items in quality-id order so it's not visible via API — always mirror the TRaSH guide's best-first order in YAML.** The configs previously listed HDTV/1080p first, which ranked the worst sources as most preferred. Also: guide-backed profiles inherit the guide's `minFormatScore` (e.g. `[Anime] Remux-1080p` got 100 from the guide) even when the YAML omits it — an explicit `min_format_score` overrides it. Note that `min_format_score: 0` still hard-rejects any release with a *negative* CF score (LQ, x265-HD, BR-DISK, 3D, etc., which the Golden Rule scores -10000); the way to truly 'prefer better but never filter' is a large negative `min_format_score` (e.g. -1000000) so negative CFs only rank releases lower. Only the disallowed *qualities* (CAM/TELESYNC/BR-DISK etc.) then act as hard filters. `qualities` omitted = only the listed qualities are allowed; qualities not listed are disabled, which silently blocks grabs for old/niche content with only 720p/480p/SD releases.
- **GPU node serial console**: Kernel logs from talos-1 (GPU node) are captured to `/var/log/vm-110-serial.log` on the Proxmox host via `vm-110-serial-logger.service`. Use `ssh root@carbon 'tail -100 /var/log/vm-110-serial.log'` to view crash logs. The service uses `socat` to connect to the Proxmox serial socket and appends output to the log file. Logrotate rotates weekly.
- Talos static control-plane pod logs under `/var/log/pods/kube-system_kube-{apiserver,controller-manager,scheduler}-*/*/*.log` are not reliably picked up by the generic Promtail `kubernetes_sd` pod scrape here; add explicit file globs if you need those logs in Loki or alerting.
- One-shot or TTL-cleaned `Job` resources should not stay in ArgoCD steady-state `resources:` lists here; once Kubernetes garbage-collects them, Argo will keep the app `OutOfSync` trying to recreate the missing Job.
- Helm hook resources that should not persist after a successful sync need `helm.sh/hook-delete-policy` to include `hook-succeeded`; otherwise leftover hook RBAC or ServiceAccounts can keep `app-of-apps` falsely unhealthy even though the actual hook already finished.
- The repo self-manages `argocd/app-of-apps`, so the custom ArgoCD `Application` health script must special-case that root app and derive health from `.status.resources`; mirroring its own `.status.health` makes the root app stay recursively `Degraded`.
- Legacy bootstrap resources that predate `application.resourceTrackingMethod: annotation` need a one-time live adoption with `argocd.argoproj.io/tracking-id`; after that, ArgoCD compare also needs to ignore that annotation or the adopted bootstrap resources stay falsely `OutOfSync`.
- Root app health should also ignore completed hook resources with `requiresPruning=true` such as `argocd-redis-secret-init` RBAC; otherwise `app-of-apps` stays falsely `Degraded` even after the cluster is already reconciled.
- **ClamAV was removed by design** — there is no `Kubernetes/bootstrap/clamav/` directory, no `clamav-scanner`/`clamav-deep-scan` CronJobs, no `clamav-db` PVC, no `clamav-secrets` ExternalSecret, and no `security` namespace. The `discord-webhook-url` Bitwarden secret is **still in use** by `Kubernetes/bootstrap/observability/externalsecret.yaml` (Promtail/Alloy alerts) and remains managed by `Terraform/secrets.tf`/`Terraform/apps/bitwarden.tf` — do not delete it. `/downloads/quarantine` and `/personal/public/.quarantine` were ClamAV's downstream consumers; if a future malware scanner is added, it must wire to those paths or the workflow needs a redesign — do not silently re-add ClamAV.

- **A cgroup OOM in an s6-overlay (linuxserver.io) container reports `Reason: Completed`, `Exit Code: 0` — not `OOMKilled`**: cgroup v2 `memory.oom.group` kills every process in the container cgroup including s6 PID 1, so kubelet never sees the OOM flag and the pod looks like it exited cleanly. Bazarr hit this every ~5h — baseline ~250Mi plus a ~320Mi `ffprobe` from the knowit refiner scanning a 2160p file exceeded its 512Mi limit. Diagnose with `container_memory_working_set_bytes` in Mimir (a sawtooth pegging the limit right before each restart) plus `talosctl -n <node> dmesg | grep oom-kill`; kubelet logs are useless here because the probe-failure message is `V(1)`-gated and Talos runs kubelet at verbosity 0.

- **Loki 3.7 rejects ALL pushes with 500 `"Ingester is shutting down"` when the WAL volume exceeds 90%** (`ingester.wal.disk_full_threshold` default 0.9; log: `wal.go:215 msg="disk usage exceeded threshold, throttling writes"`). It is NOT a real shutdown — queries and `/ready` stay healthy and the pod keeps Running. The throttle releases automatically once usage drops below 90% (per-push check), so the fix is freeing space or expanding the PVC (`data-loki-0-rwx`, Longhorn RWX supports online expansion), not restarting the pod. Keep the Loki PVC well under 90% or the whole cluster's log collection silently dies.
## Lint validation

Run `scripts/lint-kubernetes.sh` after changes — it builds with kustomize and runs kube-linter. CI runs the same check on PRs touching `Kubernetes/`.

## Emergency Recovery

### Longhorn volume in `emergency_ro` (read-only filesystem)

**Never delete the PVC as a first step.** The filesystem is locked read-only by the kernel to prevent further damage, but the data is still readable. Deleting the PVC destroys the only copy of the data.

**Correct recovery sequence:**

1. **Scale the StatefulSet/Deployment to `0`** — this releases the mount so the volume can be manipulated safely
2. **Wait for Longhorn to detach the volume** — check `kubectl get volume -n longhorn-system <volume-name>`, wait for `status.state: detached`
3. **Attach the volume to a node** — `kubectl patch volume -n longhorn-system <volume-name> --type=merge -p '{"spec":{"nodeID":"<node>"}}'`
4. **Copy data to safety** — run a privileged pod on that node mounting the raw block device read-only, `cp -a` everything to a safe location (another PVC, NFS share, or temporary location)
5. **Attempt repair** — install `e2fsprogs` in the pod and run `e2fsck -y /dev/longhorn/<volume-name>`
6. **If fsck succeeds**, scale the app back up — Kubernetes will re-mount the volume read-write
7. **Only if fsck fails and data is confirmed lost**, then delete the PVC and let the StatefulSet recreate it

**Alternative: use Longhorn snapshots.** Before any destructive action, check `kubectl get snapshot -n longhorn-system -l longhornvolume=<volume-name>` — if a recent healthy snapshot exists, revert to it (`kubectl patch volume -n longhorn-system <volume-name> --type=merge -p '{"spec":{"snapshot":"<snapshot-name>"}}'`), then re-attach.
