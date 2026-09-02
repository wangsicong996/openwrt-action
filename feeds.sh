#########################################################################
# File Name: feeds.sh
# author: Carbon (ecrasy@gmail.com)
# Description: feel free to use
# Created Time: 2022-07-23 13:04:43 UTC
# Modified Time: 2026-09-02 16:58:00 UTC
#########################################################################

#!/bin/bash

# Passwall official feeds MUST be at the top so latest cores win.
# xiaorouji transferred the project to Openwrt-Passwall.
# https://github.com/Openwrt-Passwall/openwrt-passwall
{
  echo "src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main"
  echo "src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main"
  cat feeds.conf.default
} > feeds.conf.default.tmp
mv feeds.conf.default.tmp feeds.conf.default
echo "Added Openwrt-Passwall (luci-app-passwall + packages) at top of feeds.conf.default"

echo -e "\n# Custom feeds for OpenWrt" >> feeds.conf.default

echo "Adding custom packages"
echo "src-git CustomPkgs https://github.com/ecrasy/custom-packages.git;for_official" >> feeds.conf.default

echo "Adding ShadowSocksR Plus"
echo "src-git ssrp https://github.com/ecrasy/ssrp.git;main" >> feeds.conf.default

echo "Remove git full clone"
sed -i "s/src-git-full/src-git/g" feeds.conf.default

echo "Adding Feeds Completed!!!"
