# OpenVPN to Xray TPROXY Design

## Problem

The upstream installer configures OpenVPN clients as conventional road-warrior VPN clients. Their traffic is SNATed to the VPS public IP and exits directly.

This fork must send client traffic into Xray so 3x-ui routing rules apply.

## Decision

Use host-level iptables TPROXY and policy routing.

## Why not VLESS/VMess inbound?

OpenVPN emits ordinary IP packets after decryption. VLESS/VMess/Trojan inbounds expect their own application protocol and are not suitable for plain routed packets.

## Why TPROXY?

- OpenVPN already creates the client `tun` interface.
- The host sees traffic from `10.12.14.0/24`.
- iptables can match the subnet directly.
- Xray transparent inbound can receive redirected TCP/UDP.

## Required generated components

1. OpenVPN config with `server 10.12.14.0 255.255.255.0`.
2. `/usr/local/sbin/openvpn-xray-tproxy.sh`.
3. `/etc/systemd/system/openvpn-xray-tproxy.service`.
4. Local Xray/3x-ui reference notes.

## Firewall policy

Keep input allow rule for the OpenVPN server port.

Avoid:

- direct `POSTROUTING` SNAT for OpenVPN clients;
- direct `FORWARD -s 10.12.14.0/24 -j ACCEPT`.

Add:

- `mangle/PREROUTING` jump for `10.12.14.0/24`;
- TPROXY rules in `XRAY_OVPN`;
- no-leak `FORWARD -s 10.12.14.0/24 -j REJECT`.
