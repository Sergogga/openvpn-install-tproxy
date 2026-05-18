#!/usr/bin/env bash
set -euo pipefail

grep -q 'openvpn-xray-tproxy.service' openvpn-install.sh
grep -q 'openvpn-xray-tproxy.sh' openvpn-install.sh
grep -q 'rule add fwmark' openvpn-install.sh
grep -q 'route add local 0.0.0.0/0 dev lo table' openvpn-install.sh
grep -q 'XRAY_OVPN' openvpn-install.sh
grep -q 'TPROXY --on-port' openvpn-install.sh
grep -q -- '--tproxy-mark' openvpn-install.sh
grep -q 'PREROUTING' openvpn-install.sh
grep -q '10.12.14.0/24' openvpn-install.sh
grep -Eq 'FORWARD.*REJECT|FORWARD.*-j REJECT' openvpn-install.sh
