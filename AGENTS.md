# AGENTS.md

This is the short, stable map for Codex working in this repository.

The repository is a fork of `nyr/openvpn-install`. The goal is to install OpenVPN on a VPS host so that OpenVPN client traffic is transparently redirected into a local Xray/3x-ui TPROXY inbound instead of exiting directly through VPS SNAT.

Humans steer. Agents execute. Repository-local docs, plans, tests, and scripts are the system of record.

## Non-negotiable constraints

- OpenVPN client subnet: `10.12.14.0/24`.
- OpenVPN server address: `10.12.14.1`.
- Xray/3x-ui is installed separately and must not be modified by this installer.
- No direct `POSTROUTING` SNAT/MASQUERADE for OpenVPN clients.
- No unconditional `FORWARD -s 10.12.14.0/24 -j ACCEPT`.
- Client traffic must go through host TPROXY into Xray port `12345`.
- Expected Xray inbound tag: `openvpn-tproxy`.
- Generated systemd service: `openvpn-xray-tproxy.service`.
- Generated helper script: `/usr/local/sbin/openvpn-xray-tproxy.sh`.

## Read before editing

1. `docs/PROJECT_BRIEF.md`
2. `ARCHITECTURE.md`
3. `docs/design-docs/openvpn-xray-tproxy.md`
4. `docs/exec-plans/active/openvpn-xray-tproxy-install-fork.md`
5. `docs/SECURITY.md`
6. `docs/RELIABILITY.md`
7. `docs/QUALITY_SCORE.md`
8. `docs/references/upstream-openvpn-install-notes.md`
9. `docs/references/xray-tproxy-example.json`

Keep this file short. Put deep detail in `docs/`. Do not add duplicate agent instruction files; `AGENTS.md` is the canonical entry point.

## Working rules

- Inspect current code before editing.
- Make small, atomic changes.
- Mark fork-specific code with `Fork-specific` comments.
- Centralize magic values in constants.
- Prefer idempotent scripts over one-shot command fragments.
- Do not add Docker runtime requirements.
- Do not run the real installer on the current host unless explicitly asked.
- Do not disable SSH, 3x-ui, or the OpenVPN listening port.
- Do not capture all VPS traffic; only match the OpenVPN client subnet.

## Required checks

Before reporting completion, run:

```bash
bash -n openvpn-install.sh
./run-tests.sh
```

## Definition of done

- all tests pass;
- active execution plan progress log is updated;
- direct OpenVPN client SNAT is absent;
- TPROXY service generation is idempotent;
- uninstall cleanup exists;
- docs explain that Xray/3x-ui inbound must be created separately.
