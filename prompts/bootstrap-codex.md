# Bootstrap Prompt for Codex

Read `AGENTS.md` and implement the active execution plan:

```text
docs/exec-plans/active/openvpn-xray-tproxy-install-fork.md
```

Work phase by phase. After each phase, run:

```bash
bash -n openvpn-install.sh
./run-tests.sh
```

Update the execution plan progress log before reporting back.

Do not run the real installer. Do not modify 3x-ui. Do not add direct SNAT/MASQUERADE for OpenVPN clients.
