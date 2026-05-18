#!/usr/bin/env bash
set -euo pipefail

bash -n openvpn-install.sh

for test_file in tests/test_*.sh; do
  echo "Running ${test_file}"
  bash "${test_file}"
done

echo "All tests passed"
