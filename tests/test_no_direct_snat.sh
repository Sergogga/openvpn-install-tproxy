#!/usr/bin/env bash
set -euo pipefail

if grep -E 'POSTROUTING.*-s 10\.12\.14\.0/24.*-j (SNAT|MASQUERADE)' openvpn-install.sh; then
  echo "Direct SNAT/MASQUERADE for 10.12.14.0/24 must not be generated"
  exit 1
fi

if grep -E 'POSTROUTING.*-s \$OVPN_IPV4_CIDR.*-j (SNAT|MASQUERADE)' openvpn-install.sh; then
  echo "Direct SNAT/MASQUERADE for OVPN_IPV4_CIDR must not be generated"
  exit 1
fi

if grep -E 'POSTROUTING.*-s fddd:1194:1194:1194::/64.*-j (SNAT|MASQUERADE)' openvpn-install.sh; then
  echo "Direct IPv6 SNAT/MASQUERADE for OpenVPN clients must not be generated"
  exit 1
fi

if grep -E 'FORWARD.*-s (10\.12\.14\.0/24|\$OVPN_IPV4_CIDR).*ACCEPT' openvpn-install.sh; then
  echo "Direct FORWARD ACCEPT for OpenVPN clients must not exist"
  exit 1
fi

if grep -E 'FORWARD.*-s fddd:1194:1194:1194::/64.*ACCEPT' openvpn-install.sh; then
  echo "Direct IPv6 FORWARD ACCEPT for OpenVPN clients must not exist"
  exit 1
fi
