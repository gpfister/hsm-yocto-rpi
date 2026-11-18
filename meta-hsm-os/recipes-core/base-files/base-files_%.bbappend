FILESEXTRAPATHS:prepend:rpi := "${THISDIR}/files:"

HSM_DEV_MODE ??= "0"

def hsm_compute_hostname(d):
    machine = (d.getVar("MACHINE") or "").strip()
    if not machine:
        base = "piKMS"
    elif machine.startswith("raspberrypi"):
        suffix = machine[len("raspberrypi"):].lstrip("-")
        base = f"piKMS-{suffix}" if suffix else "piKMS"
    else:
        base = f"piKMS-{machine}"
    if (d.getVar("HSM_DEV_MODE") or "0").strip() == "1":
        return f"{base}-dev"
    return base

# Derive appliance hostname from MACHINE (e.g., raspberrypi0-2w-64 -> piKMS-0-2w-64[-dev])
hostname = "${@hsm_compute_hostname(d)}"

# Add a mount point for a shared data partition
dirs755 += "/data"
