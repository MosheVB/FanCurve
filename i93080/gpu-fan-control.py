#!/usr/bin/env python3
"""Drive motherboard fan headers from the NVIDIA GPU temperature.

FAN_PWM names the channels ("5" or "2 5"). Only those leave BIOS control;
every other header keeps its BIOS curve.

Fail-safe: if the GPU temperature cannot be read, the channel goes to 100%.
On exit it hands the channel back to the BIOS mode it found at start
(systemd's ExecStopPost repeats that, so a SIGKILL cannot leave it manual).
"""
import glob, os, signal, subprocess, sys, time

CHIP = os.environ.get("FAN_CHIP", "nct6798")
CHANNELS = [int(c) for c in os.environ["FAN_PWM"].split()]  # e.g. "2 5"
CURVE = [(40, 30), (55, 50), (65, 75), (75, 100)]  # (GPU C, duty %), linear between
HYST = 3                                         # C of drop before slowing down
PERIOD = 2.0


def hwmon():
    for d in glob.glob("/sys/class/hwmon/hwmon*"):
        with open(f"{d}/name") as f:
            if f.read().strip() == CHIP:
                return d
    sys.exit(f"no hwmon named {CHIP} (is nct6775 loaded?)")


HW = hwmon()


def rd(p):
    with open(p) as f:
        return int(f.read())


def wr(p, v):
    with open(p, "w") as f:
        f.write(str(int(v)))


PWM = {c: f"{HW}/pwm{c}" for c in CHANNELS}
EN = {c: f"{HW}/pwm{c}_enable" for c in CHANNELS}
ORIG_EN = {c: rd(EN[c]) for c in CHANNELS}


def restore(*_):
    for c in CHANNELS:
        wr(EN[c], ORIG_EN[c] if ORIG_EN[c] != 1 else 5)
    sys.exit(0)


def gpu_temp():
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=10).stdout
        return max(int(x) for x in out.split())
    except Exception:
        return None


def duty(t):
    if t <= CURVE[0][0]:
        return CURVE[0][1]
    for (t0, d0), (t1, d1) in zip(CURVE, CURVE[1:]):
        if t <= t1:
            return d0 + (d1 - d0) * (t - t0) / (t1 - t0)
    return 100


signal.signal(signal.SIGTERM, restore)
signal.signal(signal.SIGINT, restore)
for c in CHANNELS:
    wr(EN[c], 1)
held_t = None
last = None
while True:
    t = gpu_temp()
    if t is None:
        pct, why = 100, "gpu temp unreadable"
    else:
        # rise immediately, fall only after a HYST-degree drop
        if held_t is None or t > held_t or t <= held_t - HYST:
            held_t = t
        pct, why = duty(held_t), f"gpu {t}C (held {held_t}C)"
    val = round(255 * pct / 100)
    for c in CHANNELS:
        if rd(EN[c]) != 1:   # something (BIOS/another tool) took it back
            wr(EN[c], 1)
            last = None
    if val != last:
        for c in CHANNELS:
            wr(PWM[c], val)
        print(f"pwm{','.join(map(str, CHANNELS))} -> {pct:.0f}% ({why})", flush=True)
        last = val
    time.sleep(PERIOD)
