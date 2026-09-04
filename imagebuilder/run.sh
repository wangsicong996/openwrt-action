#!/bin/bash
# Download official ImageBuilder (+ optional SDK), assemble firmware.
set -euo pipefail

RELEASE="${RELEASE:?RELEASE is required, e.g. 25.12.5}"
PACKAGES_FILE="${PACKAGES_FILE:?PACKAGES_FILE is required}"
if [ ! -f "$PACKAGES_FILE" ] && [ -f "${GITHUB_WORKSPACE}/${PACKAGES_FILE}" ]; then
    PACKAGES_FILE="${GITHUB_WORKSPACE}/${PACKAGES_FILE}"
fi
INCLUDE_PASSWALL="${INCLUDE_PASSWALL:-0}"
ROOTFS_PARTSIZE="${ROOTFS_PARTSIZE:-768}"
TARGET="${TARGET:-x86}"
SUBTARGET="${SUBTARGET:-64}"
PROFILE="${PROFILE:-generic}"
DL_BASE="https://downloads.openwrt.org/releases/${RELEASE}/targets/${TARGET}/${SUBTARGET}"
WORK="${GITHUB_WORKSPACE}/workspace"
IB_DIR="${WORK}/imagebuilder"
SDK_DIR="${WORK}/sdk"
FILES_DIR="${WORK}/ib-files"
FW_DIR="${GITHUB_WORKSPACE}/firmware"

mkdir -p "$WORK" "$FW_DIR"
cd "$WORK"

echo "Fetching index from $DL_BASE"
curl -fsSL "$DL_BASE/sha256sums" -o sha256sums

pick_tarball() {
    local pattern="$1"
    awk -v p="$pattern" '$2 ~ p { gsub(/^\*/, "", $2); print $2; exit }' sha256sums
}

IB_TAR="$(pick_tarball '^openwrt-imagebuilder-.*Linux-x86_64\.tar\.zst$')"
if [ -z "$IB_TAR" ]; then
    echo "ERROR: ImageBuilder tarball not found in $DL_BASE/sha256sums"
    grep imagebuilder sha256sums || true
    exit 1
fi
echo "ImageBuilder: $IB_TAR"
curl -fL --retry 5 -o "$IB_TAR" "$DL_BASE/$IB_TAR"
tar --zstd -xf "$IB_TAR"
rm -f "$IB_TAR"
mv openwrt-imagebuilder-* "$IB_DIR"

if [ "$INCLUDE_PASSWALL" = "1" ]; then
    SDK_TAR="$(pick_tarball '^openwrt-sdk-.*Linux-x86_64\.tar\.zst$')"
    if [ -z "$SDK_TAR" ]; then
        echo "ERROR: SDK tarball not found in $DL_BASE/sha256sums"
        grep sdk sha256sums || true
        exit 1
    fi
    echo "SDK: $SDK_TAR"
    curl -fL --retry 5 -o "$SDK_TAR" "$DL_BASE/$SDK_TAR"
    tar --zstd -xf "$SDK_TAR"
    rm -f "$SDK_TAR"
    mv openwrt-sdk-* "$SDK_DIR"

    echo "Adding Passwall feeds to SDK"
    {
        echo "src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main"
        echo "src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main"
        cat "$SDK_DIR/feeds.conf.default"
    } > "$SDK_DIR/feeds.conf.default.tmp"
    mv "$SDK_DIR/feeds.conf.default.tmp" "$SDK_DIR/feeds.conf.default"
    sed -i "s/src-git-full/src-git/g" "$SDK_DIR/feeds.conf.default"

    cd "$SDK_DIR"
    ./scripts/feeds update -a
    ./scripts/feeds install -a -p passwall_packages
    ./scripts/feeds install luci-app-passwall

    cp "$GITHUB_WORKSPACE/imagebuilder/sdk-passwall.config" .config
    make defconfig

    echo "Passwall options after defconfig:"
    grep -E 'passwall|sing-box|xray-core|Geoview|Simple_Obfs|V2ray_Plugin|Iptables_Transparent' .config | grep -v '^#' || true
    if grep -q '^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Geoview=y' .config \
        || grep -q '^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Plugin=y' .config \
        || grep -q '^CONFIG_PACKAGE_luci-app-passwall_Iptables_Transparent_Proxy=y' .config; then
        echo "ERROR: unwanted Passwall extras were re-selected"
        exit 1
    fi

    echo "$(nproc) threads compile Passwall packages in official SDK"
    make package/compile -j"$(nproc)" IGNORE_ERRORS="m n"
    make package/index || true

    mkdir -p "$IB_DIR/packages"
    found=0
    while IFS= read -r -d '' pkg; do
        cp -v "$pkg" "$IB_DIR/packages/"
        found=1
    done < <(find bin/packages -type f \( -name '*.apk' -o -name '*.ipk' \) \
        \( -path '*/passwall_packages/*' -o -path '*/passwall_luci/*' \) -print0)
    if [ "$found" != "1" ]; then
        echo "ERROR: SDK produced no Passwall packages"
        find bin/packages -type f | head -50 || true
        exit 1
    fi
    echo "Copied Passwall packages into ImageBuilder:"
    ls -lh "$IB_DIR/packages"
    cd "$WORK"
fi

bash "$GITHUB_WORKSPACE/imagebuilder/prepare-files.sh" "$FILES_DIR"

PACKAGES="$(grep -vE '^\s*(#|$)' "$PACKAGES_FILE" | tr '\n' ' ')"
echo "ImageBuilder PROFILE=$PROFILE PACKAGES=$PACKAGES"

cd "$IB_DIR"
make image \
    PROFILE="$PROFILE" \
    PACKAGES="$PACKAGES" \
    FILES="$FILES_DIR" \
    ROOTFS_PARTSIZE="$ROOTFS_PARTSIZE"

OUT="$IB_DIR/bin/targets/${TARGET}/${SUBTARGET}"
ls -lh "$OUT"
if [ -f "$OUT/sha256sums" ]; then
    cat "$OUT/sha256sums"
fi

shopt -s nullglob
for f in "$OUT"/*ext4-combined-efi.img.gz \
         "$OUT"/*ext4-combined.img.gz \
         "$OUT"/*squashfs-combined*.img.gz \
         "$OUT"/sha256sums \
         "$OUT"/*.buildinfo \
         "$OUT"/*.manifest \
         "$OUT"/profiles.json; do
    [ -f "$f" ] && cp "$f" "$FW_DIR/"
done
echo "Firmware artifacts:"
ls -lh "$FW_DIR"
if ! ls "$FW_DIR"/*ext4-combined-efi.img.gz >/dev/null 2>&1; then
    echo "ERROR: ext4-combined-efi image missing"
    ls -la "$OUT" || true
    exit 1
fi
