#!/usr/bin/env python3
"""Read workstation counters without spawning a command per widget."""

import json
import os
from pathlib import Path
import shutil
import socket
import time


def read(path, default=""):
    try:
        return Path(path).read_text().strip()
    except (OSError, UnicodeError):
        return default


def cpu_counters(text):
    result = {}
    for line in text.splitlines():
        fields = line.split()
        if fields and fields[0].startswith("cpu"):
            # guest and guest_nice are already included in user and nice.
            ticks = [int(value) for value in fields[1:9]]
            result[fields[0]] = (sum(ticks), ticks[3] + ticks[4])
    return result


def cpu_usage(previous, current):
    result = {}
    for name, (total, idle) in current.items():
        old = previous.get(name)
        delta = total - old[0] if old else 0
        result[name] = max(0, min(100, 100 * (1 - (idle - old[1]) / delta))) if delta > 0 else None
    return result


def memory(text):
    values = {line.split(":")[0]: int(line.split()[1]) * 1024 for line in text.splitlines() if ":" in line}
    total = values.get("MemTotal", 0)
    used = total - values.get("MemAvailable", total)
    swap_total = values.get("SwapTotal", 0)
    return {"total": total, "used": used, "percent": 100 * used / total if total else None,
            "swapTotal": swap_total, "swapUsed": swap_total - values.get("SwapFree", 0)}


def network_counters(text):
    result = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        name, values = line.split(":", 1)
        name = name.strip()
        # Physical links avoid counting each packet again on a VPN or bridge.
        if not Path(f"/sys/class/net/{name}/device").exists():
            continue
        fields = values.split()
        result[name] = (int(fields[0]), int(fields[8]))
    return result


def rates(previous, current, elapsed):
    return [{"name": name,
             "down": max(0, counters[0] - previous.get(name, counters)[0]) / elapsed,
             "up": max(0, counters[1] - previous.get(name, counters)[1]) / elapsed}
            for name, counters in sorted(current.items())] if elapsed > 0 else []


def temperatures():
    result = []
    for sensor in sorted(Path("/sys/class/hwmon").glob("hwmon*/temp*_input")):
        try:
            value = int(read(sensor)) / 1000
        except ValueError:
            continue
        if not -20 < value < 150:
            continue
        driver = read(sensor.parent / "name", "sensor")
        label = read(sensor.with_name(sensor.name.replace("_input", "_label")), sensor.stem)
        result.append({"name": f"{driver} · {label}", "value": value})
    return result


def graphics():
    result = []
    for card in sorted(Path("/sys/class/drm").glob("card[0-9]*")):
        if "-" in card.name:
            continue
        device = card / "device"
        if not device.exists():
            continue
        def counter(name):
            value = read(device / name)
            return int(value) if value.isdigit() else None
        driver = (device / "driver").resolve().name
        result.append({"name": f"{card.name} · {driver}",
                       "busy": counter("gpu_busy_percent"),
                       "vramUsed": counter("mem_info_vram_used"),
                       "vramTotal": counter("mem_info_vram_total")})
    return result


def disks():
    result = []
    for path in ["/", str(Path.home()), "/games"]:
        if not Path(path).exists():
            continue
        try:
            usage = shutil.disk_usage(path)
            result.append({"name": path, "used": usage.used, "total": usage.total,
                           "percent": 100 * usage.used / usage.total})
        except OSError:
            pass
    return result


def stream():
    previous_cpu, previous_net, previous_time = {}, {}, time.monotonic()
    while True:
        now = time.monotonic()
        current_cpu = cpu_counters(read("/proc/stat"))
        current_net = network_counters(read("/proc/net/dev"))
        usage = cpu_usage(previous_cpu, current_cpu)
        packet = {
            "hostname": socket.gethostname(), "kernel": os.uname().release,
            "cpu": usage.get("cpu"), "cores": [value for name, value in usage.items() if name != "cpu"],
            "memory": memory(read("/proc/meminfo")), "load": list(os.getloadavg()),
            "uptime": float(read("/proc/uptime", "0 0").split()[0]),
            "network": rates(previous_net, current_net, now - previous_time),
            "temperatures": temperatures(), "disks": disks(), "graphics": graphics(),
        }
        print(json.dumps(packet), flush=True)
        previous_cpu, previous_net, previous_time = current_cpu, current_net, now
        time.sleep(2)


if __name__ == "__main__":
    try:
        stream()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
