#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: DIY script (After updating feeds — modify the default IP, hostname, theme, add/remove packages, etc.)
# Source code repository: https://github.com/openwrt/openwrt / Branch: main
#========================================================================================================================

# ------------------------------- Main source configuration -------------------------------
#
# Set the default LAN IP address
default_ip="192.168.1.1"
ip_regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
# Override default IP if a valid custom IP is provided as the first argument
[[ -n "${1}" && "${1}" != "${default_ip}" && "${1}" =~ ${ip_regex} ]] && {
    echo "Modify default IP address to: ${1}"
    sed -i "/lan) ipad=\${ipaddr:-/s/\${ipaddr:-\"[^\"]*\"}/\${ipaddr:-\"${1}\"}/" package/base-files/*/bin/config_generate
}

# Set the default password for the 'root' user (change empty password to 'password')
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow

# Append source repository information to etc/openwrt_release
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEREPO='github.com/openwrt/openwrt'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCECODE='openwrt'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEBRANCH='main'" >>package/base-files/files/etc/openwrt_release

# Configure ccache for build acceleration
# Remove existing ccache settings
sed -i '/CONFIG_DEVEL/d' .config
sed -i '/CONFIG_CCACHE/d' .config
# Apply new ccache configuration
if [[ "${2}" == "true" ]]; then
    echo "CONFIG_DEVEL=y" >>.config
    echo "CONFIG_CCACHE=y" >>.config
    echo 'CONFIG_CCACHE_DIR="$(TOPDIR)/.ccache"' >>.config
else
    echo '# CONFIG_DEVEL is not set' >>.config
    echo "# CONFIG_CCACHE is not set" >>.config
    echo 'CONFIG_CCACHE_DIR=""' >>.config
fi
#
# ------------------------------- Main source configuration ends -------------------------------

# ------------------------------- Additional customizations -------------------------------
#
# Add luci-app-amlogic
rm -rf package/luci-app-amlogic
git clone -b main https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic
#
# Comprehensive Sound Support (HDMI Audio, Optical/SPDIF, USB Audio & ALSA core)
# 1. Force-enable Sound drivers in Target Kernel Config
KERNEL_CONFIG=$(ls target/linux/amlogic/config-* | head -n 1)
if [ -f "$KERNEL_CONFIG" ]; then
    echo "Configuring full audio subsystem flags in: $KERNEL_CONFIG"
    sed -i '/CONFIG_SOUND/d' "$KERNEL_CONFIG"
    sed -i '/CONFIG_SND/d' "$KERNEL_CONFIG"
    
    cat << 'EOF' >> "$KERNEL_CONFIG"
CONFIG_SOUND=y
CONFIG_SND=y
CONFIG_SND_TIMER=y
CONFIG_SND_PCM=y
CONFIG_SND_HWDEP=y
CONFIG_SND_RAWMIDI=y
CONFIG_SND_USB=y
CONFIG_SND_USB_AUDIO=y
CONFIG_SND_SOC=y
CONFIG_SND_SOC_DMAENGINE_PCM=y
CONFIG_SND_MESON_AXG_SOUND_CARD=y
CONFIG_SND_MESON_G12A_TOHDMITX=y
EOF
fi

# 2. Force OpenWrt .config to accept sound modules and ALSA utils
sed -i '/CONFIG_PACKAGE_kmod-sound-core/d' .config
sed -i '/CONFIG_PACKAGE_kmod-sound-soc-core/d' .config
sed -i '/CONFIG_PACKAGE_kmod-usb-audio/d' .config
sed -i '/CONFIG_PACKAGE_alsa-lib/d' .config
sed -i '/CONFIG_PACKAGE_alsa-utils/d' .config

cat << 'EOF' >> .config
CONFIG_PACKAGE_kmod-sound-core=y
CONFIG_PACKAGE_kmod-sound-soc-core=y
CONFIG_PACKAGE_kmod-usb-audio=y
CONFIG_PACKAGE_alsa-lib=y
CONFIG_PACKAGE_alsa-utils=y
EOF
#
# Apply patches
# git apply ../config/patches/{0001*,0002*}.patch --directory=feeds/luci
#
# ------------------------------- Additional customizations ends -------------------------------
