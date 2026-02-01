# CrowdSec Bouncer Migration to Traefik Plugin

## Summary

Migrated from the unmaintained `fbonalair/traefik-crowdsec-bouncer:0.5` forward-auth service to the official Traefik plugin `maxlerebourg/crowdsec-bouncer-traefik-plugin` v1.5.0.

## Changes Made

### Removed
- ❌ [Kubernetes/bootstrap/crowdsec/bouncer.yaml](../Kubernetes/bootstrap/crowdsec/bouncer.yaml) - Old bouncer Deployment and Service

### Added
- ✅ [Kubernetes/bootstrap/traefik/crowdsec-middleware.yaml](../Kubernetes/bootstrap/traefik/crowdsec-middleware.yaml) - CrowdSec plugin middleware configuration
- ✅ [Kubernetes/bootstrap/traefik/crowdsec-externalsecret.yaml](../Kubernetes/bootstrap/traefik/crowdsec-externalsecret.yaml) - ExternalSecret for bouncer API key in traefik namespace

### Modified
- 🔧 [Kubernetes/bootstrap/traefik/config.yaml](../Kubernetes/bootstrap/traefik/config.yaml) - Added plugin configuration
- 🔧 [Kubernetes/bootstrap/traefik/deployment.yaml](../Kubernetes/bootstrap/traefik/deployment.yaml) - Mounted CrowdSec secrets volume
- 🔧 [Kubernetes/bootstrap/traefik/kustomization.yaml](../Kubernetes/bootstrap/traefik/kustomization.yaml) - Added new resources
- 🔧 [Kubernetes/bootstrap/crowdsec/kustomization.yaml](../Kubernetes/bootstrap/crowdsec/kustomization.yaml) - Removed bouncer.yaml reference
- 🔧 [README.md](../README.md) - Updated technology stack versions

## Benefits

1. **Native Integration**: Plugin runs directly in Traefik process (no separate service)
2. **Better Performance**: No additional network hop for forward auth
3. **Active Maintenance**: Plugin is actively maintained (last update: January 2026)
4. **Stream Mode**: Efficient caching mechanism updates decisions every 60 seconds
5. **Resource Savings**: Eliminates 2 bouncer replicas (saves ~200MB memory)

## Configuration Highlights

- **Mode**: Stream (recommended for performance)
- **Update Interval**: 60 seconds
- **Trusted IPs**: Tailscale CGNAT (100.64.0.0/10), Cluster VLAN, Pod CIDR
- **LAPI Endpoint**: crowdsec-lapi.crowdsec.svc.cluster.local:8080
- **Secret Management**: API key synced from Bitwarden via ExternalSecret

## Testing

All Kubernetes manifests passed kube-linter validation:
```bash
./scripts/lint-kubernetes.sh
# ✓ All Kubernetes manifests passed linting!
```

## Documentation

Plugin Documentation: https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin
