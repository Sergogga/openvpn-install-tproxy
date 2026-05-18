# Project Brief

## Project

Fork `nyr/openvpn-install` for a VPS where OpenVPN clients should enter Xray/3x-ui routing instead of exiting directly through VPS NAT.

## Scope

In scope:

- modify `openvpn-install.sh`;
- change VPN client subnet to `10.12.14.0/24`;
- remove direct OpenVPN client SNAT;
- generate host TPROXY integration;
- generate tests and docs;
- make the behavior repeatable and auditable.

Out of scope:

- installing 3x-ui;
- editing 3x-ui database/config automatically;
- deploying Docker OpenVPN runtime;
- guaranteeing perfect domain visibility for all encrypted protocols.

## Success criteria

A fresh install creates OpenVPN with `server 10.12.14.0 255.255.255.0`, creates TPROXY integration, does not NAT clients directly, and documents the required Xray inbound.
