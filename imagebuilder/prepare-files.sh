#!/bin/bash
# Overlay for official ImageBuilder (banner, LAN IP, model name).
set -euo pipefail

DEST="${1:?usage: prepare-files.sh DEST_DIR}"
ROOT="$GITHUB_WORKSPACE"
mkdir -p "$DEST/etc/uci-defaults" "$DEST/etc/hotplug.d/iface"

cp "$ROOT/data/etc/banner" "$DEST/etc/banner"
cp "$ROOT/data/etc/model.sh" "$DEST/etc/model.sh"
chmod 0755 "$DEST/etc/model.sh"
cp "$ROOT/data/etc/92-ula-prefix" "$DEST/etc/hotplug.d/iface/92-ula-prefix"
chmod 0755 "$DEST/etc/hotplug.d/iface/92-ula-prefix"

cat > "$DEST/etc/uci-defaults/99-lan-ip" << 'EOF'
#!/bin/sh
uci -q set network.lan.ipaddr='192.168.2.1'
uci -q commit network
exit 0
EOF
chmod 0755 "$DEST/etc/uci-defaults/99-lan-ip"

echo "ImageBuilder files overlay ready: $DEST"
