# Validation Commands

```bash
systemctl status openvpn-server@server.service
systemctl status openvpn-iptables.service
systemctl status openvpn-xray-tproxy.service
ip rule show | grep fwmark
ip route show table 100
iptables -t mangle -S PREROUTING | grep XRAY_OVPN
iptables -t mangle -vnL XRAY_OVPN
iptables -t nat -S POSTROUTING | grep 10.12.14.0/24 || echo "OK: no direct SNAT"
grep -E '^server ' /etc/openvpn/server/server.conf
```
