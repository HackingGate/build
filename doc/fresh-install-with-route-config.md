# Fresh-install via route-config REST API

The old pre-config mechanism (board configs that rsync a reference snapshot
into `/usr/local/share/<board>-running-config/` and apply it on first boot via
a oneshot systemd service) is **disabled** as of 2026-06-20. Instead, a freshly
flashed system is configured by driving the route-config REST API — the same
flow the RouterPlane harness tests as "set2" (route-config-applied).

## Prerequisites

On a newly-flashed Armbian system (no pre-config):

```bash
# 1. Install the route-config packages (route-configd + route-config-rest).
#    The .debs come from RouterPlane/route-config releases; drop them in and:
dpkg -i /tmp/route-config_0.17.4-1_arm64.deb

# 2. Enable and start the gateway. Services are not enabled at boot yet —
#    the provisioning steps below will do that selectively.
systemctl start route-configd.service route-config-rest.service

# 3. Wait for the REST gateway to be healthy.
until curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8553/v1/status \
  | grep -q 200; do sleep 1; done
```

All subsequent steps are `POST /v1/<object>/<method>` calls with JSON bodies.
Success is HTTP 200 with `{"ok": ...}` in the response.

## nanopi-r6s (home-gateway)

This device runs as a home gateway/router/server behind an IPv6/MAP-E WAN.
It provides xray VLESS Reality server, dnsmasq DHCP/DNS, and firewall/NAT.

### 1. System config — kernel modules, forwarding, RA acceptance

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/system/write-system-config \
  -H 'Content-Type: application/json' -d '{
  "wan_interfaces": ["wan-main"],
  "config": {
    "bridge_module": true,
    "br_netfilter_module": true,
    "ipv4_forward": true,
    "ipv6_forward": true,
    "wan_accept_ra": 2,
    "wan_accept_ra_defrtr": true,
    "wan_autoconf": true,
    "wan_use_tempaddr": 0
  }
}'
```

### 2. TCP BBR (optional; can fail without blocking)

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/system/install-tcp-bbr-module \
  -H 'Content-Type: application/json' -d '{}'
curl -sS -X POST http://127.0.0.1:8553/v1/system/apply-tcp-config \
  -H 'Content-Type: application/json' -d '{"congestion_control":"bbr"}'
```

### 3. WAN ethernet (ens3, external zone, DHCP)

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/network/configure-ethernet \
  -H 'Content-Type: application/json' -d '{
  "connection": {
    "id": "wan-main",
    "interface_name": "ens3",
    "connection_type": "ethernet",
    "zone": "external",
    "autoconnect": true,
    "autoconnect_priority": 10,
    "master": null,
    "slave_type": null
  },
  "ipv4_method": "auto",
  "ipv4_addresses": [],
  "ipv4_gateway": null,
  "ipv4_dns": [],
  "ipv6_method": "auto",
  "ipv6_addresses": [],
  "ipv6_gateway": null,
  "ipv4_route_metric": "10",
  "ipv6_route_metric": null
}'
```

### 4. LAN bridge (br0 on ens4, 192.168.6.1/24, internal zone)

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/network/configure-bridge \
  -H 'Content-Type: application/json' -d '{
  "connection": {
    "id": "br0",
    "interface_name": "br0",
    "connection_type": "bridge",
    "zone": "internal",
    "autoconnect": true,
    "autoconnect_priority": 0,
    "master": null,
    "slave_type": null
  },
  "ipv4_method": "manual",
  "ipv4_addresses": ["192.168.6.1/24"],
  "ipv6_method": "manual",
  "ipv6_addresses": ["fd00:168:6::1/64"],
  "stp": true
}'

curl -sS -X POST http://127.0.0.1:8553/v1/network/add-bridge-slave \
  -H 'Content-Type: application/json' -d '["br0","ens4"]'
```

### 5. Router forwarding (LAN ↔ WAN)

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/system/configure-router-forwarding \
  -H 'Content-Type: application/json' -d '{
  "lan_bridge": "br0",
  "lan_conn": "br0",
  "lan_cidr": "192.168.6.1/24",
  "wan_interface": "ens3",
  "wan_conn": "wan-main",
  "lan_interfaces": ["ens4"],
  "lan_zone": "internal",
  "wan_zone": "external"
}'
```

### 6. Firewall NAT + masquerade

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/firewall/configure-router-nat \
  -H 'Content-Type: application/json' -d '{
  "lan_interface": "br0",
  "lan_network_v4": "192.168.6.0/24",
  "lan_network_v6": null,
  "wan_interfaces": ["ens3"],
  "isolated_lan_interfaces": []
}'

curl -sS -X POST http://127.0.0.1:8553/v1/firewall/enable-masquerade \
  -H 'Content-Type: application/json' -d '"external"'
```

### 7. Open xray VLESS server port

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/firewall/add-port \
  -H 'Content-Type: application/json' -d '["internal",{"port":"13600","protocol":"tcp"}]'
```

### 8. DNS/DHCP (dnsmasq on br0)

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/dns/write-config \
  -H 'Content-Type: application/json' -d '{
  "interface": "br0",
  "listen_addresses": ["192.168.6.1"],
  "mode": "custom",
  "upstream_servers": ["1.1.1.1"],
  "dns_forward_max": 1000,
  "advertise_dns_v4": ["192.168.6.1"],
  "advertise_dns_v6": [],
  "captive_portal_url": null,
  "dhcp_range_start": "192.168.6.100",
  "dhcp_range_end": "192.168.6.200",
  "dhcp_lease_time": 12,
  "gateway": "192.168.6.1",
  "enable_ra": true,
  "ipv6_mode": "server",
  "ipv6_prefix": null,
  "ipv6_relay_wan_interface": null,
  "reservations": [],
  "dns_entries": [],
  "log_dhcp": false
}'
```

### 9. xray VLESS Reality server config

Write the xray config to `/etc/xray/config.json` (the harness writes it directly;
the Proxy API may not cover all Reality fields). Use the same keys and UUIDs as
your current running device. Example:

```json
{
  "log": {"loglevel": "warning", "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log"},
  "inbounds": [{
    "port": 13600, "protocol": "vless",
    "settings": {"clients": [{"id": "<YOUR-UUID>", "flow": "xtls-rprx-vision"}], "decryption": "none"},
    "streamSettings": {
      "network": "tcp", "security": "reality",
      "realitySettings": {
        "dest": "127.0.0.1:8443",
        "serverNames": ["localhost"],
        "privateKey": "<YOUR-PRIVATE-KEY>",
        "shortIds": ["<YOUR-SHORT-ID>"]
      }
    }
  }],
  "outbounds": [{"protocol": "freedom", "tag": "direct"}, {"protocol": "blackhole", "tag": "block"}],
  "routing": {"rules": []}
}
```

Then restart xray:
```bash
systemctl restart xray-core.service
```

### 10. Enable services at boot

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/dns/enable-on-boot \
  -H 'Content-Type: application/json' -d '{}'
curl -sS -X POST http://127.0.0.1:8553/v1/firewall/enable-on-boot \
  -H 'Content-Type: application/json' -d '{}'
```

### 11. MAP-E tunnel

On real hardware (NTT/KDDI IPv6 + MAP-E), the wanmap interface is configured
separately. The harness lab uses a simplified MAP-E topology without a real
tunnel endpoint; use `nmcli` or the MAP-E API on real hardware.

---

## photonicat2 (travel-router)

This device is a travel router that connects to the home-gateway's xray server
when at home, or to a modem/other upstream when away.

### 1. System config

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/system/write-system-config \
  -H 'Content-Type: application/json' -d '{
  "wan_interfaces": ["wan-main"],
  "config": {
    "bridge_module": true,
    "br_netfilter_module": true,
    "ipv4_forward": true,
    "ipv6_forward": false,
    "wan_accept_ra": 0,
    "wan_accept_ra_defrtr": false,
    "wan_autoconf": true,
    "wan_use_tempaddr": 0
  }
}'
```

### 2. WAN ethernet (ens3, DHCP client)

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/network/configure-ethernet \
  -H 'Content-Type: application/json' -d '{
  "connection": {
    "id": "wan-main",
    "interface_name": "ens3",
    "connection_type": "ethernet",
    "zone": "external",
    "autoconnect": true,
    "autoconnect_priority": 10,
    "master": null,
    "slave_type": null
  },
  "ipv4_method": "auto",
  "ipv4_addresses": [],
  "ipv4_gateway": null,
  "ipv4_dns": [],
  "ipv6_method": "auto",
  "ipv6_addresses": [],
  "ipv6_gateway": null,
  "ipv4_route_metric": "10",
  "ipv6_route_metric": null
}'
```

### 3. LAN bridge (br0 on ens4, 172.16.0.1/24, internal zone)

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/network/configure-bridge \
  -H 'Content-Type: application/json' -d '{
  "connection": {
    "id": "br0",
    "interface_name": "br0",
    "connection_type": "bridge",
    "zone": "internal",
    "autoconnect": true,
    "autoconnect_priority": 0,
    "master": null,
    "slave_type": null
  },
  "ipv4_method": "manual",
  "ipv4_addresses": ["172.16.0.1/24"],
  "ipv6_method": "manual",
  "ipv6_addresses": ["fd00:16::1/64"],
  "stp": true
}'

curl -sS -X POST http://127.0.0.1:8553/v1/network/add-bridge-slave \
  -H 'Content-Type: application/json' -d '["br0","ens4"]'
```

### 4. Router forwarding (LAN ↔ WAN)

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/system/configure-router-forwarding \
  -H 'Content-Type: application/json' -d '{
  "lan_bridge": "br0",
  "lan_conn": "br0",
  "lan_cidr": "172.16.0.1/24",
  "wan_interface": "ens3",
  "wan_conn": "wan-main",
  "lan_interfaces": ["ens4"],
  "lan_zone": "internal",
  "wan_zone": "external"
}'
```

### 5. Firewall NAT + masquerade

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/firewall/configure-router-nat \
  -H 'Content-Type: application/json' -d '{
  "lan_interface": "br0",
  "lan_network_v4": "172.16.0.0/24",
  "lan_network_v6": null,
  "wan_interfaces": ["ens3"],
  "isolated_lan_interfaces": []
}'

curl -sS -X POST http://127.0.0.1:8553/v1/firewall/enable-masquerade \
  -H 'Content-Type: application/json' -d '"external"'
```

### 6. DNS/DHCP (dnsmasq on br0)

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/dns/write-config \
  -H 'Content-Type: application/json' -d '{
  "interface": "br0",
  "listen_addresses": ["172.16.0.1"],
  "mode": "custom",
  "upstream_servers": ["1.1.1.1"],
  "dns_forward_max": 1000,
  "advertise_dns_v4": ["172.16.0.1"],
  "advertise_dns_v6": [],
  "captive_portal_url": null,
  "dhcp_range_start": "172.16.0.100",
  "dhcp_range_end": "172.16.0.200",
  "dhcp_lease_time": 12,
  "gateway": "172.16.0.1",
  "enable_ra": true,
  "ipv6_mode": "server",
  "ipv6_prefix": null,
  "ipv6_relay_wan_interface": null,
  "reservations": [],
  "dns_entries": [],
  "log_dhcp": false
}'
```

### 7. xray VLESS Reality client + tun2socks

Write xray client config to `/etc/xray/config.json` with your server's
address, UUID, and Reality keys:

```json
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "tag": "socks", "port": 1080, "protocol": "socks",
    "settings": {"auth": "noauth", "udp": true}
  }],
  "outbounds": [{
    "protocol": "vless", "tag": "proxy",
    "settings": {"vnext": [{
      "address": "<SERVER-IP>", "port": 13600,
      "users": [{"id": "<YOUR-UUID>", "flow": "xtls-rprx-vision", "encryption": "none"}]
    }]},
    "streamSettings": {
      "network": "tcp", "security": "reality",
      "realitySettings": {
        "serverName": "localhost",
        "publicKey": "<SERVER-PUBLIC-KEY>",
        "shortId": "<YOUR-SHORT-ID>",
        "fingerprint": "chrome"
      }
    }
  }],
  "routing": {"rules": []}
}
```

Then start xray + tun2socks:
```bash
systemctl restart xray-core.service tun2socks.service
```

### 8. Enable services at boot

```bash
curl -sS -X POST http://127.0.0.1:8553/v1/dns/enable-on-boot \
  -H 'Content-Type: application/json' -d '{}'
curl -sS -X POST http://127.0.0.1:8553/v1/firewall/enable-on-boot \
  -H 'Content-Type: application/json' -d '{}'
```

---

## Verification

After provisioning, check:

```bash
# System state
systemctl is-system-running         # should be "running" or "degraded"
curl -s http://127.0.0.1:8553/v1/status | jq .ok.state  # "healthy"

# Network
nmcli connection show                # wan-main, br0, MGMT
ip -br addr show                     # verify IPs on br0 and WAN

# Services
systemctl status dnsmasq firewalld xray-core
ss -tlnp | grep -E '53|13600|1080|8553'
```

## References

- Harness provision scripts:
  `RouterPlane/harness/qemu/mkosi/*/mkosi.extra.route-config-applied/usr/local/sbin/route-config-provision`
- Board configs (old pre-config now disabled):
  `config/boards/nanopi-r6s.conf`, `config/boards/photonicat2.csc`
- Live device state snapshots:
  `local/csc/conf/rootfs/nanopi-r6s/`, `local/csc/conf/rootfs/photonicat2/`
