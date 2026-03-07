"""Prometheus exporter for Intel Xe GPUs via sysfs."""

import glob
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

CARD_BASE = "/sys/class/drm"


def read_sysfs(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except (OSError, ValueError):
        return None


def read_int(path):
    val = read_sysfs(path)
    if val is not None:
        try:
            return int(val)
        except ValueError:
            pass
    return None


def discover_cards():
    cards = []
    for card_dir in sorted(glob.glob(os.path.join(CARD_BASE, "card[0-9]*"))):
        driver_link = os.path.join(card_dir, "device", "driver")
        if os.path.islink(driver_link):
            driver = os.path.basename(os.readlink(driver_link))
            if driver == "xe":
                cards.append(os.path.basename(card_dir))
    return cards


def collect_metrics():
    lines = []
    cards = discover_cards()

    for card in cards:
        device = os.path.join(CARD_BASE, card, "device")

        # GT frequencies and idle
        tile_path = os.path.join(device, "tile0")
        if os.path.isdir(tile_path):
            for gt_dir in sorted(glob.glob(os.path.join(tile_path, "gt[0-9]*"))):
                gt = os.path.basename(gt_dir)
                freq_dir = os.path.join(gt_dir, "freq0")

                for metric in ["act_freq", "cur_freq", "max_freq", "min_freq"]:
                    val = read_int(os.path.join(freq_dir, metric))
                    if val is not None:
                        lines.append(
                            f'intel_xe_{metric}_mhz{{card="{card}",gt="{gt}"}} {val}'
                        )

                idle_ms = read_int(os.path.join(gt_dir, "gtidle", "idle_residency_ms"))
                if idle_ms is not None:
                    lines.append(
                        f'intel_xe_idle_residency_ms{{card="{card}",gt="{gt}"}} {idle_ms}'
                    )

                # Throttle reasons
                throttle_dir = os.path.join(freq_dir, "throttle")
                if os.path.isdir(throttle_dir):
                    status = read_int(os.path.join(throttle_dir, "status"))
                    if status is not None:
                        lines.append(
                            f'intel_xe_throttle_status{{card="{card}",gt="{gt}"}} {status}'
                        )
                    for reason_file in glob.glob(
                        os.path.join(throttle_dir, "reason_*")
                    ):
                        reason = os.path.basename(reason_file).removeprefix("reason_")
                        val = read_int(reason_file)
                        if val is not None:
                            lines.append(
                                f'intel_xe_throttle_reason{{card="{card}",gt="{gt}",reason="{reason}"}} {val}'
                            )

        # hwmon sensors
        for hwmon_dir in glob.glob(os.path.join(device, "hwmon", "hwmon*")):
            name = read_sysfs(os.path.join(hwmon_dir, "name"))
            if name != "xe":
                continue

            # Temperatures
            for i in range(1, 10):
                val = read_int(os.path.join(hwmon_dir, f"temp{i}_input"))
                label = read_sysfs(os.path.join(hwmon_dir, f"temp{i}_label"))
                if val is not None and label:
                    lines.append(
                        f'intel_xe_temp_celsius{{card="{card}",sensor="{label}"}} {val / 1000}'
                    )

            # Energy counters (monotonic, use rate() in PromQL)
            for i in range(1, 5):
                val = read_int(os.path.join(hwmon_dir, f"energy{i}_input"))
                label = read_sysfs(os.path.join(hwmon_dir, f"energy{i}_label"))
                if val is not None and label:
                    lines.append(
                        f'intel_xe_energy_microjoules_total{{card="{card}",domain="{label}"}} {val}'
                    )

            # Fans
            for i in range(1, 5):
                val = read_int(os.path.join(hwmon_dir, f"fan{i}_input"))
                if val is not None:
                    lines.append(
                        f'intel_xe_fan_rpm{{card="{card}",fan="{i}"}} {val}'
                    )

            # Power cap
            val = read_int(os.path.join(hwmon_dir, "power1_cap"))
            if val is not None:
                lines.append(
                    f'intel_xe_power_cap_watts{{card="{card}"}} {val / 1e6}'
                )

    return "\n".join(lines) + "\n"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/metrics":
            self.send_response(404)
            self.end_headers()
            return
        body = collect_metrics().encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    print("Intel Xe GPU exporter listening on :8080", flush=True)
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
