# ARCHITECTURE.md

## Purpose

This fork changes the network role of `nyr/openvpn-install`.

Upstream installs a conventional OpenVPN road-warrior server where VPN clients are NATed through the VPS public IP. This fork turns OpenVPN into an ingress layer for Xray/3x-ui routing.

## Target topology

```text
OpenVPN client
  |
  | encrypted OpenVPN tunnel
  v
OpenVPN server on VPS host
  |
  | plain IP traffic from 10.12.14.0/24
  v
host iptables mangle PREROUTING
  |
  | TPROXY to local Xray inbound :12345
  v
Xray / 3x-ui routing
  |
  | selected outbound
  v
Internet / WARP / proxy / block
```

## Responsibility split

### OpenVPN

OpenVPN authenticates clients, creates the `tun` interface, assigns addresses from `10.12.14.0/24`, pushes default route/DNS options, and generates `.ovpn` profiles.

OpenVPN must not NAT clients directly to the Internet.

### Host firewall/routing

The VPS host keeps the OpenVPN listening port reachable, marks and locally delivers client traffic to Xray through TPROXY, and prevents bypass through normal forwarding.

### Xray/3x-ui

Xray accepts transparent traffic on local port `12345`, applies routing rules, and sends traffic to `direct`, `warp`, proxy, or block outbounds.

The installer must not modify 3x-ui directly.

## Critical invariant

Traffic from `10.12.14.0/24` must not be SNATed directly to the Internet.

It must be captured at `mangle/PREROUTING` and delivered to Xray.

## Desired packet path

```text
source: 10.12.14.x
hook: mangle/PREROUTING
action: jump to XRAY_OVPN
action: TPROXY --on-port 12345 --tproxy-mark 0x1/0x1
policy routing: fwmark 1 -> table 100
route table 100: local 0.0.0.0/0 dev lo
listener: Xray TPROXY inbound
```

## Forbidden path

```text
source: 10.12.14.x
hook: nat/POSTROUTING
action: SNAT/MASQUERADE to VPS public IP
```
