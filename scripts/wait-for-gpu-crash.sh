#!/usr/bin/env bash
# wait-for-gpu-crash.sh
#
# Watches the cluster for the Flannel-restart / GPU-pod-NotReady crash
# pattern and exits with diagnostic info when it happens. Designed to
# be run in a terminal you can come back to (tmux, screen, or a
# backgrounded shell with notifications).
#
# Detection signals (any one fires the alert):
#   1. Flannel container restart count on the GPU node increases
#      (primary; this is the upstream cause of the cascade).
#   2. jellyfin or immich-ml pod has been NotReady for >=2 minutes.
#   3. New UnexpectedAdmissionError event for gpu.intel.com/xe.
#
# On detection, dumps:
#   - Flannel pod state + recent events
#   - GPU pod state (jellyfin, immich-ml)
#   - Recent UnexpectedAdmissionError events
#   - GPU node resource pressure
#   - Recent kernel log lines (Loki via talos-kmsg-shipper)
#   - Talos dmesg filtered for oom/kill/flannel/xe/drm
# Optionally posts a one-line message to a Discord webhook.
#
# Usage:
#   ./scripts/wait-for-gpu-crash.sh                       # run forever
#   ./scripts/wait-for-gpu-crash.sh --timeout 2h          # exit after 2h
#   ./scripts/wait-for-gpu-crash.sh --node=talos-9jv-bx9  # override node
#   ./scripts/wait-for-gpu-crash.sh --interval 15         # poll every 15s
#   DISCORD_WEBHOOK_URL=https://... ./scripts/wait-for-gpu-crash.sh
#
# Environment variables (all optional, overridable on cmdline):
#   NODE              GPU node name          (default: talos-9jv-bx9)
#   NAMESPACE         Flannel namespace      (default: kube-system)
#   POLL_INTERVAL     Seconds between polls  (default: 30)
#   NOTREADY_THRESHOLD  Seconds NotReady before alert  (default: 120)
#   TIMEOUT           Total seconds to run   (default: 0 = forever)
#   DISCORD_WEBHOOK_URL  If set, post a message on detection
#   LOG_FILE          Where to write full diagnostic dump
#                                          (default: /tmp/gpu-crash-watcher.log)
#
# Exit codes:
#   0  Crash pattern detected
#   1  Bad usage / missing tools / unreachable cluster
#   2  Timeout reached without detection
#   3  Interrupted (Ctrl-C)
#
# Requirements: kubectl, jq. Optional: talosctl, curl (Discord),
# bash >= 4 (for ${var:=default} and arrays).

set -euo pipefail

# --- Defaults (env-overridable) ---
: "${NODE:=talos-9jv-bx9}"
: "${NAMESPACE:=kube-system}"
: "${POLL_INTERVAL:=30}"
: "${NOTREADY_THRESHOLD:=120}"
: "${TIMEOUT:=0}"
: "${DISCORD_WEBHOOK_URL:=}"
: "${LOG_FILE:=/tmp/gpu-crash-watcher.log}"

# --- Arg parse ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) sed -n '2,/^# Requirements/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --timeout=*) TIMEOUT="${1#*=}" ;;
    --timeout)   TIMEOUT="$2"; shift ;;
    --node=*)    NODE="${1#*=}" ;;
    --node)      NODE="$2"; shift ;;
    --interval=*) POLL_INTERVAL="${1#*=}" ;;
    --interval)  POLL_INTERVAL="$2"; shift ;;
    --threshold=*) NOTREADY_THRESHOLD="${1#*=}" ;;
    --threshold) NOTREADY_THRESHOLD="$2"; shift ;;
    --log=*)     LOG_FILE="${1#*=}" ;;
    --log)       LOG_FILE="$2"; shift ;;
    --no-dump)   NO_DUMP=1 ;;
    --no-discord) DISCORD_WEBHOOK_URL="" ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

# --- Helpers ---
log()  { printf '[%s] %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE" >&2; }
hdr()  { printf '\n========== %s ==========\n' "$*" | tee -a "$LOG_FILE" >&2; }

# Pre-flight checks
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found" >&2; exit 1; }
command -v jq      >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }
command -v talosctl >/dev/null 2>&1 || log "talosctl not found; dmesg dump will be skipped"
command -v curl     >/dev/null 2>&1 || log "curl not found; Discord alert will be skipped"

kubectl get node "$NODE" >/dev/null 2>&1 || { echo "Cannot reach node $NODE via kubectl" >&2; exit 1; }

# Trap for clean interrupt
trap 'log "Interrupted (exit 3)"; exit 3' INT TERM

# --- Diagnostic dumper ---
dump_diagnostics() {
  local reason="$1"
  hdr "GPU crash pattern detected on $NODE — reason: $reason"
  log "Writing full diagnostic dump to $LOG_FILE"
  {
    echo "## Timestamp: $(date -Iseconds)"
    echo "## Reason: $reason"
    echo

    echo "## Flannel pod state on $NODE:"
    kubectl -n "$NAMESPACE" get pod -l app=flannel \
      --field-selector "spec.nodeName=$NODE" -o wide 2>&1 || true
    echo

    local flannel_pod
    flannel_pod=$(kubectl -n "$NAMESPACE" get pod -l app=flannel \
      --field-selector "spec.nodeName=$NODE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -n "$flannel_pod" ]]; then
      echo "## Flannel pod recent events ($flannel_pod):"
      kubectl -n "$NAMESPACE" get events \
        --field-selector "involvedObject.name=$flannel_pod" \
        --sort-by=.lastTimestamp 2>&1 | tail -20 || true
      echo
    fi

    echo "## GPU pods (jellyfin + immich-ml):"
    kubectl -n media     get pod -l 'app in (jellyfin)'             -o wide 2>&1 || true
    kubectl -n utilities get pod -l 'app in (immich-ml,immich)'      -o wide 2>&1 || true
    echo

    echo "## Recent UnexpectedAdmissionError events (last 10):"
    kubectl get events -A --field-selector reason=UnexpectedAdmissionError \
      --sort-by=.lastTimestamp 2>&1 | tail -10 || true
    echo

    echo "## GPU node resource pressure:"
    kubectl describe node "$NODE" 2>&1 \
      | grep -A 4 -E "Conditions:|Allocated resources:|MemoryPressure|DiskPressure|PIDPressure" \
      | head -25 || true
    echo

    if command -v curl >/dev/null 2>&1; then
      echo "## Recent kernel log from $NODE (Loki, kmsg_level=4..7, last 5m):"
      kubectl -n observability port-forward svc/loki 3100:3100 >/dev/null 2>&1 & local pf=$!
      sleep 2
      curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
        --data-urlencode "query={app=\"talos-kmsg-shipper\", node_name=\"$NODE\"} |= \"\" | kmsg_level=~\"4|5|6|7\"" \
        --data-urlencode "limit=20" --data-urlencode "since=5m" 2>/dev/null \
        | jq -r '.data.result[]?.values[]?[-1]' 2>/dev/null \
        | head -20 || true
      kill "$pf" 2>/dev/null || true
      wait "$pf" 2>/dev/null || true
      echo
    fi

    if command -v talosctl >/dev/null 2>&1; then
      echo "## talosctl dmesg tail (last 200 lines, filtered):"
      talosctl --nodes "$NODE" dmesg --tail=200 2>&1 \
        | grep -iE "flannel|oom|kill|err|reset|xe|drm|aer|throttl" \
        | tail -20 || true
    fi

    echo
    echo "## Next: read docs/superpowers/plans/2026-06-18-gpu-dmc-firmware.md"
    echo "## and the AGENTS.md Flannel gotcha for the long-term fix plan."
  } >> "$LOG_FILE"
}

post_discord() {
  local reason="$1"
  if [[ -n "$DISCORD_WEBHOOK_URL" ]] && command -v curl >/dev/null 2>&1; then
    curl -fsS -H "Content-Type: application/json" \
      -d "{\"content\": \"🚨 GPU crash pattern on $NODE — $reason. Full dump: $LOG_FILE\"}" \
      "$DISCORD_WEBHOOK_URL" 2>/dev/null || log "Discord post failed"
  fi
}

# --- Main loop ---
log "Watching for GPU crash pattern on $NODE"
log "  poll=${POLL_INTERVAL}s  notready_threshold=${NOTREADY_THRESHOLD}s  timeout=${TIMEOUT}s  log=$LOG_FILE"
log "  discord=${DISCORD_WEBHOOK_URL:+set}${DISCORD_WEBHOOK_URL:-off}"
log "Press Ctrl-C to abort."

# Establish baselines
flannel_restarts=$(kubectl -n "$NAMESPACE" get pod -l app=flannel \
  --field-selector "spec.nodeName=$NODE" \
  -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo 0)
uadm_count=$(kubectl get events -A --field-selector reason=UnexpectedAdmissionError \
  -o jsonpath='{.items[*].metadata.uid}' 2>/dev/null | wc -w)
gpu_notready_since=0
start_ts=$(date +%s)
log "Baselines: flannel_restarts=$flannel_restarts  unexpected_admission_errors=$uadm_count"

while true; do
  if [[ "$TIMEOUT" -gt 0 ]]; then
    elapsed=$(( $(date +%s) - start_ts ))
    if [[ "$elapsed" -ge "$TIMEOUT" ]]; then
      log "Timeout (${TIMEOUT}s) reached without detection (exit 2)"
      exit 2
    fi
    remaining=$(( TIMEOUT - elapsed ))
    log "tick (${elapsed}s elapsed, ${remaining}s remaining)"
  else
    log "tick"
  fi

  # 1. Flannel restart count
  flannel_now=$(kubectl -n "$NAMESPACE" get pod -l app=flannel \
    --field-selector "spec.nodeName=$NODE" \
    -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo "$flannel_restarts")
  if [[ "$flannel_now" -gt "$flannel_restarts" ]]; then
    log "Flannel restarted on $NODE (was $flannel_restarts, now $flannel_now)"
    [[ "${NO_DUMP:-}" != "1" ]] && dump_diagnostics "flannel-restart ($flannel_restarts -> $flannel_now)"
    post_discord "flannel-restart"
    log "Exiting 0"
    exit 0
  fi

  # 2. GPU pod NotReady for >= threshold
  notready_pods=$(kubectl get pod -A -o json 2>/dev/null | jq -r '
    .items[]
    | select(.metadata.labels.app == "jellyfin" or .metadata.labels.app == "immich-ml")
    | select((.status.conditions // []) | map(select(.type == "Ready" and .status == "True")) | length == 0)
    | .metadata.namespace + "/" + .metadata.name
  ' 2>/dev/null | sort -u)
  if [[ -n "$notready_pods" ]]; then
    if [[ "$gpu_notready_since" -eq 0 ]]; then
      gpu_notready_since=$(date +%s)
      log "GPU pod(s) NotReady, starting ${NOTREADY_THRESHOLD}s grace: $(echo "$notready_pods" | tr '\n' ' ')"
    else
      elapsed_nr=$(( $(date +%s) - gpu_notready_since ))
      log "GPU pod(s) still NotReady (${elapsed_nr}s / ${NOTREADY_THRESHOLD}s): $(echo "$notready_pods" | tr '\n' ' ')"
      if [[ "$elapsed_nr" -ge "$NOTREADY_THRESHOLD" ]]; then
        log "GPU NotReady threshold reached"
        [[ "${NO_DUMP:-}" != "1" ]] && dump_diagnostics "gpu-pod-notready>${NOTREADY_THRESHOLD}s"
        post_discord "gpu-pod-notready>${NOTREADY_THRESHOLD}s"
        log "Exiting 0"
        exit 0
      fi
    fi
  else
    if [[ "$gpu_notready_since" -ne 0 ]]; then
      log "GPU pods recovered (was NotReady for $(( $(date +%s) - gpu_notready_since ))s)"
    fi
    gpu_notready_since=0
  fi

  # 3. UnexpectedAdmissionError
  uadm_now=$(kubectl get events -A --field-selector reason=UnexpectedAdmissionError \
    -o jsonpath='{.items[*].metadata.uid}' 2>/dev/null | wc -w)
  if [[ "$uadm_now" -gt "$uadm_count" ]]; then
    log "New UnexpectedAdmissionError event(s) (was $uadm_count, now $uadm_now)"
    [[ "${NO_DUMP:-}" != "1" ]] && dump_diagnostics "unexpected-admission-error"
    post_discord "unexpected-admission-error"
    log "Exiting 0"
    exit 0
  fi

  sleep "$POLL_INTERVAL"
done
