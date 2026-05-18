# QUALITY_SCORE.md

## Quality bar

The implementation must be correct, testable without a real VPN server, legible to future agents, safe by default, and easy to revert.

| Area | Requirement | Test |
|---|---|---|
| Shell syntax | Script parses | `bash -n openvpn-install.sh` |
| Subnet | Uses `10.12.14.0/24` | `tests/test_static_network_constants.sh` |
| Legacy subnet | No active `10.8.0.0` behavior | `tests/test_static_network_constants.sh` |
| NAT | No direct client SNAT/MASQUERADE | `tests/test_no_direct_snat.sh` |
| TPROXY | Generates service/script/rules | `tests/test_tproxy_generation.sh` |
| Uninstall | Cleanup exists | `tests/test_uninstall_cleanup.sh` |
| Docs | Required docs/examples exist | `tests/test_docs_contract.sh` |
