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

- Talos static control-plane pod logs under `/var/log/pods/kube-system_kube-{apiserver,controller-manager,scheduler}-*/*/*.log` are not reliably picked up by the generic Promtail `kubernetes_sd` pod scrape here; add explicit file globs if you need those logs in Loki or alerting.
- One-shot or TTL-cleaned `Job` resources should not stay in ArgoCD steady-state `resources:` lists here; once Kubernetes garbage-collects them, Argo will keep the app `OutOfSync` trying to recreate the missing Job.

## Lint validation

Run `scripts/lint-kubernetes.sh` after changes — it builds with kustomize and runs kube-linter. CI runs the same check on PRs touching `Kubernetes/`.
