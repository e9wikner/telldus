# hubbabubba deployment

Deploying `telldusd` and the `telldus-mqtt` bridge as a **rootless Podman
quadlet** on `hubbabubba` (Arch Linux home server), from a checkout of this
repo on that host.

This directory is additive and specific. The Docker and native paths in the
top-level [README](../README.md) are unchanged and still the right starting
point for anyone else — nothing here replaces them.

```bash
ssh hubbabubba
cd ~/Development/telldus
git pull
deploy/deploy.sh
```

There is no Ansible run behind this and nothing to apply from a workstation.
The server repo (`e9wikner/hubbabubba`) prepares the host — a container
engine, a place to keep data, access to the TellStick — and stops there.

## Layout

```
deploy/
  telldus.container.in     The quadlet    (@TOKEN@ placeholders)
  deploy.sh                The deployment
  deploy.env.example       Host-specific values — copy to deploy.env  (gitignored)
  tellstick.conf.example   Device pairing — copy to tellstick.conf    (gitignored)
```

Both real files are gitignored: the broker password and the household's
house/unit codes do not belong in a public fork. They live in the checkout on
the deployment host, which is also where you edit them — `deploy.sh` copies
`tellstick.conf` onto the host, so the checkout stays the source of truth
rather than becoming a stale copy of it.

They are backed up differently, and it matters. `tellstick.conf` is not a
secret and *is* backed up by both of hubbabubba's tiers — it is the one file
here that cannot be regenerated, since losing house/unit codes means
re-pairing every physical switch by hand. `deploy.env` holds a password and
is *excluded* from both tiers rather than mirrored offsite, so it is the only
copy; `deploy.sh` keeps it at 0600. Losing it costs a new broker password and
a re-deploy of this stack and `e9wikner/homeass`, nothing more.

## What the host has to provide

`deploy.sh` refuses to run until these hold, and says which one failed. On
hubbabubba every one of them is applied by that repo's `podman` role
(`python scripts/install.py --tags podman`).

| Requirement | Why |
|---|---|
| `podman`, plus `netavark`/`aardvark-dns`/`passt`/`catatonit`/`fuse-overlayfs` | The rootless container engine and its network and storage helpers. |
| A subordinate UID/GID range for the deploying account in `/etc/subuid` and `/etc/subgid` | Rootless Podman builds its user namespace from these; they must exist before the first image is built. |
| `loginctl enable-linger <account>` | Without it `/run/user/<uid>` and the session bus only exist while the account is logged in, and the unit would die with the SSH session that started it. |
| A directory at `APPDATA_ROOT` the account can create subdirectories in | Where `tellstick.conf` and the daemon's state live. On hubbabubba it is `/srv/appdata`, a Btrfs subvolume that Snapper snapshots and the backup engine mirrors locally and offsite. |
| A udev rule granting the account `rw` on the TellStick's USB node | The quadlet bind-mounts the whole `/dev/bus/usb` tree so libusb can find the device at whatever devnum it currently has; the ACL is what makes that one node writable to an unprivileged account. hubbabubba declares it as `podman_device_acls` in host_vars, matched on `1781:0c31`. |
| A running MQTT broker | Deployed separately by `e9wikner/homeass`, with `Network=host`, so the bridge reaches it at `127.0.0.1:1883`. |

## First deployment

```bash
cd ~/Development && git clone git@github.com:e9wikner/telldus.git
cd telldus
cp deploy/deploy.env.example deploy/deploy.env          # then edit: broker password
cp deploy/tellstick.conf.example deploy/tellstick.conf  # then edit: devices, serial
deploy/deploy.sh
```

The first run builds `telldus:latest` from this checkout, which takes a
while — there is no published image for this fork (no release, and it carries
USB-passthrough fixes not yet upstream).

If you do not know the controller's serial yet, deploy once with a placeholder
device list, read it out of the startup log, then fill it in and deploy again:

```bash
journalctl --user -u telldus.service | grep serial
```

Pairing a new switch is the same loop: hold the switch's button while running
`podman exec telldus tdtool --learn <device_id>`, then add it to
`deploy/tellstick.conf` and re-deploy. `telldusd` hot-reloads that file via
inotify, so the pairing takes effect without a restart.

## The loop

```bash
# Source change: rebuild and restart
deploy/deploy.sh --build

# Config-only change (pairing, broker settings): no rebuild
deploy/deploy.sh

# A bad build: the previous image is kept as telldus:previous on every
# rebuild, so going back needs neither the network nor a source checkout
deploy/deploy.sh --rollback

# Logs and device control
journalctl --user -u telldus.service -f
podman exec telldus tdtool --list
podman exec telldus tdtool --on 1

# Stop the stack entirely (config and state are left alone)
deploy/deploy.sh --remove
```

## Verification

```bash
# The unit is up and the container is running
systemctl --user status telldus.service
podman ps | grep telldus

# The daemon sees the TellStick and the configured devices
podman exec telldus lsusb | grep 1781:0c31
podman exec telldus tdtool --list

# A switch actually transmits — this is the check that catches the device-ACL
# and user-namespace problems, because tdtool --list passes without either
podman exec telldus tdtool --on 1
podman exec telldus tdtool --off 1

# The bridge is publishing, and Home Assistant is discovering
mosquitto_sub -h 127.0.0.1 -t 'telldus/#' -v -u hubbabubba -P "$MQTT_PASSWORD"
mosquitto_sub -h 127.0.0.1 -t 'homeassistant/#' -v -u hubbabubba -P "$MQTT_PASSWORD"
```

`tdtool --list` succeeding proves less than it looks like: it only queries
`telldusd`'s in-memory config over a local socket and never touches the
device. `tdtool --on` is what exercises the USB path.

## Why the quadlet looks the way it does

`telldus.container.in` argues for each of its decisions in comments — the
host network, the `keep-id:uid=65534` mapping, the bind-mounted bus tree
instead of `AddDevice=`, the separate environment file for the broker
password. Read those before changing it; each one is there because the
obvious alternative was tried and failed in a specific way.
