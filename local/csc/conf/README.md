# Local Machine Configuration Snapshot

This branch keeps local-only snapshots of running-machine configuration for
board-specific Armbian builds.

- `rootfs/nanopi-r6s/` is staged into NanoPi R6S images by
  `config/boards/nanopi-r6s.conf`.
- `rootfs/photonicat2/` is staged into PhotoNICat2 images by
  `config/boards/photonicat2.csc`.
- Each board config writes and enables a board-specific
  `*-apply-running-config.service`, which applies the staged payload on first
  boot before the affected services start.
- `reference/<board>/` contains board-specific machine files that are useful to
  keep, but are not installed automatically because they can break a newly
  generated image.

The service copies the staged native configuration into `/`, fixes permissions
for NetworkManager and Xray, reloads systemd metadata, reapplies
`modules-load.d` and `sysctl.d`, records a stamp under
`/var/lib/<board>-running-config/`, and disables itself.

Covered runtime areas include Samba, firewalld/nftables/netfilter-persistent,
dnsmasq/unbound/dnscrypt-proxy, `modules-load.d`, `sysctl.d`, and
`systemd-networkd`.

The snapshot may contain credentials, private keys, connection UUIDs, endpoint
addresses, and host-specific device identifiers. Keep this branch private.
