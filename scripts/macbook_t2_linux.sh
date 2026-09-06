#!/bin/sh
# Install the Intel MacBook Pro T2 suspend/resume workaround.

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
# shellcheck source=utils.sh
. "${SCRIPT_DIR}/utils.sh"

if [ "$(uname -s)" != "Linux" ]; then
  print_warning "T2 suspend support is only needed on Linux; skipping"
  exit 0
fi

if ! command -v lsmod >/dev/null 2>&1 || ! command -v modinfo >/dev/null 2>&1; then
  print_error "lsmod and modinfo are required to detect T2 hardware"
  exit 1
fi

if ! lsmod | grep -q apple_bce && ! modinfo apple-bce >/dev/null 2>&1; then
  print_warning "Apple T2 hardware was not detected; skipping suspend support"
  exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
  print_error "Run this script with sudo"
  exit 1
fi

print_progress "Configuring T2 suspend/resume support..."

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-t2.XXXXXX")
trap 'rm -rf "$tmp_dir"' 0 HUP INT TERM

# Lid handling stays with Omarchy's lock/suspend and clamshell hooks.
touchbar_source="$tmp_dir/restart-tiny-dfr-when-ready.sh"
touchbar_target="/usr/local/bin/restart-tiny-dfr-when-ready.sh"
cat >"$touchbar_source" <<'EOF'
#!/bin/sh
# Wait up to ten seconds for the Touch Bar device, then restart tiny-dfr.

i=0
while [ "$i" -lt 10 ]; do
  if [ -e /dev/tiny_dfr_display ]; then
    systemctl restart tiny-dfr.service
    exit 0
  fi
  i=$((i + 1))
  sleep 1
done

systemctl restart tiny-dfr.service || true
EOF

if ! cmp -s "$touchbar_source" "$touchbar_target"; then
  install -m 0755 "$touchbar_source" "$touchbar_target"
  print_success "  ✓ Installed Touch Bar restart helper"
  track_change
else
  print_info "  → Touch Bar restart helper is current"
fi

service_source="$tmp_dir/suspend-fix-t2.service"
service_target="/etc/systemd/system/suspend-fix-t2.service"
cat >"$service_source" <<'EOF'
[Unit]
Description=Reset Apple BCE modules around T2 suspend/resume
Before=sleep.target
StopWhenUnneeded=yes

[Service]
User=root
Type=oneshot
RemainAfterExit=yes

# Unload before suspend in reverse dependency order. A module may already be
# absent, so '-' keeps the remaining recovery steps running.
ExecStart=-/usr/bin/modprobe -r hid_appletb_kbd
ExecStart=-/usr/bin/modprobe -r hid_appletb_bl
ExecStart=-/usr/bin/rmmod -f apple-bce

# Reload after resume in dependency order and let hardware settle between steps.
ExecStop=/usr/bin/sleep 2
ExecStop=-/usr/bin/modprobe apple-bce
ExecStop=/usr/bin/sleep 2
ExecStop=-/usr/bin/modprobe hid_appletb_bl
ExecStop=/usr/bin/sleep 1
ExecStop=-/usr/bin/modprobe hid_appletb_kbd
ExecStop=/usr/local/bin/restart-tiny-dfr-when-ready.sh

[Install]
WantedBy=sleep.target
EOF

if ! cmp -s "$service_source" "$service_target"; then
  install -m 0644 "$service_source" "$service_target"
  systemctl daemon-reload
  track_change
  print_success "  ✓ Installed systemd suspend service"
else
  print_info "  → Systemd suspend service is current"
fi

if ! systemctl is-enabled suspend-fix-t2.service >/dev/null 2>&1; then
  systemctl enable suspend-fix-t2.service >/dev/null
  track_change
  print_success "  ✓ Enabled systemd suspend service"
else
  print_info "  → Systemd suspend service is enabled"
fi

rm -rf "$tmp_dir"
trap - 0 HUP INT TERM

print_conditional_success "T2 suspend/resume support"
