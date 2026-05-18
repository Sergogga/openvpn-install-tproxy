# openvpn-install-tproxy

This is a focused fork of `nyr/openvpn-install` for VPS hosts where OpenVPN
clients must be routed through local Xray/3x-ui policy routing instead of
leaving the server through direct NAT.

The installer keeps the upstream OpenVPN workflow: run the script, answer the
prompts, receive a client `.ovpn` profile, and rerun the script later to add or
remove clients. The network behavior is different:

```text
OpenVPN client
  -> OpenVPN server on the VPS
  -> iptables TPROXY on the host
  -> local Xray/3x-ui inbound on port 12345
  -> Xray routing/outbounds
```

## Fixed Contract

- OpenVPN client subnet: `10.12.14.0/24`
- OpenVPN server address: `10.12.14.1`
- Xray TPROXY inbound port: `12345`
- Expected Xray inbound tag: `openvpn-tproxy`
- Generated service: `openvpn-xray-tproxy.service`
- Generated helper: `/usr/local/sbin/openvpn-xray-tproxy.sh`

The script does not install Xray, does not modify 3x-ui, and does not create
direct `POSTROUTING` SNAT/MASQUERADE for OpenVPN clients. If the Xray TPROXY
path is unavailable, client traffic is intended to fail closed instead of
bypassing Xray through normal forwarding. OpenVPN client routing in this fork is
IPv4-only.

## Installation

Run as root on a supported Ubuntu, Debian, AlmaLinux, Rocky Linux, CentOS, or
Fedora server:

```bash
bash openvpn-install.sh
```

Before connecting clients, create the Xray/3x-ui transparent inbound separately.
The required inbound is a `dokodemo-door` listener on port `12345` with
`followRedirect` enabled and `sockopt.tproxy` set to `tproxy`.

## Operations

Useful checks after installation:

```bash
systemctl status openvpn-xray-tproxy.service
ip rule show | grep fwmark
ip route show table 100
iptables -t mangle -vnL XRAY_OVPN
iptables -t nat -S POSTROUTING | grep 10.12.14.0/24 || echo "OK: no direct SNAT"
```

Development documentation, tests, and agent planning files live on the `dev`
branch. The `master` branch intentionally keeps only this README, the license,
and the installer script.
