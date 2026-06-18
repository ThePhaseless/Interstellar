# Proxmox Server Power Optimization

**Date:** 2026-06-14
**Server:** carbon (Proxmox VE 9.2.3, AMD Ryzen 9 3950X, 64GB DDR4)
**Goal:** Reduce idle power consumption while maintaining performance for bursty workloads

## Current State

**Hardware:**
- CPU: AMD Ryzen 9 3950X (16c/32t, 105W TDP)
- RAM: 64GB DDR4
- GPU: Intel Arc B580 (passed through to talos-1 VM)
- Storage: 5x 3TB 7200RPM HDD (RAIDZ1), 2x 1TB NVMe (mirror)
- Network: 2x Realtek NICs (1GbE + 2.5GbE), unused WiFi

**Current power state:**
- CPU package: ~38W (RAPL measured)
- CPU cores: ~1.8W (already scaling 573MHz–3.6GHz)
- GPU: ~9.2W average (never enters runtime suspend despite being idle)
- 5x HDD: ~28W (all spinning, no spindown)
- ASPM: disabled (`pcie_aspm=off` in GRUB)
- No TLP, powertop, or power management tools installed

**Estimated total wall draw:** ~130-145W at idle

## Changes

### Phase 1: Proxmox Host (apply via SSH, measure, then codify)

| # | Change | Command/Method | Expected savings | Risk |
|---|--------|----------------|-----------------|------|
| 1 | Enable ASPM | Remove `pcie_aspm=off` from `/etc/default/grub`, run `update-grub`, reboot | 5-15W | Medium (AMD stability — monitor for crashes) |
| 2 | Install TLP | `apt install tlp`, configure for server profile | 2-5W | Low |
| 3 | CPU energy preference | `cpupower set -b balance_performance` (all cores) | 1-3W | Low |
| 4 | Disable Postfix | `systemctl disable --now postfix` | <1W | Low |
| 5 | Disable WiFi | `rfkill block wifi` | ~1.5W | Low |
| 6 | Powertop auto-tune | Create oneshot systemd service running `powertop --auto-tune` | 1-3W | Low |
| 7 | HDD spindown | `hdparm -S 120 /dev/sd{a,b,c,d,e}` (10 min timeout) | ~25W when idle | Low (few sec latency on wake) |
| 8 | SATA link power | Set all `/sys/class/scsi_host/host*/link_power_management_policy` to `min_power` | 1-2W | Low |

**Phase 1 estimated savings: 37-55W**

### Phase 2: GPU (Talos VM, via talosctl/Terraform)

| # | Change | Method | Expected savings | Risk |
|---|--------|--------|-----------------|------|
| 9 | Fix GPU runtime PM | Investigate why `runtime_suspended_time=0` despite `control=auto`. Check if GPU device plugin or DRM connectors prevent suspend. Fix root cause. | ~8W | Low |
| 10 | Verify xe driver PM | Ensure xe driver's default PM settings work with device plugin | included above | Low |

**Phase 2 estimated savings: ~8W**

### Phase 3: Codify (Ansible + Terraform)

| # | Change | File |
|---|--------|------|
| 11 | Add all host changes to Ansible | `Ansible/setup-proxmox.yaml` |
| 12 | Add GPU PM config if needed | `Terraform/talos.tf` (kernel params) |

## Measurement Plan

1. Record baseline wall power from HA smart plug
2. Apply Phase 1 changes via SSH (except GRUB), measure after each
3. Reboot for GRUB/ASPM change, verify stability over 24h
4. Apply Phase 2 GPU fixes, measure
5. Codify everything into Ansible/Terraform
6. Final measurement comparison

## Rollback Plan

- ASPM: Re-add `pcie_aspm=off` to GRUB, reboot
- TLP: `apt remove tlp`
- HDD spindown: `hdparm -S 0 /dev/sd{a,b,c,d,e}`
- Services: `systemctl enable --now postfix`, `rfkill unblock wifi`
- GPU: Revert any Talos machine config changes via Terraform

## Success Criteria

- Measurable reduction in wall power (target: 30-50W savings at idle)
- No stability issues over 1 week
- Jellyfin transcoding still works (GPU performance unaffected)
- NFS/media access still responsive (HDD spindown adds few seconds on cold access)
