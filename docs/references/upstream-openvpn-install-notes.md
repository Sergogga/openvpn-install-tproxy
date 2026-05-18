# Upstream `nyr/openvpn-install` Notes

Date captured: 2026-05-18

Upstream generates OpenVPN server config with:

```conf
topology subnet
server 10.8.0.0 255.255.255.0
```

Upstream also creates direct NAT/forwarding behavior for OpenVPN clients, including rules equivalent to:

```bash
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to <server-ip>
iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT
```

This fork intentionally removes that behavior and routes `10.12.14.0/24` through Xray TPROXY instead.
