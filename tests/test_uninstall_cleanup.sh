#!/usr/bin/env bash
set -euo pipefail

grep -Fq 'systemctl disable --now "$XRAY_TPROXY_SERVICE"' openvpn-install.sh
grep -Fq 'rm -f "/etc/systemd/system/$XRAY_TPROXY_SERVICE"' openvpn-install.sh
grep -Fq 'rm -f "$XRAY_TPROXY_SCRIPT" "$XRAY_TPROXY_REFERENCE"' openvpn-install.sh
grep -Fq 'XRAY_TPROXY_CHAIN="XRAY_OVPN"' openvpn-install.sh
grep -Eq 'iptables_path.*mangle.*XRAY_TPROXY_CHAIN|XRAY_TPROXY_CHAIN.*iptables_path.*mangle' openvpn-install.sh
grep -Eq 'rule del fwmark|rule delete fwmark' openvpn-install.sh
grep -Eq 'route del local 0.0.0.0/0 dev lo table|route delete local 0.0.0.0/0 dev lo table' openvpn-install.sh
