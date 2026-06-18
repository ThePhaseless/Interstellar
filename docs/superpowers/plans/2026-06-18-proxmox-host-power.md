# Proxmox Host Power Optimization (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce carbon's idle wall power ~25W via ZFS hygiene, hd-idle fix, USB/NIC cleanup — measured via Home Assistant, codified into Ansible.

**Architecture:** Apply each change on carbon via SSH → measure via HA REST API → verify no regression → codify into `Ansible/setup-proxmox.yaml` `power` tag. All changes reversible.

**Tech Stack:** Proxmox VE 7.0.6-2 (Debian 13), ZFS 2.x, hd-idle, hdparm, udev, Ansible, Home Assistant REST API.

**Spec:** `docs/superpowers/specs/2026-06-18-proxmox-host-power-design.md`

**HA measurement command (reused throughout):**
```bash
HA_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI5YjMzNzVkMjMzMDc0ZjE0OGRkOTMxYjM2YWU1MWIwNSIsImlhdCI6MTc4MTgwMDIzNywiZXhwIjoyMDk3MTYwMjM3fQ.XDs0wPukWHygi2LlrXF17bv-_x2DUNEmKISZSqZ90qU"
# Daily buckets mean/min/max over a time range:
curl -s -H "Authorization: Bearer $HA_TOKEN" \
  "http://192.168.1.186:8123/api/history/period/<START_ISO>?filter_entity_id=sensor.serwer_current_consumption&end_time=<END_ISO>&minimal_response" \
  | python3 -c "import json,sys,statistics,collections; d=json.load(sys.stdin)[0]; b=collections.defaultdict(list); [b[s['last_changed'][:10]].append(float(s['state'])) for s in d if s['state'] not in ('unavailable','unknown','none','')]; [print(f'{day:12s} n={len(v):5d} min={min(v):6.1f} mean={statistics.mean(v):7.1f} med={statistics.median(v):7.1f} max={max(v):7.1f}') for day,v in sorted(b.items())]"
```

**Baseline (recorded 2026-06-18):** post-Phase-1 idle floor = 83.3W, mean = 130.2W.

---

### Task 1: Record baseline + capture pre-change HDD state

**Files:** none (read-only measurement)

- [ ] **Step 1: Capture 24h baseline power** — run the HA measurement command for the last 24h. Record mean/min/max. Save output to a scratch file (e.g. `/tmp/power-baseline.txt` on carbon or local).
- [ ] **Step 2: Capture current HDD power state** — `ssh root@carbon 'for d in /dev/sd[a-e]; do echo -n "$d: "; smartctl -n standby $d 2>/dev/null | grep -E "Power mode" | head -1; done'`. Expect `IDLE_A`/`IDLE_B` (heads parked, platters spinning) — confirms the problem.
- [ ] **Step 3: Capture ZFS pool status** — `ssh root@carbon 'zpool status Storage; zfs get atime,compression,recordsize Storage'`. Record for before/after comparison.

### Task 2: Change 1 — ZFS `atime=off` (the biggest free win)

**Files:**
- Modify (test phase): live ZFS property on carbon
- Modify (codify): `Ansible/setup-proxmox.yaml` (add ZFS set task under `power` tag)

- [ ] **Step 1: Apply `atime=off` on carbon** — `ssh root@carbon 'zfs set atime=off Storage'`. Verify: `ssh root@carbon 'zfs get atime Storage'` → `off`.
- [ ] **Step 2: Wait 10 min, then check HDD state** — `ssh root@carbon 'for d in /dev/sd[a-e]; do echo -n "$d: "; smartctl -n standby $d 2>/dev/null | grep -E "Power mode" | head -1; done'`. If disks still `IDLE_A/B`, wait longer (downloads may still be writing — that's Change 3's job to fix). If `STANDBY`, the win is confirmed.
- [ ] **Step 3: Measure HA power over 2h** — run the HA measurement command for the last 2h. Compare min (idle floor) to baseline 83W. If floor dropped, `atime=off` is a confirmed win.
- [ ] **Step 4: Codify into Ansible** — add to `Ansible/setup-proxmox.yaml` after the `power-tuning` service task (around line 216), before handlers, under `tags: [power]`:
```yaml
    - name: Disable atime on Storage pool (stop reads from writing)
      ansible.builtin.command:
        cmd: zfs set atime=off Storage
      changed_when: false  # idempotent: zfs set is a no-op if already set
      tags:
        - power
```
- [ ] **Step 5: Verify Ansible idempotency** — `ansible-playbook Ansible/setup-proxmox.yaml --tags power --check --diff` (or run the lint: `mise run lint-ansible`). Confirm the task reports "changed=0" on a second run (since `changed_when: false` and the value is already set).
- [ ] **Step 6: Commit** — `git add Ansible/setup-proxmox.yaml && git commit -m "feat(proxmox): set ZFS atime=off on Storage to enable HDD spindown"`

### Task 3: Change 2 — Fix `hd-idle` to use `-c ata` for SATA drives

**Files:**
- Modify: `Ansible/setup-proxmox.yaml:222-227` (the `hd-idle` defaults template)

- [ ] **Step 1: Apply on carbon (test)** — `ssh root@carbon 'sed -i "s/-i 600 -c scsi/-i 600 -c ata/" /etc/default/hd-idle && systemctl restart hd-idle'`. Verify: `ssh root@carbon 'cat /etc/default/hd-idle'` shows `HD_IDLE_OPTS="-i 600 -c ata"`.
- [ ] **Step 2: Wait 10 min for idle timeout, check HDD state** — `ssh root@carbon 'for d in /dev/sd[a-e]; do echo -n "$d: "; smartctl -n standby $d 2>/dev/null | grep -E "Power mode" | head -1; done'`. Expect `STANDBY` for drives with no recent I/O. (Note: if `atime=off` alone already got them to STANDBY, this confirms the fix holds; if they were still IDLE_A/B, this change should push them to STANDBY.)
- [ ] **Step 3: Measure HA power** — run HA measurement for last 2h. Compare to Task 2's result. Additional drop confirms the `-c ata` fix.
- [ ] **Step 4: Codify into Ansible** — edit `Ansible/setup-proxmox.yaml` line 226, change:
```yaml
          HD_IDLE_OPTS="-i 600 -c scsi"
```
to:
```yaml
          HD_IDLE_OPTS="-i 600 -c ata"
```
Also update the comment on line 225 to: `# Spin down all SATA disks after 10 minutes of inactivity (use -c ata for SATA, not -c scsi).`
- [ ] **Step 5: Commit** — `git add Ansible/setup-proxmox.yaml && git commit -m "fix(proxmox): use hd-idle -c ata for SATA drives (scsi never reached STANDBY)"`

### Task 4: Change 4 — Disable unused USB devices (RGB + serial)

**Files:**
- Modify: `Ansible/setup-proxmox.yaml` (add udev rule task under `power` tag)

- [ ] **Step 1: Test unbind MSI MYSTIC LIGHT** — First find the correct syspath: `ssh root@carbon 'for d in /sys/bus/usb/devices/*/; do [ -f "$d/idVendor" ] && echo "$(basename $d) $(cat $d/idVendor):$(cat $d/idProduct) $(cat $d/product 2>/dev/null)"; done'`. Locate the `1462:7c37` device path. Unbind it: `ssh root@carbon 'echo > /sys/bus/usb/devices/<devpath>/driver/unbind'`. Wait 10 min, measure HA, confirm no service break (`ssh root@carbon 'systemctl status nut-server nut-driver apcupsd'` all inactive — expected).
- [ ] **Step 2: Test unbind CH340 serial** — same process for `1a86:7523`. Unbind, wait 10 min, measure, confirm no getty/UPS breakage (`ssh root@carbon 'systemctl status getty@tty* nut-server nut-driver apcupsd'`).
- [ ] **Step 3: Codify udev rule into Ansible** — add to `Ansible/setup-proxmox.yaml` before the `Enable power management services` task (around line 231), under `tags: [power]`:
```yaml
    - name: Disable unused USB devices (RGB controller + serial) for power
      ansible.builtin.copy:
        dest: /etc/udev/rules.d/99-power-usb-unbind.rules
        mode: "0644"
        content: |
          # MSI MYSTIC LIGHT RGB controller (no RGB daemon running)
          ACTION=="add", ATTR{idVendor}=="1462", ATTR{idProduct}=="7c37", RUN+="/bin/sh -c 'echo > /sys$DEVPATH/driver/unbind'"
          # CH340 serial converter (no getty, no UPS software)
          ACTION=="add", ATTR{idVendor}=="1a86", ATTR{idProduct}=="7523", RUN+="/bin/sh -c 'echo > /sys$DEVPATH/driver/unbind'"
      tags:
        - power
```
- [ ] **Step 4: Verify** — `mise run lint-ansible`. Re-run `ansible-playbook Ansible/setup-proxmox.yaml --tags power --check` to confirm idempotency.
- [ ] **Step 5: Commit** — `git add Ansible/setup-proxmox.yaml && git commit -m "feat(proxmox): disable unused USB RGB + serial devices for ~2W power saving"`

### Task 5: Change 5 — Power off unused `nic0`

**Files:**
- Modify: `Ansible/setup-proxmox.yaml` (add nic0 powersave task under `power` tag)

- [ ] **Step 1: Find nic0 PCI address + driver** — `ssh root@carbon 'ls -d /sys/class/net/nic0/device; readlink /sys/class/net/nic0/device; lspci -nn -s $(basename $(readlink -f /sys/class/net/nic0/device)); ls /sys/class/net/nic0/device/driver -L'`. Record the PCI address (e.g. `0000:XX:YY.Z`), vendor/device IDs, and driver name.
- [ ] **Step 2: Test unbind** — `ssh root@carbon 'echo <pci-addr> > /sys/bus/pci/drivers/<driver>/unbind 2>/dev/null; ip link show nic0'`. Verify `nic1`/`vmbr0`/`tailscale0` still up: `ssh root@carbon 'ip -br link'`. Wait 10 min, measure HA.
- [ ] **Step 3: Codify** — add to `Ansible/setup-proxmox.yaml` under `tags: [power]`. Use a udev rule keyed to the PCI vendor/device ID (more stable than address):
```yaml
    - name: Power off unused nic0 (1GbE, no carrier)
      ansible.builtin.copy:
        dest: /etc/udev/rules.d/99-power-nic0.rules
        mode: "0644"
        content: |
          # nic0 is unused (DOWN, no carrier) — unbind driver to allow PCI runtime PM
          ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="<vid>", ATTR{device}=="<pid>", RUN+="/bin/sh -c 'echo %k > /sys/bus/pci/drivers/<driver>/unbind'"
      tags:
        - power
```
(Replace `<vid>`, `<pid>`, `<driver>` with values from Step 1.)
- [ ] **Step 4: Commit** — `git add Ansible/setup-proxmox.yaml && git commit -m "feat(proxmox): power off unused nic0 for ~1-2W saving"`

### Task 6: Change 3 — Relocate qBittorrent downloads to NVMe (only if HDDs still spin)

**Files:**
- Modify: `Kubernetes/apps/common/media-pv.yaml:67-98` (downloads PV/PVC)
- Modify: `Kubernetes/apps/qbittorrent/deployment.yaml:107-109`
- Modify: `Kubernetes/apps/sonarr/deployment.yaml:146-148`
- Modify: `Kubernetes/apps/radarr/deployment.yaml:146-148`
- Create: `Kubernetes/apps/common/downloads-longhorn-pvc.yaml` (new Longhorn PVC)

**Precondition:** Only do this if Task 2+3 left HDDs spinning too often (background downloads still writing). Check `smartctl -n standby` over a 1h download-only window. If disks reach STANDBY without downloads running, skip this task.

- [ ] **Step 1: Verify the problem persists** — start a small qBittorrent download, monitor `ssh root@carbon 'for d in /dev/sd[a-e]; do echo -n "$d: "; smartctl -n standby $d 2>/dev/null | grep -E "Power mode" | head -1; done'` every 2 min for 30 min. If disks never reach STANDBY while downloading, proceed. Else skip to Task 7.
- [ ] **Step 2: Create new Longhorn downloads PVC** — create `Kubernetes/apps/common/downloads-longhorn-pvc.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: downloads-longhorn
  namespace: media
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn
  resources:
    requests:
      storage: 500Gi
```
Add it to `Kubernetes/apps/common/kustomization.yaml` resources if needed.
- [ ] **Step 3: Scale down the 3 consumers** — `kubectl -n media scale deploy qbittorrent sonarr radarr --replicas=0`. Wait for pods to terminate.
- [ ] **Step 4: Copy existing downloads to Longhorn** — run a temporary job that mounts both `downloads-pvc` (NFS, read-only) and `downloads-longhorn` (RWX), `cp -a` contents:
```bash
kubectl -n media apply -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate-downloads
spec:
  template:
    spec:
      restartPolicy: OnFailure
      volumes:
        - name: src
          persistentVolumeClaim: { claimName: downloads-pvc }
        - name: dst
          persistentVolumeClaim: { claimName: downloads-longhorn }
      containers:
        - name: migrate
          image: busybox:1.38
          command: ["/bin/sh", "-c", "cp -a /src/. /dst/"]
          volumeMounts:
            - { name: src, mountPath: /src, readOnly: true }
            - { name: dst, mountPath: /dst }
EOF
kubectl -n media wait job/migrate-downloads --for=condition=complete --timeout=3600s
```
- [ ] **Step 5: Switch the 3 deployments to the new PVC** — in `qbittorrent/deployment.yaml:108`, `sonarr/deployment.yaml:148`, `radarr/deployment.yaml:148`, change `claimName: downloads-pvc` → `claimName: downloads-longhorn`. **Patch in-place, never delete+recreate** (AGENTS.md safety rule).
- [ ] **Step 6: Scale up + verify** — `kubectl -n media scale deploy qbittorrent sonarr radarr --replicas=1`. Verify pods healthy, downloads work, imports work.
- [ ] **Step 7: Verify HDDs now sleep during downloads** — start a download, monitor `smartctl -n standby` — disks should reach STANDBY during download (writes go to NVMe now). Measure HA power.
- [ ] **Step 8: Lint + commit** — `mise run lint-kubernetes`. `git add Kubernetes/apps/ && git commit -m "feat(media): relocate downloads PVC to Longhorn NVMe to enable HDD spindown"`. Push for ArgoCD sync.

### Task 7: Change 6 — Optional EPP `balance_power`→`power` test

**Files:** potentially `Ansible/setup-proxmox.yaml:155` (TLP config)

- [ ] **Step 1: Apply test** — `ssh root@carbon 'cpupower set -b power'`. Verify: `ssh root@carbon 'cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference'` → `power`.
- [ ] **Step 2: Measure power 30 min** — run HA measurement for last 30 min. Compare to pre-change.
- [ ] **Step 3: Bench performance** — trigger a Jellyfin transcode or run `ssh root@carbon 'sysbench cpu --time=30 run'` (if sysbench installed; else use a quick transcode). Compare to expected.
- [ ] **Step 4: Decision** — if power dropped >1W AND perf unchanged: codify by editing `Ansible/setup-proxmox.yaml:155` `CPU_ENERGY_PERF_POLICY_ON_AC=balance_power` → `=power`. Commit. Else revert: `ssh root@carbon 'cpupower set -b balance_power'` and skip codification.

### Task 8: Final verification + AGENTS.md gotchas

**Files:**
- Modify: `AGENTS.md` (append Key Gotchas)

- [ ] **Step 1: Measure 24h final power** — run HA measurement for 24h post-all-changes. Compare to baseline (83W floor / 130W mean). Record results.
- [ ] **Step 2: Verify ZFS healthy** — `ssh root@carbon 'zpool status Storage'` — no errors. `ssh root@carbon 'zpool scrub Storage'` if not recently scrubbed (monitor progress).
- [ ] **Step 3: Verify media stack functional** — play a Jellyfin item (cold access — expect 5-10s spinup), confirm transcoding works. Confirm qBittorrent/Sonarr/Radarr all healthy.
- [ ] **Step 4: Append gotchas to `AGENTS.md`** — add the three bullets from the spec's "Key Gotchas" section (hd-idle `-c scsi` vs `-c ata`; ZFS `atime=on` prevents spindown; qBittorrent downloads on spinning pool keep disks awake).
- [ ] **Step 5: Commit** — `git add AGENTS.md && git commit -m "docs(agents): add power-optimization gotchas (hd-idle, atime, downloads relocation)"`

### Task 9: Push + ArgoCD/Ansible sync verification

- [ ] **Step 1: Push all commits** — `git push origin main`.
- [ ] **Step 2: Verify CI passes** — check GitHub Actions: `ansible-lint.yaml` (for Ansible changes), `kubernetes-lint.yaml` (for K8s changes).
- [ ] **Step 3: Verify ArgoCD syncs** — (if Task 6 was done) check ArgoCD syncs the new PVC + deployment changes. `kubectl -n media get pvc,pod -l app=qbittorrent`.
- [ ] **Step 4: Final 24h measurement** — confirm power savings hold over a full day/night cycle.
