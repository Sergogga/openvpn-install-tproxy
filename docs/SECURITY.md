# SECURITY.md

## Security goals

- Avoid accidental bypass of Xray routing.
- Preserve administrative access to the VPS.
- Keep the OpenVPN server port reachable.
- Avoid broad firewall captures that affect unrelated VPS traffic.

## The installer must not

- install or modify 3x-ui;
- edit Xray config automatically;
- disable SSH;
- disable the OpenVPN listening port;
- add direct SNAT/MASQUERADE for OpenVPN clients;
- add broad `PREROUTING` rules that capture all host traffic.

## Fail-closed behavior

If Xray/TPROXY is unavailable, OpenVPN clients should not bypass Xray through direct forwarding.

No-leak rule:

```bash
iptables -I FORWARD 1 -s 10.12.14.0/24 -j REJECT
```
