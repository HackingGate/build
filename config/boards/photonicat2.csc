# Rockchip RK3576 octa core 4-16GB 2x GbE eMMC HDMI WiFi USB3 3x M.2 (B/E/M-Key)

BOARD_NAME="Photonicat2"
BOARD_VENDOR="ariaboard"
BOARD_MAINTAINER="HackingGate"
BOARDFAMILY="rk35xx"
INTRODUCED="2025"
BOOT_SOC="rk3576"
BOOTCONFIG="photonicat2-rk3576_defconfig"
KERNEL_TARGET="current"
KERNEL_TEST_TARGET="current"
FULL_DESKTOP="no"
BOOT_FDT_FILE="rockchip/rk3576-photonicat2.dtb"
BOOT_SCENARIO="spl-blobs"
IMAGE_PARTITION_TABLE="gpt"
BOARD_FIRMWARE_INSTALL="-full"
ENABLE_EXTENSIONS="radxa-aic8800,photonicat-pm"
AIC8800_TYPE="usb"

# Enable btrfs support in u-boot
enable_extension "uboot-btrfs"

# Mainline U-Boot
function post_family_config__photonicat2_mainline_uboot() {
	display_alert "$BOARD" "Using Mainline U-Boot v2026.04" "info"
	declare -g BOOTSOURCE='https://github.com/u-boot/u-boot.git'
	declare -g BOOTBRANCH='tag:v2026.04'
	declare -g BOOTPATCHDIR='v2026.04'
	declare -g BOOTDIR="u-boot-${BOARD}"

	# Use binman for Mainline U-Boot
	declare -g UBOOT_TARGET_MAP="BL31=${RKBIN_DIR}/${BL31_BLOB} ROCKCHIP_TPL=${RKBIN_DIR}/${DDR_BLOB};;u-boot-rockchip.bin"

	# Disable legacy rockchip processing
	unset uboot_custom_postprocess write_uboot_platform write_uboot_platform_mtd

	# Custom write function for u-boot-rockchip.bin
	function write_uboot_platform() {
		dd "if=$1/u-boot-rockchip.bin" "of=$2" bs=32k seek=1 conv=notrunc status=none
	}
}

# Install USB hub watchdog (recovers onboard USB hubs after warm-reboot drop)
function post_family_tweaks_bsp__install_photonicat2_usb_hub_watchdog() {
	display_alert "$BOARD" "Installing Photonicat2 USB hub watchdog" "info"

	local watchdog_dir="${SRC}/packages/bsp/photonicat2/usb-hub-watchdog"

	install -Dm 0755 "${watchdog_dir}/photonicat-usb-hub-watchdog-run" \
		"${destination}/usr/lib/armbian/photonicat2-usb-hub-watchdog-run"

	install -Dm 0644 "${watchdog_dir}/photonicat-usb-hub-watchdog.service" \
		"${destination}/usr/lib/systemd/system/photonicat-usb-hub-watchdog.service"

	install -Dm 0644 "${watchdog_dir}/photonicat-usb-hub-watchdog.timer" \
		"${destination}/usr/lib/systemd/system/photonicat-usb-hub-watchdog.timer"
}

function post_family_tweaks__enable_photonicat2_usb_hub_watchdog() {
	display_alert "$BOARD" "Enabling Photonicat2 USB hub watchdog" "info"

	if chroot_sdcard systemctl enable photonicat-usb-hub-watchdog.timer; then
		display_alert "$BOARD" "USB hub watchdog enabled" "info"
	else
		display_alert "$BOARD" "Failed to enable photonicat-usb-hub-watchdog.timer" "err"
		return 1
	fi
}

# Install PMU settings persistence (saves/restores user-changed PMU sysfs settings across reboots)
function post_family_tweaks__install_photonicat2_pmu_settings() {
	display_alert "$BOARD" "Installing Photonicat2 PMU settings persistence" "info"

	local pmu_settings_dir="${SRC}/packages/bsp/photonicat2/pmu-settings"

	run_host_command_logged install -m 0755 "${pmu_settings_dir}/photonicat-pmu-settings" \
		"${SDCARD}/usr/local/bin/photonicat-pmu-settings"

	run_host_command_logged install -m 0644 "${pmu_settings_dir}/photonicat-pmu-settings.service" \
		"${SDCARD}/etc/systemd/system/photonicat-pmu-settings.service"

	run_host_command_logged install -m 0644 "${pmu_settings_dir}/photonicat-pmu-settings.path" \
		"${SDCARD}/etc/systemd/system/photonicat-pmu-settings.path"

	chroot_sdcard systemctl enable photonicat-pmu-settings.path || {
		display_alert "$BOARD" "Failed to enable photonicat-pmu-settings.path" "wrn"
	}

	display_alert "$BOARD" "PMU settings persistence installed and enabled" "info"
}

# Add cellular modem packages
function post_family_config__photonicat2_modem_packages() {
	display_alert "$BOARD" "Adding cellular modem packages" "info"
	add_packages_to_image "modemmanager"
	add_packages_to_image "libqmi-utils"
	add_packages_to_image "libmbim-utils"
	add_packages_to_image "usb-modeswitch"
	add_packages_to_image "libxml2-utils"
}

# Add wireless packages
function post_family_config__photonicat2_wireless_packages() {
	display_alert "$BOARD" "Adding wireless packages" "info"
	add_packages_to_image "wpasupplicant"
	add_packages_to_image "hostapd"
}

# Add bluetooth packages
function post_family_config__photonicat2_bluetooth_packages() {
	display_alert "$BOARD" "Adding bluetooth packages" "info"
	add_packages_to_image "bluez"
	add_packages_to_image "bluez-tools"
	add_packages_to_image "bluetooth"
}

# Add additional useful packages
function post_family_config__photonicat2_useful_packages() {
	display_alert "$BOARD" "Adding useful packages" "info"
	add_packages_to_image "lm-sensors"
	add_packages_to_image "qrencode"
	add_packages_to_image "unbound"
	add_packages_to_image "unbound-anchor"
	add_packages_to_image "dnscrypt-proxy"
	add_packages_to_image "emacs-nox"
	add_packages_to_image "vim-nox"
	add_packages_to_image "curl"
	add_packages_to_image "wget"
	add_packages_to_image "netcat-openbsd"
	add_packages_to_image "gh"
	add_packages_to_image "git"
	add_packages_to_image "build-essential"
	add_packages_to_image "clang"
	add_packages_to_image "gcc-aarch64-linux-gnu"
	add_packages_to_image "gcc-arm-linux-gnueabihf"
	add_packages_to_image "mold"
	add_packages_to_image "zsh"
	add_packages_to_image "jq"
	add_packages_to_image "fastfetch"
	add_packages_to_image "htop"
	add_packages_to_image "dkms"
	add_packages_to_image "cargo"
	add_packages_to_image "apt-transport-https"
	add_packages_to_image "ripgrep"
	add_packages_to_image "pkg-config"
	add_packages_to_image "libnm-dev"
	add_packages_to_image "libglib2.0-dev"
	add_packages_to_image "bubblewrap"
	add_packages_to_image "power-profiles-daemon"
	add_packages_to_image "upower"
	add_packages_to_image "tmux"
	add_packages_to_image "unzip"
}

# Add firewalld, cockpit, and DNS packages
function post_family_config__photonicat2_firewall_packages() {
	display_alert "$BOARD" "Adding firewall and networking packages" "info"
	add_packages_to_image "nftables"
	add_packages_to_image "iptables-persistent"
	add_packages_to_image "netfilter-persistent"
	add_packages_to_image "firewalld"
	add_packages_to_image "firewall-config"
	add_packages_to_image "cockpit"
	add_packages_to_image "cockpit-networkmanager"
	add_packages_to_image "cockpit-storaged"
	add_packages_to_image "cockpit-packagekit"
	add_packages_to_image "dnsmasq"
	add_packages_to_image "ndppd"
	add_packages_to_image "radvd"
	add_packages_to_image "dnsutils"
	add_packages_to_image "nfs-kernel-server"
	add_packages_to_image "samba"
	add_packages_to_image "tcpdump"
	add_packages_to_image "traceroute"
	add_packages_to_image "wakeonlan"
	add_packages_to_image "mobile-broadband-provider-info"
}

# Add virtualization packages
function post_family_config__photonicat2_virtualization_packages() {
	display_alert "$BOARD" "Adding virtualization packages" "info"
	add_packages_to_image "qemu-system-arm"
	add_packages_to_image "qemu-utils"
	add_packages_to_image "qemu-efi-aarch64"
	add_packages_to_image "libvirt-daemon-system"
	add_packages_to_image "libvirt-clients"
}

# Copy and install pre-built mini display program
function post_family_tweaks__install_photonicat2_mini_display() {
	display_alert "$BOARD" "Installing Photonicat2 mini display program" "info"

	local resources_dir="${SRC}/packages/bsp/photonicat2/resources"

	# Install pre-built mini display .deb package (includes systemd service)
	display_alert "$BOARD" "Installing mini display .deb package" "info"
	run_host_command_logged cp "${resources_dir}/pcat2_mini_display.deb" "${SDCARD}/tmp/"
	chroot_sdcard dpkg -i /tmp/pcat2_mini_display.deb || {
		display_alert "$BOARD" "Failed to install mini display .deb package" "err"
		return 1
	}
	run_host_command_logged rm "${SDCARD}/tmp/pcat2_mini_display.deb"

	# Enable the systemd service (installed by the deb package)
	display_alert "$BOARD" "Enabling mini display service" "info"
	chroot_sdcard systemctl enable pcat2_mini_display.service || {
		display_alert "$BOARD" "Failed to enable mini display service" "wrn"
	}

	display_alert "$BOARD" "Mini display program installed and enabled successfully" "info"
}

# OLD PRE-CONFIG (commented out 2026-06-20): installs route-config deb at build
# time. Replaced by the route-config-provision first-boot flow (harness set2 /
# RouterPlane/harness#71). Restore when returning to prebaked images.
# function post_family_tweaks__install_photonicat2_router_config() {
# 	display_alert "$BOARD" "Installing route-config package" "info"
#
# 	local router_config_deb_src="${SRC}/packages/bsp/common/resources/route-config_0.17.4-1_arm64.deb"
# 	local router_config_deb_dst="/tmp/route-config_0.17.4-1_arm64.deb"
#
# 	if [[ ! -f "${router_config_deb_src}" ]]; then
# 		display_alert "$BOARD" "route-config deb not found at ${router_config_deb_src}" "err"
# 		return 1
# 	fi
#
# 	run_host_command_logged cp -f "${router_config_deb_src}" "${SDCARD}${router_config_deb_dst}"
# 	chroot_sdcard dpkg -i "${router_config_deb_dst}" || {
# 		display_alert "$BOARD" "Failed to install route-config .deb package" "err"
# 		run_host_command_logged rm -f "${SDCARD}${router_config_deb_dst}"
# 		return 1
# 	}
# 	run_host_command_logged rm -f "${SDCARD}${router_config_deb_dst}"
#
# 	display_alert "$BOARD" "route-config package installed successfully" "info"
# }

# OLD PRE-CONFIG (disabled 2026-06-20): copies rootfs snapshot + installs
# first-boot apply-running-config.service. Replaced by route-config-provision
# (harness set2 / RouterPlane/harness#71). Restore when returning to prebaked images.
: <<'DISABLED_PRE_CONFIG'
function post_family_tweaks__photonicat2_install_running_config_firstboot() {
	display_alert "$BOARD" "Installing first-boot running config apply service" "info"

	local payload_src="${SRC}/local/csc/conf/rootfs/photonicat2"
	local payload_dst="${SDCARD}/usr/local/share/photonicat2-running-config/rootfs"
	local script_path="${SDCARD}/usr/local/sbin/photonicat2-apply-running-config"
	local service_path="${SDCARD}/etc/systemd/system/photonicat2-apply-running-config.service"

	if [[ ! -d "${payload_src}" ]]; then
		display_alert "$BOARD" "Running config payload not found at ${payload_src}" "wrn"
		return 0
	fi

	run_host_command_logged mkdir -p "${payload_dst}" "${SDCARD}/usr/local/sbin" "${SDCARD}/etc/systemd/system"
	run_host_command_logged rsync -a --delete --chown=root:root "${payload_src}/" "${payload_dst}/"

	cat > "${script_path}" <<-'EOF'
		#!/usr/bin/env bash
		set -euo pipefail

		PAYLOAD="/usr/local/share/photonicat2-running-config/rootfs"
		STATE_DIR="/var/lib/photonicat2-running-config"
		STAMP="${STATE_DIR}/applied"
		LOG="/var/log/photonicat2-running-config.log"

		mkdir -p "${STATE_DIR}"
		exec >>"${LOG}" 2>&1

		echo "[$(date -Is)] applying Photonicat2 running config"

		if [[ -e "${STAMP}" ]]; then
			echo "already applied"
			exit 0
		fi

		if [[ ! -d "${PAYLOAD}" ]]; then
			echo "missing payload: ${PAYLOAD}" >&2
			exit 1
		fi

		cp -a "${PAYLOAD}/." /

		if compgen -G "/etc/NetworkManager/system-connections/*.nmconnection" >/dev/null; then
			chown root:root /etc/NetworkManager/system-connections/*.nmconnection
			chmod 600 /etc/NetworkManager/system-connections/*.nmconnection
		fi

		if [[ -f /usr/local/etc/xray/config.json ]]; then
			chown root:root /usr/local/etc/xray/config.json
			chmod 600 /usr/local/etc/xray/config.json
		fi

		if command -v systemctl >/dev/null 2>&1; then
			systemctl daemon-reload || true
			if [[ -d /etc/systemd/logind.conf.d ]]; then
				systemctl restart systemd-logind.service || true
			fi
			systemctl restart systemd-modules-load.service || true
			systemctl restart systemd-sysctl.service || true
		fi

		if command -v sysctl >/dev/null 2>&1; then
			sysctl --system || true
		fi

		date -Is > "${STAMP}"
		systemctl disable photonicat2-apply-running-config.service >/dev/null 2>&1 || true
		echo "[$(date -Is)] Photonicat2 running config applied"
	EOF
	chmod 755 "${script_path}"

	cat > "${service_path}" <<-'EOF'
		[Unit]
		Description=Apply Photonicat2 running-machine config snapshot
		DefaultDependencies=no
		After=local-fs.target
		Before=network-pre.target NetworkManager.service systemd-networkd.service systemd-networkd-wait-online.service firewalld.service nftables.service netfilter-persistent.service dnsmasq.service unbound.service dnscrypt-proxy.service nginx.service xray.service smbd.service nmbd.service multi-user.target
		ConditionPathExists=/usr/local/share/photonicat2-running-config/rootfs
		ConditionPathExists=!/var/lib/photonicat2-running-config/applied

		[Service]
		Type=oneshot
		ExecStart=/usr/local/sbin/photonicat2-apply-running-config

		[Install]
		WantedBy=multi-user.target
	EOF

	chroot_sdcard systemctl --no-reload enable photonicat2-apply-running-config.service
}
DISABLED_PRE_CONFIG
