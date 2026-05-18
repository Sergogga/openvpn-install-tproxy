#!/usr/bin/env bash
set -euo pipefail

grep -q 'OVPN_IPV4_NETWORK="10.12.14.0"' openvpn-install.sh
grep -q 'OVPN_IPV4_NETMASK="255.255.255.0"' openvpn-install.sh
grep -q 'OVPN_IPV4_CIDR="10.12.14.0/24"' openvpn-install.sh
grep -q 'XRAY_TPROXY_PORT="12345"' openvpn-install.sh

if grep -q '10\.8\.0\.0' openvpn-install.sh; then
  echo "Unexpected legacy 10.8.0.0 reference found in active installer logic"
  exit 1
fi

bash -n openvpn-install.sh
