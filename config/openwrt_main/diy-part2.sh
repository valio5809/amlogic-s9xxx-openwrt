#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: DIY script (After updating feeds — modify the default IP, hostname, theme, add/remove packages, etc.)
# Source code repository: https://github.com/openwrt/openwrt / Branch: main
#========================================================================================================================

# 1. Set the default LAN IP address
default_ip="192.168.1.1"
ip_regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
[[ -n "${1}" && "${1}" != "${default_ip}" && "${1}" =~ ${ip_regex} ]] && {
    echo "Modify default IP address to: ${1}"
    sed -i "/lan) ipad=\${ipaddr:-/s/\${ipaddr:-\"[^\"]*\"}/\${ipaddr:-\"${1}\"}/" package/base-files/*/bin/config_generate
}

# 2. Set the default password for the 'root' user
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow

# 3. Append source repository information and timestamp to release
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d-%H%M)'|g" package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEREPO='github.com/openwrt/openwrt'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCECODE='openwrt'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEBRANCH='main'" >>package/base-files/files/etc/openwrt_release

# 4. Configure ccache
sed -i '/CONFIG_DEVEL/d' .config
sed -i '/CONFIG_CCACHE/d' .config
if [[ "${2}" == "true" ]]
then
    echo "CONFIG_DEVEL=y" >>.config
    echo "CONFIG_CCACHE=y" >>.config
    echo 'CONFIG_CCACHE_DIR="$(TOPDIR)/.ccache"' >>.config
else
    echo '# CONFIG_DEVEL is not set' >>.config
    echo "# CONFIG_CCACHE is not set" >>.config
    echo 'CONFIG_CCACHE_DIR=""' >>.config
fi

# 5. Remove conflicting packages that break defconfig in main branch
rm -rf feeds/packages/net/fwknopd
rm -rf feeds/video/frameworks/qt5

# 6. Add luci-app-amlogic
rm -rf package/luci-app-amlogic
git clone -b main https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic

# 7. Post-config Audio Injection: Ensure ALSA and Sound support are appended to any generated config template
TARGET_CONFIG_DIR="target/linux/amlogic"
if [ -d "$TARGET_CONFIG_DIR" ]; then
    echo "Injecting audio defaults into amlogic target configuration templates..."
    for cfg in "$TARGET_CONFIG_DIR"/config-*; do
        if [ -f "$cfg" ]; then
            echo "Patching target kernel config: $cfg"
            echo "CONFIG_SOUND=y" >> "$cfg"
            echo "CONFIG_SND=y" >> "$cfg"
            echo "CONFIG_SND_TIMER=y" >> "$cfg"
            echo "CONFIG_SND_PCM=y" >> "$cfg"
            echo "CONFIG_SND_HWDEP=y" >> "$cfg"
            echo "CONFIG_SND_RAWMIDI=y" >> "$cfg"
            echo "CONFIG_SND_USB=y" >> "$cfg"
            echo "CONFIG_SND_USB_AUDIO=y" >> "$cfg"
            echo "CONFIG_SND_SOC=y" >> "$cfg"
            echo "CONFIG_SND_SOC_DMAENGINE_PCM=y" >> "$cfg"
            echo "CONFIG_SND_MESON_AXG_SOUND_CARD=y" >> "$cfg"
            echo "CONFIG_SND_MESON_G12A_TOHDMITX=y" >> "$cfg"
        fi
    done
fi

# Also force user-space packages into global config target
cat << 'EOF' >> .config
CONFIG_PACKAGE_kmod-sound-core=y
CONFIG_PACKAGE_kmod-sound-soc-core=y
CONFIG_PACKAGE_kmod-usb-audio=y
CONFIG_PACKAGE_alsa-lib=y
CONFIG_PACKAGE_alsa-utils=y
EOF

echo "All custom audio hooks applied successfully."
