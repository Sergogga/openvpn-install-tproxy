# Execution Plan: OpenVPN Installer Fork for Xray TPROXY

Status: active  
Owner: Codex  
Last updated: 2026-05-18

## Objective

Modify the fork of `nyr/openvpn-install` so OpenVPN clients use subnet `10.12.14.0/24` and their traffic is redirected into local Xray/3x-ui routing via TPROXY instead of direct SNAT.

## Invariants

- OpenVPN client subnet is `10.12.14.0/24`.
- OpenVPN server config uses `server 10.12.14.0 255.255.255.0`.
- No direct `POSTROUTING` SNAT/MASQUERADE for the OpenVPN client subnet.
- No direct unconditional `FORWARD -s 10.12.14.0/24 -j ACCEPT`.
- Xray/3x-ui is not installed or modified by this script.
- TPROXY service setup is idempotent.
- Uninstall cleanup is explicit and best-effort.
- Fork-specific changes are marked with `Fork-specific`.

## Phase 0 — Repository reconnaissance

Identify all references to `10.8.0.0`, `10.8.0.0/24`, `POSTROUTING`, `SNAT`, `MASQUERADE`, `FORWARD`, `firewall-cmd`, and uninstall cleanup.

Acceptance: list each code region that needs modification.

## Phase 1 — Add centralized fork constants

Add constants:

```bash
OVPN_IPV4_NETWORK="10.12.14.0"
OVPN_IPV4_NETMASK="255.255.255.0"
OVPN_IPV4_CIDR="10.12.14.0/24"
OVPN_IPV4_SERVER="10.12.14.1"
XRAY_TPROXY_PORT="12345"
XRAY_TPROXY_MARK="0x1/0x1"
XRAY_FWMARK="1"
XRAY_ROUTE_TABLE="100"
XRAY_TPROXY_CHAIN="XRAY_OVPN"
XRAY_TPROXY_SERVICE="openvpn-xray-tproxy.service"
XRAY_TPROXY_SCRIPT="/usr/local/sbin/openvpn-xray-tproxy.sh"
```

Acceptance: constants exist once and syntax check passes.

## Phase 2 — Change OpenVPN server subnet

Generate:

```conf
server 10.12.14.0 255.255.255.0
```

not `server 10.8.0.0 255.255.255.0`.

## Phase 3 — Remove direct client SNAT

Remove installer logic that creates direct `POSTROUTING ... -j SNAT` or `MASQUERADE` for OpenVPN clients. Handle iptables and firewalld branches.

## Phase 4 — Remove direct forwarding accept

Avoid generating unconditional `FORWARD -s 10.12.14.0/24 -j ACCEPT`.

## Phase 5 — Generate TPROXY helper script

Write `/usr/local/sbin/openvpn-xray-tproxy.sh` that:

- uses `set -euo pipefail`;
- ensures `ip rule add fwmark 1 table 100`;
- ensures `ip route add local 0.0.0.0/0 dev lo table 100`;
- creates/flushes `XRAY_OVPN`;
- adds exclusions for local/private/reserved networks;
- adds TCP/UDP TPROXY to port `12345`;
- ensures one `PREROUTING -s 10.12.14.0/24 -j XRAY_OVPN`;
- inserts no-leak `FORWARD -s 10.12.14.0/24 -j REJECT`.

## Phase 6 — Generate systemd service

Write `/etc/systemd/system/openvpn-xray-tproxy.service` with:

```ini
[Unit]
Description=Route OpenVPN client traffic to Xray TPROXY inbound
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/openvpn-xray-tproxy.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Enable it with `systemctl daemon-reload` and `systemctl enable --now openvpn-xray-tproxy.service`.

## Phase 7 — Add uninstall cleanup

Cleanup service, helper script, mangle rules, no-leak rule, and best-effort policy routing entries.

## Phase 8 — Generate Xray reference notes

Generate local reference file containing the required Xray inbound and routing examples. Do not modify 3x-ui.

## Phase 9 — Add final validation output

Print commands for service status, policy routing, mangle counters, OpenVPN subnet, and direct NAT absence.

## Phase 10 — Documentation update

Update README/docs and this execution plan.

## Required test loop

```bash
bash -n openvpn-install.sh
./run-tests.sh
```

## Progress log

- [x] Phase 0 complete. Regions identified: OpenVPN server subnet generation, firewalld rules, iptables service generation, uninstall firewall cleanup, and IPv6 client routing bypass risk.
- [x] Phase 1 complete. Fork-specific constants are centralized in `openvpn-install.sh`.
- [x] Phase 2 complete. Server config now generates `server 10.12.14.0 255.255.255.0`.
- [x] Phase 3 complete. Direct OpenVPN client SNAT/MASQUERADE generation was removed.
- [x] Phase 4 complete. Direct unconditional OpenVPN client `FORWARD ACCEPT` generation was removed.
- [x] Phase 5 complete. Installer generates idempotent `/usr/local/sbin/openvpn-xray-tproxy.sh`.
- [x] Phase 6 complete. Installer generates and enables `openvpn-xray-tproxy.service`.
- [x] Phase 7 complete. Uninstall performs best-effort TPROXY service, rule, route, and helper cleanup.
- [x] Phase 8 complete. Installer writes a local Xray inbound reference JSON for manual 3x-ui setup.
- [x] Phase 9 complete. Installer prints validation commands after install.
- [x] Phase 10 complete. README was rewritten to describe the fork purpose and operational contract.

## Decision log

- 2026-05-18: Use host-level OpenVPN, not Docker runtime.
- 2026-05-18: Use TPROXY + transparent Xray inbound, not VLESS inbound.
- 2026-05-18: Disable direct SNAT by design so client traffic fails closed if Xray/TPROXY is unavailable.
- 2026-05-18: Keep development artifacts on `dev`; keep `master` minimal with README, license, and installer script.
