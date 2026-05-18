#!/bin/bash
#
# https://github.com/Nyr/openvpn-install
#
# Copyright (c) 2013 Nyr. Released under the MIT License.


# Detect Debian users running the script with "sh" instead of bash
if readlink /proc/$$/exe | grep -q "dash"; then
	echo 'This installer needs to be run with "bash", not "sh".'
	exit
fi

# Discard stdin. Needed when running from a one-liner which includes a newline
read -N 999999 -t 0.001

# Detect OS
# $os_version variables aren't always in use, but are kept here for convenience
if grep -qs "ubuntu" /etc/os-release; then
	os="ubuntu"
	os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
	group_name="nogroup"
elif [[ -e /etc/debian_version ]]; then
	os="debian"
	os_version=$(grep -oE '[0-9]+' /etc/debian_version | head -1)
	group_name="nogroup"
elif [[ -e /etc/almalinux-release || -e /etc/rocky-release || -e /etc/centos-release ]]; then
	os="centos"
	os_version=$(grep -shoE '[0-9]+' /etc/almalinux-release /etc/rocky-release /etc/centos-release | head -1)
	group_name="nobody"
elif [[ -e /etc/fedora-release ]]; then
	os="fedora"
	os_version=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)
	group_name="nobody"
else
	echo "This installer seems to be running on an unsupported distribution.
Supported distros are Ubuntu, Debian, AlmaLinux, Rocky Linux, CentOS and Fedora."
	exit
fi

if [[ "$os" == "ubuntu" && "$os_version" -lt 2204 ]]; then
	echo "Ubuntu 22.04 or higher is required to use this installer.
This version of Ubuntu is too old and unsupported."
	exit
fi

if [[ "$os" == "debian" ]]; then
	if grep -q '/sid' /etc/debian_version; then
		echo "Debian Testing and Debian Unstable are unsupported by this installer."
		exit
	fi
	if [[ "$os_version" -lt 11 ]]; then
		echo "Debian 11 or higher is required to use this installer.
This version of Debian is too old and unsupported."
		exit
	fi
fi

if [[ "$os" == "centos" && "$os_version" -lt 9 ]]; then
	os_name=$(sed 's/ release.*//' /etc/almalinux-release /etc/rocky-release /etc/centos-release 2>/dev/null | head -1)
	echo "$os_name 9 or higher is required to use this installer.
This version of $os_name is too old and unsupported."
	exit
fi

# Detect environments where $PATH does not include the sbin directories
if ! grep -q sbin <<< "$PATH"; then
	echo '$PATH does not include sbin. Try using "su -" instead of "su".'
	exit
fi

if [[ "$EUID" -ne 0 ]]; then
	echo "This installer needs to be run with superuser privileges."
	exit
fi

if [[ ! -e /dev/net/tun ]] || ! ( exec 7<>/dev/net/tun ) 2>/dev/null; then
	echo "The system does not have the TUN device available.
TUN needs to be enabled before running this installer."
	exit
fi

# Store the absolute path of the directory where the script is located
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Fork-specific: OpenVPN clients must enter local Xray/3x-ui TPROXY routing,
# not exit through direct VPS NAT.
OVPN_IPV4_NETWORK="10.12.14.0"
OVPN_IPV4_NETMASK="255.255.255.0"
OVPN_IPV4_CIDR="10.12.14.0/24"
OVPN_IPV4_SERVER="10.12.14.1"
XRAY_TPROXY_PORT="12345"
XRAY_TPROXY_MARK="0x1/0x1"
XRAY_FWMARK="1"
XRAY_ROUTE_TABLE="100"
XRAY_TPROXY_CHAIN="XRAY_OVPN"
XRAY_TPROXY_SERVICE="openvpn-xray-tproxy.service"
XRAY_TPROXY_SCRIPT="/usr/local/sbin/openvpn-xray-tproxy.sh"
XRAY_TPROXY_TAG="openvpn-tproxy"
XRAY_TPROXY_REFERENCE="/etc/openvpn/server/xray-tproxy-example.json"

write_xray_tproxy_files() {
	# Fork-specific: this helper is idempotent and captures only OpenVPN clients.
	mkdir -p /usr/local/sbin /etc/systemd/system
	cat > "$XRAY_TPROXY_SCRIPT" <<XRAY_TPROXY_SCRIPT
#!/bin/bash
set -euo pipefail

OVPN_IPV4_CIDR="$OVPN_IPV4_CIDR"
XRAY_TPROXY_PORT="$XRAY_TPROXY_PORT"
XRAY_TPROXY_MARK="$XRAY_TPROXY_MARK"
XRAY_FWMARK="$XRAY_FWMARK"
XRAY_ROUTE_TABLE="$XRAY_ROUTE_TABLE"
XRAY_TPROXY_CHAIN="$XRAY_TPROXY_CHAIN"

iptables_path="\${IPTABLES_PATH:-\$(command -v iptables)}"
ip_path="\${IP_PATH:-\$(command -v ip)}"

if ! "\$ip_path" rule show | grep -Eq "fwmark (0x)?\${XRAY_FWMARK}(/0x[0-9a-f]+)? .*lookup \${XRAY_ROUTE_TABLE}"; then
	"\$ip_path" rule add fwmark "\${XRAY_FWMARK}" table "\${XRAY_ROUTE_TABLE}"
fi

if ! "\$ip_path" route show table "\${XRAY_ROUTE_TABLE}" | grep -Eq '^local (default|0\.0\.0\.0/0) dev lo'; then
	"\$ip_path" route add local 0.0.0.0/0 dev lo table "\${XRAY_ROUTE_TABLE}"
fi

"\$iptables_path" -w 5 -t mangle -N "\${XRAY_TPROXY_CHAIN}" 2>/dev/null || true
"\$iptables_path" -w 5 -t mangle -F "\${XRAY_TPROXY_CHAIN}"

"\$iptables_path" -w 5 -t mangle -A "\${XRAY_TPROXY_CHAIN}" -m mark --mark "\${XRAY_FWMARK}" -j RETURN
for reserved_cidr in \\
	0.0.0.0/8 \\
	10.0.0.0/8 \\
	100.64.0.0/10 \\
	127.0.0.0/8 \\
	169.254.0.0/16 \\
	172.16.0.0/12 \\
	192.0.0.0/24 \\
	192.0.2.0/24 \\
	192.168.0.0/16 \\
	198.18.0.0/15 \\
	198.51.100.0/24 \\
	203.0.113.0/24 \\
	224.0.0.0/4 \\
	240.0.0.0/4; do
	"\$iptables_path" -w 5 -t mangle -A "\${XRAY_TPROXY_CHAIN}" -d "\$reserved_cidr" -j RETURN
done

"\$iptables_path" -w 5 -t mangle -A "\${XRAY_TPROXY_CHAIN}" -p tcp -j TPROXY --on-port "\${XRAY_TPROXY_PORT}" --tproxy-mark "\${XRAY_TPROXY_MARK}"
"\$iptables_path" -w 5 -t mangle -A "\${XRAY_TPROXY_CHAIN}" -p udp -j TPROXY --on-port "\${XRAY_TPROXY_PORT}" --tproxy-mark "\${XRAY_TPROXY_MARK}"

if ! "\$iptables_path" -w 5 -t mangle -C PREROUTING -s "\${OVPN_IPV4_CIDR}" -j "\${XRAY_TPROXY_CHAIN}" 2>/dev/null; then
	"\$iptables_path" -w 5 -t mangle -A PREROUTING -s "\${OVPN_IPV4_CIDR}" -j "\${XRAY_TPROXY_CHAIN}"
fi

while "\$iptables_path" -w 5 -C FORWARD -s "\${OVPN_IPV4_CIDR}" -j REJECT 2>/dev/null; do
	"\$iptables_path" -w 5 -D FORWARD -s "\${OVPN_IPV4_CIDR}" -j REJECT
done
"\$iptables_path" -w 5 -I FORWARD 1 -s "\${OVPN_IPV4_CIDR}" -j REJECT
XRAY_TPROXY_SCRIPT
	chmod 755 "$XRAY_TPROXY_SCRIPT"

	cat > "/etc/systemd/system/$XRAY_TPROXY_SERVICE" <<XRAY_TPROXY_SERVICE
[Unit]
Description=Route OpenVPN client traffic to Xray TPROXY inbound
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$XRAY_TPROXY_SCRIPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
XRAY_TPROXY_SERVICE

	cat > "$XRAY_TPROXY_REFERENCE" <<XRAY_TPROXY_REFERENCE
{
  "inbounds": [
    {
      "tag": "$XRAY_TPROXY_TAG",
      "listen": "0.0.0.0",
      "port": $XRAY_TPROXY_PORT,
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "streamSettings": {
        "sockopt": {
          "tproxy": "tproxy"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ],
        "routeOnly": true
      }
    }
  ]
}
XRAY_TPROXY_REFERENCE
}

cleanup_xray_tproxy() {
	# Fork-specific: best-effort cleanup of generated TPROXY integration.
	systemctl disable --now "$XRAY_TPROXY_SERVICE" 2>/dev/null || true
	rm -f "/etc/systemd/system/$XRAY_TPROXY_SERVICE"

	iptables_path=$(command -v iptables 2>/dev/null)
	if [[ -n "$iptables_path" ]]; then
		while "$iptables_path" -w 5 -t mangle -C PREROUTING -s "$OVPN_IPV4_CIDR" -j "$XRAY_TPROXY_CHAIN" 2>/dev/null; do
			"$iptables_path" -w 5 -t mangle -D PREROUTING -s "$OVPN_IPV4_CIDR" -j "$XRAY_TPROXY_CHAIN"
		done
		"$iptables_path" -w 5 -t mangle -F "$XRAY_TPROXY_CHAIN" 2>/dev/null || true
		"$iptables_path" -w 5 -t mangle -X "$XRAY_TPROXY_CHAIN" 2>/dev/null || true
		while "$iptables_path" -w 5 -C FORWARD -s "$OVPN_IPV4_CIDR" -j REJECT 2>/dev/null; do
			"$iptables_path" -w 5 -D FORWARD -s "$OVPN_IPV4_CIDR" -j REJECT
		done
	fi

	ip_path=$(command -v ip 2>/dev/null)
	if [[ -n "$ip_path" ]]; then
		"$ip_path" rule del fwmark "$XRAY_FWMARK" table "$XRAY_ROUTE_TABLE" 2>/dev/null || true
		"$ip_path" route del local 0.0.0.0/0 dev lo table "$XRAY_ROUTE_TABLE" 2>/dev/null || true
	fi

	rm -f "$XRAY_TPROXY_SCRIPT" "$XRAY_TPROXY_REFERENCE"
	systemctl daemon-reload 2>/dev/null || true
}

if [[ ! -e /etc/openvpn/server/server.conf ]]; then
	# Detect some Debian minimal setups where neither wget nor curl are installed
	if ! hash wget 2>/dev/null && ! hash curl 2>/dev/null; then
		echo "Wget is required to use this installer."
		read -n1 -r -p "Press any key to install Wget and continue..."
		apt-get update
		apt-get install -y wget
	fi
	clear
	echo 'Welcome to this OpenVPN road warrior installer!'
	# If system has a single IPv4, it is selected automatically. Else, ask the user
	if [[ $(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}') -eq 1 ]]; then
		ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')
	else
		number_of_ip=$(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}')
		echo
		echo "Which IPv4 address should be used?"
		ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | nl -s ') '
		read -p "IPv4 address [1]: " ip_number
		until [[ -z "$ip_number" || "$ip_number" =~ ^[0-9]+$ && "$ip_number" -le "$number_of_ip" ]]; do
			echo "$ip_number: invalid selection."
			read -p "IPv4 address [1]: " ip_number
		done
		[[ -z "$ip_number" ]] && ip_number="1"
		ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n "$ip_number"p)
	fi
	# If $ip is a private IP address, the server must be behind NAT
	if echo "$ip" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
		echo
		echo "This server is behind NAT. What is the public IPv4 address or hostname?"
		# Get public IP and sanitize with grep
		get_public_ip=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<< "$(wget -T 10 -t 1 -4qO- "http://ip1.dynupdate.no-ip.com/" || curl -m 10 -4Ls "http://ip1.dynupdate.no-ip.com/")")
		read -p "Public IPv4 address / hostname [$get_public_ip]: " public_ip
		# If the checkip service is unavailable and user didn't provide input, ask again
		until [[ -n "$get_public_ip" || -n "$public_ip" ]]; do
			echo "Invalid input."
			read -p "Public IPv4 address / hostname: " public_ip
		done
		[[ -z "$public_ip" ]] && public_ip="$get_public_ip"
	fi
	echo
	echo "Which protocol should OpenVPN use?"
	echo "   1) UDP (recommended)"
	echo "   2) TCP"
	read -p "Protocol [1]: " protocol
	until [[ -z "$protocol" || "$protocol" =~ ^[12]$ ]]; do
		echo "$protocol: invalid selection."
		read -p "Protocol [1]: " protocol
	done
	case "$protocol" in
		1|"") 
		protocol=udp
		;;
		2) 
		protocol=tcp
		;;
	esac
	echo
	echo "What port should OpenVPN listen on?"
	read -p "Port [1194]: " port
	until [[ -z "$port" || "$port" =~ ^[0-9]+$ && "$port" -le 65535 ]]; do
		echo "$port: invalid port."
		read -p "Port [1194]: " port
	done
	[[ -z "$port" ]] && port="1194"
	echo
	echo "Select a DNS server for the clients:"
	echo "   1) Default system resolvers"
	echo "   2) Google"
	echo "   3) 1.1.1.1"
	echo "   4) OpenDNS"
	echo "   5) Quad9"
	echo "   6) Gcore"
	echo "   7) AdGuard"
	echo "   8) Specify custom resolvers"
	read -p "DNS server [1]: " dns
	until [[ -z "$dns" || "$dns" =~ ^[1-8]$ ]]; do
		echo "$dns: invalid selection."
		read -p "DNS server [1]: " dns
	done
	# If the user selected custom resolvers, we deal with that here
	if [[ "$dns" = "8" ]]; then
		echo
		until [[ -n "$custom_dns" ]]; do
			echo "Enter DNS servers (one or more IPv4 addresses, separated by commas or spaces):"
			read -p "DNS servers: " dns_input
			# Convert comma delimited to space delimited
			dns_input=$(echo "$dns_input" | tr ',' ' ')
			# Validate and build custom DNS IP list
			for dns_ip in $dns_input; do
				if [[ "$dns_ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
					if [[ -z "$custom_dns" ]]; then
						custom_dns="$dns_ip"
					else
						custom_dns="$custom_dns $dns_ip"
					fi
				fi
			done
			if [ -z "$custom_dns" ]; then
				echo "Invalid input."
			fi
		done
	fi
	echo
	echo "Enter a name for the first client:"
	read -p "Name [client]: " unsanitized_client
	# Allow a limited set of characters to avoid conflicts
	client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
	[[ -z "$client" ]] && client="client"
	echo
	echo "OpenVPN installation is ready to begin."
	# Install a firewall if firewalld or iptables are not already available
	if ! systemctl is-active --quiet firewalld.service && ! hash iptables 2>/dev/null; then
		if [[ "$os" == "centos" || "$os" == "fedora" ]]; then
			firewall="firewalld"
			# We don't want to silently enable firewalld, so we give a subtle warning
			# If the user continues, firewalld will be installed and enabled during setup
			echo "firewalld, which is required to manage routing tables, will also be installed."
		elif [[ "$os" == "debian" || "$os" == "ubuntu" ]]; then
			# iptables is way less invasive than firewalld so no warning is given
			firewall="iptables"
		fi
	fi
	read -n1 -r -p "Press any key to continue..."
	# Fork-specific: TPROXY rules are installed with iptables even when firewalld
	# is used only to open the OpenVPN listener port.
	if ! hash iptables 2>/dev/null; then
		firewall="${firewall:+$firewall }iptables"
	fi
	# If running inside a container, disable LimitNPROC to prevent conflicts
	if systemd-detect-virt -cq; then
		mkdir /etc/systemd/system/openvpn-server@server.service.d/ 2>/dev/null
		echo "[Service]
LimitNPROC=infinity" > /etc/systemd/system/openvpn-server@server.service.d/disable-limitnproc.conf
	fi
	if [[ "$os" = "debian" || "$os" = "ubuntu" ]]; then
		apt-get update
		apt-get install -y --no-install-recommends openvpn openssl ca-certificates $firewall
	elif [[ "$os" = "centos" ]]; then
		dnf install -y epel-release
		dnf install -y openvpn openssl ca-certificates tar $firewall
	else
		# Else, OS must be Fedora
		dnf install -y openvpn openssl ca-certificates tar $firewall
	fi
	# If firewalld was just installed, enable it
	if [[ "$firewall" == "firewalld" ]]; then
		systemctl enable --now firewalld.service
	fi
	# Get easy-rsa
	easy_rsa_url='https://github.com/OpenVPN/easy-rsa/releases/download/v3.2.6/EasyRSA-3.2.6.tgz'
	mkdir -p /etc/openvpn/server/easy-rsa/
	{ wget -qO- "$easy_rsa_url" 2>/dev/null || curl -sL "$easy_rsa_url" ; } | tar xz -C /etc/openvpn/server/easy-rsa/ --strip-components 1
	chown -R root:root /etc/openvpn/server/easy-rsa/
	cd /etc/openvpn/server/easy-rsa/
	# Create the PKI, set up the CA and create TLS key
	./easyrsa --batch init-pki
	./easyrsa --batch build-ca nopass
	./easyrsa gen-tls-crypt-key
	# Create the DH parameters file using the predefined ffdhe2048 group
	echo '-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD
ssbzSibBsu/6iGtCOGEoXJf//////////wIBAg==
-----END DH PARAMETERS-----' > /etc/openvpn/server/dh.pem
	# Make easy-rsa aware of our external DH file (prevents a warning)
	ln -s /etc/openvpn/server/dh.pem pki/dh.pem
	# Create certificates and CRL
	./easyrsa --batch --days=3650 build-server-full server nopass
	./easyrsa --batch --days=3650 build-client-full "$client" nopass
	./easyrsa --batch --days=3650 gen-crl
	# Move the stuff we need
	cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/crl.pem /etc/openvpn/server
	cp pki/private/easyrsa-tls.key /etc/openvpn/server/tc.key
	# CRL is read with each client connection, while OpenVPN is dropped to nobody
	chown nobody:"$group_name" /etc/openvpn/server/crl.pem
	# Without +x in the directory, OpenVPN can't run a stat() on the CRL file
	chmod o+x /etc/openvpn/server/
	# Generate server.conf
	echo "local $ip
port $port
proto $protocol
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA512
tls-crypt tc.key
topology subnet
server $OVPN_IPV4_NETWORK $OVPN_IPV4_NETMASK" > /etc/openvpn/server/server.conf
	# Fork-specific: client routing is IPv4-only because the transparent Xray
	# integration below captures the fixed OpenVPN IPv4 subnet.
	echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server/server.conf
	echo 'ifconfig-pool-persist ipp.txt' >> /etc/openvpn/server/server.conf
	# DNS
	case "$dns" in
		1|"")
			# Locate the proper resolv.conf
			# Needed for systems running systemd-resolved
			if grep '^nameserver' "/etc/resolv.conf" | grep -qv '127.0.0.53' ; then
				resolv_conf="/etc/resolv.conf"
			else
				resolv_conf="/run/systemd/resolve/resolv.conf"
			fi
			# Obtain the resolvers from resolv.conf and use them for OpenVPN
			grep -v '^#\|^;' "$resolv_conf" | grep '^nameserver' | grep -v '127.0.0.53' | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | while read line; do
				echo "push \"dhcp-option DNS $line\"" >> /etc/openvpn/server/server.conf
			done
		;;
		2)
			echo 'push "dhcp-option DNS 8.8.8.8"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 8.8.4.4"' >> /etc/openvpn/server/server.conf
		;;
		3)
			echo 'push "dhcp-option DNS 1.1.1.1"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 1.0.0.1"' >> /etc/openvpn/server/server.conf
		;;
		4)
			echo 'push "dhcp-option DNS 208.67.222.222"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 208.67.220.220"' >> /etc/openvpn/server/server.conf
		;;
		5)
			echo 'push "dhcp-option DNS 9.9.9.9"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 149.112.112.112"' >> /etc/openvpn/server/server.conf
		;;
		6)
			echo 'push "dhcp-option DNS 95.85.95.85"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 2.56.220.2"' >> /etc/openvpn/server/server.conf
		;;
		7)
			echo 'push "dhcp-option DNS 94.140.14.14"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 94.140.15.15"' >> /etc/openvpn/server/server.conf
		;;
		8)
		for dns_ip in $custom_dns; do
			echo "push \"dhcp-option DNS $dns_ip\"" >> /etc/openvpn/server/server.conf
		done
		;;
	esac
	echo 'push "block-outside-dns"' >> /etc/openvpn/server/server.conf
	echo "keepalive 10 120
user nobody
group $group_name
persist-key
persist-tun
verb 3
crl-verify crl.pem" >> /etc/openvpn/server/server.conf
	if [[ "$protocol" = "udp" ]]; then
		echo "explicit-exit-notify" >> /etc/openvpn/server/server.conf
	fi
	# Enable net.ipv4.ip_forward for the system
	echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-openvpn-forward.conf
	# Enable without waiting for a reboot or service restart
	echo 1 > /proc/sys/net/ipv4/ip_forward
	if systemctl is-active --quiet firewalld.service; then
		# Using both permanent and not permanent rules to avoid a firewalld
		# reload.
		# We don't use --add-service=openvpn because that would only work with
		# the default port and protocol.
		firewall-cmd --add-port="$port"/"$protocol"
		firewall-cmd --permanent --add-port="$port"/"$protocol"
	else
		# Create a service to set up persistent iptables rules
		iptables_path=$(command -v iptables)
		# nf_tables is not available as standard in OVZ kernels. So use iptables-legacy
		# if we are in OVZ, with a nf_tables backend and iptables-legacy is available.
		if [[ $(systemd-detect-virt) == "openvz" ]] && readlink -f "$(command -v iptables)" | grep -q "nft" && hash iptables-legacy 2>/dev/null; then
			iptables_path=$(command -v iptables-legacy)
		fi
		echo "[Unit]
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=$iptables_path -w 5 -I INPUT -p $protocol --dport $port -j ACCEPT
ExecStop=$iptables_path -w 5 -D INPUT -p $protocol --dport $port -j ACCEPT
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/openvpn-iptables.service
		systemctl enable --now openvpn-iptables.service
	fi
	write_xray_tproxy_files
	systemctl daemon-reload
	systemctl enable --now "$XRAY_TPROXY_SERVICE"
	# If SELinux is enabled and a custom port was selected, we need this
	if sestatus 2>/dev/null | grep "Current mode" | grep -q "enforcing" && [[ "$port" != 1194 ]]; then
		# Install semanage if not already present
		if ! hash semanage 2>/dev/null; then
				dnf install -y policycoreutils-python-utils
		fi
		semanage port -a -t openvpn_port_t -p "$protocol" "$port"
	fi
	# If the server is behind NAT, use the correct IP address
	[[ -n "$public_ip" ]] && ip="$public_ip"
	# client-common.txt is created so we have a template to add further users later
	echo "client
dev tun
proto $protocol
remote $ip $port
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
ignore-unknown-option block-outside-dns
verb 3" > /etc/openvpn/server/client-common.txt
	# Enable and start the OpenVPN service
	systemctl enable --now openvpn-server@server.service
	# Build the $client.ovpn file, stripping comments from easy-rsa in the process
	grep -vh '^#' /etc/openvpn/server/client-common.txt /etc/openvpn/server/easy-rsa/pki/inline/private/"$client".inline > "$script_dir"/"$client".ovpn
	echo
	echo "Finished!"
	echo
	echo "The client configuration is available in:" "$script_dir"/"$client.ovpn"
	echo "New clients can be added by running this script again."
	echo
	echo "OpenVPN clients use $OVPN_IPV4_CIDR with server address $OVPN_IPV4_SERVER."
	echo "Traffic is delivered to local Xray TPROXY port $XRAY_TPROXY_PORT."
	echo "Create the 3x-ui/Xray inbound tagged \"$XRAY_TPROXY_TAG\" separately."
	echo "Reference inbound example:" "$XRAY_TPROXY_REFERENCE"
	echo
	echo "Validation commands:"
	echo "  systemctl status $XRAY_TPROXY_SERVICE"
	echo "  ip rule show | grep fwmark"
	echo "  ip route show table $XRAY_ROUTE_TABLE"
	echo "  iptables -t mangle -vnL $XRAY_TPROXY_CHAIN"
	echo "  iptables -t nat -S POSTROUTING | grep $OVPN_IPV4_CIDR || echo 'OK: no direct SNAT'"
else
	clear
	echo "OpenVPN is already installed."
	echo
	echo "Select an option:"
	echo "   1) Add a new client"
	echo "   2) Revoke an existing client"
	echo "   3) Remove OpenVPN"
	echo "   4) Exit"
	read -p "Option: " option
	until [[ "$option" =~ ^[1-4]$ ]]; do
		echo "$option: invalid selection."
		read -p "Option: " option
	done
	case "$option" in
		1)
			echo
			echo "Provide a name for the client:"
			read -p "Name: " unsanitized_client
			client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
			while [[ -z "$client" || -e /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt ]]; do
				echo "$client: invalid name."
				read -p "Name: " unsanitized_client
				client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
			done
			cd /etc/openvpn/server/easy-rsa/
			./easyrsa --batch --days=3650 build-client-full "$client" nopass
			# Build the $client.ovpn file, stripping comments from easy-rsa in the process
			grep -vh '^#' /etc/openvpn/server/client-common.txt /etc/openvpn/server/easy-rsa/pki/inline/private/"$client".inline > "$script_dir"/"$client".ovpn
			echo
			echo "$client added. Configuration available in:" "$script_dir"/"$client.ovpn"
			exit
		;;
		2)
			# This option could be documented a bit better and maybe even be simplified
			# ...but what can I say, I want some sleep too
			number_of_clients=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep -c "^V")
			if [[ "$number_of_clients" = 0 ]]; then
				echo
				echo "There are no existing clients!"
				exit
			fi
			echo
			echo "Select the client to revoke:"
			tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
			read -p "Client: " client_number
			until [[ "$client_number" =~ ^[0-9]+$ && "$client_number" -le "$number_of_clients" ]]; do
				echo "$client_number: invalid selection."
				read -p "Client: " client_number
			done
			client=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$client_number"p)
			echo
			read -p "Confirm $client revocation? [y/N]: " revoke
			until [[ "$revoke" =~ ^[yYnN]*$ ]]; do
				echo "$revoke: invalid selection."
				read -p "Confirm $client revocation? [y/N]: " revoke
			done
			if [[ "$revoke" =~ ^[yY]$ ]]; then
				cd /etc/openvpn/server/easy-rsa/
				./easyrsa --batch revoke "$client"
				./easyrsa --batch --days=3650 gen-crl
				rm -f /etc/openvpn/server/crl.pem
				rm -f /etc/openvpn/server/easy-rsa/pki/reqs/"$client".req
				rm -f /etc/openvpn/server/easy-rsa/pki/private/"$client".key
				cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
				# CRL is read with each client connection, when OpenVPN is dropped to nobody
				chown nobody:"$group_name" /etc/openvpn/server/crl.pem
				echo
				echo "$client revoked!"
			else
				echo
				echo "$client revocation aborted!"
			fi
			exit
		;;
		3)
			echo
			read -p "Confirm OpenVPN removal? [y/N]: " remove
			until [[ "$remove" =~ ^[yYnN]*$ ]]; do
				echo "$remove: invalid selection."
				read -p "Confirm OpenVPN removal? [y/N]: " remove
			done
			if [[ "$remove" =~ ^[yY]$ ]]; then
				port=$(grep '^port ' /etc/openvpn/server/server.conf | cut -d " " -f 2)
				protocol=$(grep '^proto ' /etc/openvpn/server/server.conf | cut -d " " -f 2)
				if systemctl is-active --quiet firewalld.service; then
					# Using both permanent and not permanent rules to avoid a firewalld reload.
					firewall-cmd --remove-port="$port"/"$protocol"
					firewall-cmd --permanent --remove-port="$port"/"$protocol"
				else
					systemctl disable --now openvpn-iptables.service
					rm -f /etc/systemd/system/openvpn-iptables.service
				fi
				cleanup_xray_tproxy
				if sestatus 2>/dev/null | grep "Current mode" | grep -q "enforcing" && [[ "$port" != 1194 ]]; then
					semanage port -d -t openvpn_port_t -p "$protocol" "$port"
				fi
				systemctl disable --now openvpn-server@server.service
				rm -f /etc/systemd/system/openvpn-server@server.service.d/disable-limitnproc.conf
				rm -f /etc/sysctl.d/99-openvpn-forward.conf
				if [[ "$os" = "debian" || "$os" = "ubuntu" ]]; then
					rm -rf /etc/openvpn/server
					apt-get remove --purge -y openvpn
				else
					# Else, OS must be CentOS or Fedora
					dnf remove -y openvpn
					rm -rf /etc/openvpn/server
				fi
				echo
				echo "OpenVPN removed!"
			else
				echo
				echo "OpenVPN removal aborted!"
			fi
			exit
		;;
		4)
			exit
		;;
	esac
fi
