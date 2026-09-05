#!/usr/bin/env bash
#
# Deploy telldusd and the telldus-mqtt bridge as a rootless Podman quadlet,
# from a checkout of this repo ON the target host (hubbabubba).
#
# This is the whole deployment for that host. There is no
# configuration-management run behind it and no workstation step: you SSH to
# the server, build, and deploy. The generic Docker and native paths in the
# top-level README are unaffected — this directory is additive.
#
# Usage:
#   deploy/deploy.sh               build if the image is missing, then deploy
#   deploy/deploy.sh --build       rebuild the image even if it exists
#   deploy/deploy.sh --no-build    never build; fail if the image is missing
#   deploy/deploy.sh --rollback    re-tag telldus:previous as :latest, restart
#   deploy/deploy.sh --remove      stop the unit and remove the quadlet
#
# Deliberately no sudo anywhere: every path it writes is either inside this
# account's home or inside a directory the host granted this account
# ownership of. If a step here asks for a password, something about the host
# preparation is wrong — fix that, do not run this with sudo.

set -euo pipefail

deploy_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "${deploy_dir}/.." && pwd)"
env_file="${deploy_dir}/deploy.env"
conf_file="${deploy_dir}/tellstick.conf"
quadlet_dir="${HOME}/.config/containers/systemd"
image=telldus:latest
previous=telldus:previous

build=auto
remove=false
rollback=false

die() { printf 'deploy.sh: %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) build=always ;;
    --no-build) build=never ;;
    --rollback) rollback=true ;;
    --remove) remove=true ;;
    -h|--help) sed -n '3,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

# --------------------------------------------------------------------------
# Preflight. Each check names what fixes it rather than just failing — the
# host preparation these depend on is documented in deploy/README.md and, on
# hubbabubba, applied by that repo's `podman` role.
# --------------------------------------------------------------------------
[[ ${EUID} -ne 0 ]] || die "run this as the unprivileged account that owns the stack, not as root."

command -v podman >/dev/null 2>&1 || die "podman is not installed on this host."

# Without lingering, /run/user/<uid> and its D-Bus session only exist while
# this account is logged in, so the unit below would die with the SSH session
# that started it.
if [[ ! -e "/var/lib/systemd/linger/${USER}" ]]; then
  die "lingering is not enabled for ${USER}: user units would stop when you log out.
     Fix on the host, as an account with sudo: loginctl enable-linger ${USER}"
fi

# --------------------------------------------------------------------------
# Removal and rollback. Both are complete operations on their own, so they
# run before anything is rendered.
# --------------------------------------------------------------------------
if [[ ${remove} == true ]]; then
  # Removing the quadlet, not just declining to render it: a file left in the
  # drop-in directory keeps being picked up by the user systemd generator, so
  # the stack would come back on the next daemon-reload or reboot. Appdata is
  # left alone — it is the data, not the deployment.
  step "Stopping telldus.service"
  systemctl --user disable --now telldus.service 2>/dev/null || true
  rm -f "${quadlet_dir}/telldus.container"
  systemctl --user daemon-reload
  echo
  echo "Quadlet removed. Config and state are untouched."
  exit 0
fi

if [[ ${rollback} == true ]]; then
  podman image exists "${previous}" \
    || die "no ${previous} image to roll back to. It is only created by a build here,
     so there is nothing to return to until this script has rebuilt at least once."
  step "Rolling back to ${previous}"
  podman tag "${previous}" "${image}"
  systemctl --user restart telldus.service
  systemctl --user --no-pager --lines=0 status telldus.service || true
  exit 0
fi

[[ -f ${env_file} ]] || die "${env_file} does not exist.
     Copy it from the example and fill in this host's values:
       cp ${deploy_dir}/deploy.env.example ${env_file}"

# 0600 before reading, not after: this file holds the broker password, and a
# `cp` from the example leaves it at the ambient umask (usually 0644). It is
# also what makes hubbabubba's backup exclusion for `**/deploy.env` correct
# rather than merely cautious — an unreadable file that is NOT excluded makes
# the offsite Syncthing tier park a permanent folder error.
chmod 0600 "${env_file}"

# shellcheck source=/dev/null
source "${env_file}"

for var in APPDATA_ROOT MQTT_BROKER_HOST MQTT_BROKER_PORT MQTT_USERNAME \
           MQTT_PASSWORD MQTT_CLIENT_ID MQTT_TOPIC_PREFIX \
           MQTT_DISCOVERY_PREFIX MQTT_QOS; do
  [[ -n ${!var:-} ]] || die "${var} is not set in ${env_file} (see deploy.env.example)."
done
[[ ${MQTT_PASSWORD} != CHANGE_ME ]] || die "MQTT_PASSWORD is still the example placeholder.
     It must match the broker password in e9wikner/homeass's own deploy.env."

[[ -f ${conf_file} ]] || die "${conf_file} does not exist.
     It is the device pairing (house/unit codes) this deployment transmits with.
     Copy it from the example and edit:
       cp ${deploy_dir}/tellstick.conf.example ${conf_file}"

if grep -q 'CHANGE_ME' "${conf_file}"; then
  die "${conf_file} still contains CHANGE_ME — the controller serial was never filled in.
     Find it in the container's startup log:
       journalctl --user -u telldus.service | grep serial"
fi

appdata="${APPDATA_ROOT}/telldus"

# --------------------------------------------------------------------------
# Rendering. Replace @TOKEN@ placeholders with values that are treated as
# literal text throughout: paths contain '/', which sed would read as its own
# delimiter.
#
# Split-and-rejoin rather than the obvious ${content//token/value}, because
# bash 5.2 changed pattern substitution so that an unescaped '&' in the
# REPLACEMENT expands to whatever the pattern matched. A value containing '&'
# would therefore render correctly on an older bash and silently wrong on a
# newer one. Prefix/suffix removal has no such interpretation on any version.
# --------------------------------------------------------------------------
render() {
  local src=$1 dst=$2 content token value out head
  shift 2
  content=$(<"${src}")
  while [[ $# -gt 0 ]]; do
    token="@$1@"
    value=$2
    shift 2
    out=''
    while [[ ${content} == *"${token}"* ]]; do
      head=${content%%"${token}"*}
      out+="${head}${value}"
      content=${content#*"${token}"}
    done
    content="${out}${content}"
  done
  printf '%s\n' "${content}" > "${dst}"
}

step "Creating appdata directories under ${APPDATA_ROOT}"
# The parent itself is never created here: it belongs to the host, and
# silently making a plain directory where a Btrfs subvolume was expected
# would take this stack's state outside snapshots and backups without saying
# so.
[[ -d ${APPDATA_ROOT} ]] || die "${APPDATA_ROOT} does not exist.
     It is the host's to provide (on hubbabubba, the @docker subvolume mounted
     there) — creating it here would put this stack's state outside snapshots
     and backups. See deploy/README.md, \"What the host has to provide\"."
mkdir -p "${appdata}/state"
chmod 0750 "${appdata}"

# --------------------------------------------------------------------------
# The image. There is no registry tag for this fork — no published image, and
# it carries USB-passthrough fixes not yet upstream — so the host builds it
# from this checkout.
#
# Plain `podman build`, not scripts/build-docker.sh: that script drives
# `docker buildx ... --load`, and hubbabubba has no Docker CLI or buildx
# plugin. The Dockerfile is a standard multi-stage build with nothing
# buildx-specific in it, so the result is the same image.
#
# :latest is re-tagged to :previous BEFORE each build, which is the only
# reason --rollback has anything to return to.
# --------------------------------------------------------------------------
if [[ ${build} == always ]] || { [[ ${build} == auto ]] && ! podman image exists "${image}"; }; then
  if podman image exists "${image}"; then
    step "Tagging the current image as ${previous}"
    podman tag "${image}" "${previous}"
  fi
  step "Building ${image}"
  podman build --tag "${image}" "${repo_dir}"
elif [[ ${build} == never ]] && ! podman image exists "${image}"; then
  die "${image} does not exist and --no-build was given."
else
  echo "==> Using the existing ${image} (--build to rebuild)"
fi

# tellstick.conf is world-readable, not just owner-readable: telldusd runs as
# `nobody` inside the container, which under this quadlet's user namespace
# mapping is the deploying account — but the brief root phase before the
# privilege drop reads it too, and 0644 costs nothing here. House and unit
# codes are pairing data, not credentials; the broker password is in the env
# file below, which is 0600.
step "Installing tellstick.conf"
install -m 0644 "${conf_file}" "${appdata}/tellstick.conf"

# 0600: this file holds the broker password. Podman reads it on the host, as
# this account, before the container starts — nothing inside the container
# ever opens it, so nothing needs wider access.
step "Writing the bridge environment"
# umask, not a chmod after the fact: `cat >` would otherwise create the file
# at the ambient umask and hold the password at that mode for as long as the
# write takes.
_old_umask=$(umask)
umask 077
cat > "${appdata}/mqtt.env" <<ENV
# Written by deploy/deploy.sh from deploy/deploy.env — do not edit here.
MQTT_BROKER_HOST=${MQTT_BROKER_HOST}
MQTT_BROKER_PORT=${MQTT_BROKER_PORT}
MQTT_USERNAME=${MQTT_USERNAME}
MQTT_PASSWORD=${MQTT_PASSWORD}
MQTT_CLIENT_ID=${MQTT_CLIENT_ID}
MQTT_TOPIC_PREFIX=${MQTT_TOPIC_PREFIX}
MQTT_DISCOVERY_PREFIX=${MQTT_DISCOVERY_PREFIX}
MQTT_QOS=${MQTT_QOS}
ENV
umask "${_old_umask}"
chmod 0600 "${appdata}/mqtt.env"

step "Rendering the quadlet into ${quadlet_dir}"
mkdir -p "${quadlet_dir}"
render "${deploy_dir}/telldus.container.in" \
       "${quadlet_dir}/telldus.container" \
       APPDATA_ROOT "${APPDATA_ROOT}"

# The generator only turns .container files into services on daemon-reload,
# and a new image or a changed env file needs a restart on top of that — so
# both, unconditionally, rather than trying to work out what changed.
# tellstick.conf is the exception: telldusd hot-reloads it via inotify, so a
# pairing-only change would not have needed the restart.
step "Reloading and restarting the unit"
systemctl --user daemon-reload
systemctl --user enable telldus.service >/dev/null 2>&1 || true
systemctl --user restart telldus.service

step "Status"
systemctl --user --no-pager --lines=0 status telldus.service || true

cat <<EOF

Deployed.

  podman exec telldus tdtool --list
  journalctl --user -u telldus.service -f
  mosquitto_sub -h ${MQTT_BROKER_HOST} -t '${MQTT_TOPIC_PREFIX}/#' -v \\
    -u ${MQTT_USERNAME} -P "\$MQTT_PASSWORD"
EOF
