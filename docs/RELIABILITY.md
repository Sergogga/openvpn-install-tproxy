# RELIABILITY.md

## Reliability goals

The installer must produce repeatable network behavior across reboot and service restart.

## Idempotency requirements

The generated TPROXY helper must be safe to run repeatedly:

- create `XRAY_OVPN` if missing;
- flush `XRAY_OVPN` before re-adding rules;
- add unique jump rules using `iptables -C ... || iptables -A ...`;
- remove duplicate no-leak rules before inserting the canonical one.

## Operational checks

```bash
systemctl status openvpn-xray-tproxy.service
ip rule show | grep fwmark
ip route show table 100
iptables -t mangle -vnL XRAY_OVPN
iptables -t nat -S POSTROUTING | grep 10.12.14.0/24 || echo "OK: no direct SNAT"
```
