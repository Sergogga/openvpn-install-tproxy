# Documentation Gardening Prompt

Scan the repository for documentation drift.

Check `AGENTS.md`, `ARCHITECTURE.md`, the active execution plan, README, and Xray examples. Ensure all mention port `12345`, tag `openvpn-tproxy`, and no direct SNAT for OpenVPN clients.

Run:

```bash
./run-tests.sh
```
