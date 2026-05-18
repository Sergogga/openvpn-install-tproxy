#!/usr/bin/env bash
set -euo pipefail

test -f AGENTS.md
forbidden_instruction_file="agent.md"
test ! -f "$forbidden_instruction_file"
test -f ARCHITECTURE.md
test -f docs/PROJECT_BRIEF.md
test -f docs/design-docs/openvpn-xray-tproxy.md
test -f docs/exec-plans/active/openvpn-xray-tproxy-install-fork.md
test -f docs/references/xray-tproxy-example.json

grep -q '10.12.14.0/24' AGENTS.md
grep -q 'openvpn-tproxy' docs/references/xray-tproxy-example.json
grep -q '12345' docs/references/xray-tproxy-example.json
grep -q 'followRedirect' docs/references/xray-tproxy-example.json
grep -q 'tproxy' docs/references/xray-tproxy-example.json
