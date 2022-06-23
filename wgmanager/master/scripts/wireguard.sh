#!/bin/sh

wireguard_generate_keys()
{
	local user="$1"
	local device="$2"

	( umask 077; wg genkey > "$ROOT/db/$user/$device/private-key" ) || return 1

	cat "$ROOT/db/$user/$device/private-key" | wg pubkey > "$ROOT/db/$user/$device/public-key" || return 1
}

wireguard_create_client_config()
{
	local user="$1"
	local device="$2"

	[ -n "$user" ] && [ -n "$device" ] && [ -d "$ROOT/db/$user/$device" ] || return 1

	local private_key
	local gate_info
	local gate_public_address
	local gate_public_key
	local address_ipv4
	local address_ipv6

	private_key=$( cat "$ROOT/db/$user/$device/private-key" )

	if [ -z "$private_key" ]
	then
		log_error "Missing private key for device $user:$device"
		return 1
	fi

	gate_info=$( cat "$ROOT/db/$user/$device/gate" )

	if [ -z "$gate_info" ]
	then
		log_error "No gate server for device $user:$device"
		return 1
	fi

	gate_public_address=$( echo "$gate_info" | cut -d '|' -f 2 )
	gate_public_key=$(     echo "$gate_info" | cut -d '|' -f 3 )

	[ "$ENABLE_IPV4" = "yes" ] && address_ipv4=$( cat "$ROOT/db/$user/$device/address-ipv4" )
	[ "$ENABLE_IPV6" = "yes" ] && address_ipv6=$( cat "$ROOT/db/$user/$device/address-ipv6" )

	if [ -z "$address_ipv4" ] && [ -z "$address_ipv6" ]
	then
		log_error "No address for device $user:$device"
		return 1
	fi

	local config="$ROOT/db/$user/$device/config"

	echo "[Interface]"                                              >  "$config"
	[ -n "$address_ipv4" ] && echo "Address = $address_ipv4"        >> "$config"
	[ -n "$address_ipv6" ] && echo "Address = $address_ipv6"        >> "$config"
	echo "PrivateKey = $private_key"                                >> "$config"
	echo "DNS = $DNS_SERVERS"                                       >> "$config"
	echo                                                            >> "$config"
	echo "[Peer]"                                                   >> "$config"
	echo "Endpoint = $gate_public_address"                          >> "$config"
	echo "PublicKey = $gate_public_key"                             >> "$config"
	[ -n "$PRESHARED_KEY" ] && echo "PresharedKey = $PRESHARED_KEY" >> "$config"
	echo "AllowedIPs = 0.0.0.0/0, ::/0"                             >> "$config"
	echo "PersistentKeepalive = 25"                                 >> "$config"
}
