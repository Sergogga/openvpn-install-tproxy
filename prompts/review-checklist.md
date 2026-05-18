# Review Checklist Prompt

Review the current branch against the OpenVPN → Xray TPROXY contract.

Focus on:

- direct SNAT/MASQUERADE absence;
- `10.12.14.0/24` consistency;
- no legacy `10.8.0.0/24` active behavior;
- no direct forwarding accept for OpenVPN clients;
- TPROXY helper idempotency;
- systemd service generation;
- uninstall cleanup;
- docs/tests alignment.

Run:

```bash
bash -n openvpn-install.sh
./run-tests.sh
```
