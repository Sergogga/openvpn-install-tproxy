# plan.md

You are Codex working inside a fork of `nyr/openvpn-install`.

Modify this fork so that OpenVPN is installed on a VPS host, but OpenVPN client traffic is not sent directly to the Internet through SNAT/MASQUERADE. Traffic from the OpenVPN client subnet must be transparently redirected to a local Xray/3x-ui TPROXY inbound.

Before editing code, read:

1. `AGENTS.md`
2. `ARCHITECTURE.md`
3. `docs/PROJECT_BRIEF.md`
4. `docs/design-docs/openvpn-xray-tproxy.md`
5. `docs/exec-plans/active/openvpn-xray-tproxy-install-fork.md`
6. `docs/SECURITY.md`
7. `docs/RELIABILITY.md`
8. `docs/QUALITY_SCORE.md`

## Target network contract

- OpenVPN client subnet: `10.12.14.0/24`
- OpenVPN server address: `10.12.14.1`
- Xray TPROXY inbound port: `12345`
- TPROXY mark: `0x1/0x1`
- policy routing fwmark: `1`
- policy routing table: `100`
- mangle chain: `XRAY_OVPN`
- Xray inbound tag used in docs/examples: `openvpn-tproxy`
- generated service: `openvpn-xray-tproxy.service`
- generated helper script: `/usr/local/sbin/openvpn-xray-tproxy.sh`

## Implementation objectives

Implement the active execution plan in:

```text
docs/exec-plans/active/openvpn-xray-tproxy-install-fork.md
```

The modified installer must:

1. use `10.12.14.0/24` instead of `10.8.0.0/24`;
2. generate `server 10.12.14.0 255.255.255.0` in OpenVPN server config;
3. remove direct OpenVPN client SNAT/MASQUERADE behavior;
4. avoid direct `FORWARD -s 10.12.14.0/24 -j ACCEPT`;
5. generate an idempotent TPROXY helper script;
6. generate and enable a systemd oneshot service for TPROXY setup;
7. add no-leak protection so OpenVPN clients cannot bypass Xray through normal forwarding;
8. add uninstall cleanup for fork-specific service/script/rules;
9. generate local notes/examples for required 3x-ui/Xray inbound;
10. print validation commands after install.

## Development loop

Work in small steps. After each step:

```bash
bash -n openvpn-install.sh
./run-tests.sh
```

Update the progress log in:

```text
docs/exec-plans/active/openvpn-xray-tproxy-install-fork.md
```

## Do not do

- Do not install or modify 3x-ui.
- Do not run the real installer on this machine unless explicitly asked.
- Do not add Docker runtime requirements.
- Do not open broad firewall forwarding from the OpenVPN subnet to the Internet.
- Do not leave legacy `10.8.0.0/24` behavior in active installer logic.

## Final validation

Before finishing, run and report:

```bash
bash -n openvpn-install.sh
./run-tests.sh
grep -n "10\.8\.0\.0" openvpn-install.sh || true
grep -En 'POSTROUTING.*(10\.12\.14\.0/24|\$OVPN_IPV4_CIDR).*(SNAT|MASQUERADE)' openvpn-install.sh || true
grep -En 'FORWARD.*(10\.12\.14\.0/24|\$OVPN_IPV4_CIDR).*ACCEPT' openvpn-install.sh || true
```
