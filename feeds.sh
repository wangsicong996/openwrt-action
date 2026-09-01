#########################################################################
# File Name: feeds.sh
# author: Carbon (ecrasy@gmail.com)
# Description: feel free to use
# Created Time: 2022-07-23 13:04:43 UTC
# Modified Time: 2026-09-02 06:55:00 UTC
#########################################################################

#!/bin/bash

echo -e "\n# Custom feeds for OpenWrt" >> feeds.conf.default

# add custom packages
echo "Adding custom packages"
echo "src-git CustomPkgs https://github.com/ecrasy/custom-packages.git;for_official" >> feeds.conf.default

# passwall: official Openwrt-Passwall repos (xiaorouji transferred to this org)
echo "Adding Openwrt-Passwall (luci + packages)"
echo "src-git PWpackages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git PWluci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main" >> feeds.conf.default

# passwall2
echo "Adding xiaorouji Passwall2"
echo "src-git Passwall2 https://github.com/xiaorouji/openwrt-passwall2.git;main" >> feeds.conf.default

# ssrp
echo "Adding ShadowSocksR Plus"
echo "src-git ssrp https://github.com/ecrasy/ssrp.git;main" >> feeds.conf.default

echo "Remove git full clone"
sed -i "s/src-git-full/src-git/g" feeds.conf.default

echo "Adding Feeds Completed!!!"
