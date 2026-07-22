#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

# 【修改点 1】增加 qualcommbe 架构支持，确保 SBE1V1K 能够成功修改默认 Wi-Fi 名称和密码
WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax,qualcommbe}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config
#daed eBPF/BTF内核底层特性要求
echo "CONFIG_KERNEL_DEBUG_INFO=y" >> ./.config
echo "CONFIG_KERNEL_DEBUG_INFO_REDUCED=n" >> ./.config
echo "CONFIG_KERNEL_DEBUG_INFO_BTF=y" >> ./.config
echo "CONFIG_KERNEL_CGROUPS=y" >> ./.config
echo "CONFIG_KERNEL_CGROUP_BPF=y" >> ./.config
echo "CONFIG_KERNEL_BPF_EVENTS=y" >> ./.config
echo "CONFIG_BPF_TOOLCHAIN_HOST=y" >> ./.config
echo "CONFIG_KERNEL_XDP_SOCKETS=y" >> ./.config
echo "CONFIG_PACKAGE_kmod-xdp-sockets-diag=y" >> ./.config

# 【修改点 2】专门针对 SBE1V1K (qualcommbe) 注入高通 Wi-Fi 7 闭源固件支持
if [[ "${WRT_TARGET^^}" == *"QUALCOMMBE"* || "${WRT_TARGET^^}" == *"IPQ9574"* || "${WRT_TARGET^^}" == *"IPQ95XX"* ]]; then
	echo "Detected qualcommbe (SBE1V1K/IPQ9574) platform, injecting ath12k firmware..."
	
	# 强制将闭源驱动依赖写入配置文件
	echo "CONFIG_PACKAGE_kmod-ath12k=y" >> ./.config
	echo "CONFIG_PACKAGE_ath12k-firmware-ipq9574=y" >> ./.config
	echo "CONFIG_PACKAGE_ath12k-firmware-qcn9274=y" >> ./.config

	# 【新增的终极修复代码】暴力删除源码中其它机型写错的幽灵依赖！
	echo "Fixing OpenWrt source code bugs for ALL_PROFILES..."
	find target/linux/qualcommbe/ -type f -name "*.mk" -exec sed -i 's/ath11k-firmware-ipq9574//g' {} +
	find target/linux/qualcommbe/ -type f -name "*.mk" -exec sed -i 's/kmod-qrtr-smd//g' {} +
fi

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi
