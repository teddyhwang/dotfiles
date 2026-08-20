#!/bin/sh
# Installation script for Intel MacBook Pro T2 Suspend/Resume Fix
# This script installs all necessary components to make suspend/resume work properly
# This script is idempotent and can be run multiple times safely

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/utils.sh
. "${SCRIPT_DIR}/utils.sh"

# Check if we're on Linux
if [ "$(uname -s)" != "Linux" ]; then
  print_warning "T2 suspend fix is only needed on Linux systems, skipping..."
  exit 0
fi

# Check if apple-bce module exists (indicates T2 hardware)
if ! lsmod | grep -q apple_bce && ! modinfo apple-bce >/dev/null 2>&1; then
  print_warning "Apple T2 hardware not detected (no apple-bce module), skipping suspend fix..."
  exit 0
fi

print_progress "Configuring T2 Suspend/Resume Fix..."

# Check if running with sufficient privileges
if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO_USER" ]; then
  print_error "This script needs to be run with sudo"
  exit 1
fi

# Lid handling is no longer installed here. Omarchy 4 binds the lid switch to
# omarchy-system-lid-close (lock + suspend) and omarchy-hyprland-monitor-clamshell
# (display reconciliation) in default/hypr/bindings/utilities.lua.

# Create the Touch Bar restart helper script
TOUCHBAR_SCRIPT="/usr/local/bin/restart-tiny-dfr-when-ready.sh"
if [ ! -f "$TOUCHBAR_SCRIPT" ] || ! grep -q "Wait for Touch Bar devices to be ready" "$TOUCHBAR_SCRIPT" 2>/dev/null; then
  cat > "$TOUCHBAR_SCRIPT" << 'EOF'
#!/bin/bash
# Wait for Touch Bar devices to be ready, then restart tiny-dfr

# Wait up to 10 seconds for the device to appear
for i in {1..10}; do
  if [ -e /dev/tiny_dfr_display ]; then
      # Device found, restart tiny-dfr
      systemctl restart tiny-dfr.service
      exit 0
  fi
  sleep 1
done

# If we get here, device didn't appear in time
# Try restarting anyway as a fallback
systemctl restart tiny-dfr.service || true
exit 0
EOF
  chmod 755 "$TOUCHBAR_SCRIPT"
  print_success "  ✓ Installed Touch Bar restart helper"
else
  print_info "  → Touch Bar restart helper already exists, skipping"
fi

# Create the systemd service
SYSTEMD_SERVICE="/etc/systemd/system/suspend-fix-t2.service"
SERVICE_NEEDS_RELOAD=0

if [ ! -f "$SYSTEMD_SERVICE" ]; then
  cat > "$SYSTEMD_SERVICE" << 'EOF'
[Unit]
Description=Disable and Re-Enable Apple BCE Module for T2 Suspend/Resume (with Touch Bar support)
Before=sleep.target
StopWhenUnneeded=yes

[Service]
User=root
Type=oneshot
RemainAfterExit=yes

# Unload modules before suspend in reverse dependency order
# Touch Bar keyboard driver depends on backlight driver, both depend on apple-bce
ExecStart=/usr/bin/modprobe -r hid_appletb_kbd
ExecStart=/usr/bin/modprobe -r hid_appletb_bl
ExecStart=/usr/bin/rmmod -f apple-bce

# Reload modules after resume in correct dependency order
# Wait 2 seconds for hardware to settle
ExecStop=/usr/bin/sleep 2
ExecStop=/usr/bin/modprobe apple-bce
ExecStop=/usr/bin/sleep 2
ExecStop=/usr/bin/modprobe hid_appletb_bl
ExecStop=/usr/bin/sleep 1
ExecStop=/usr/bin/modprobe hid_appletb_kbd
# Run script that waits for devices and restarts tiny-dfr
ExecStop=/usr/local/bin/restart-tiny-dfr-when-ready.sh

[Install]
WantedBy=sleep.target
EOF
  SERVICE_NEEDS_RELOAD=1
  print_success "  ✓ Installed systemd suspend service"
else
  print_info "  → Systemd service already exists, skipping"
fi

# Reload systemd and enable the service if needed
if [ $SERVICE_NEEDS_RELOAD -eq 1 ]; then
  systemctl daemon-reload
fi

if ! systemctl is-enabled suspend-fix-t2.service >/dev/null 2>&1; then
  systemctl enable suspend-fix-t2.service >/dev/null 2>&1
  print_success "  ✓ Enabled systemd service"
else
  print_info "  → Systemd service already enabled"
fi

print_success "T2 suspend/resume fix configured successfully!"
