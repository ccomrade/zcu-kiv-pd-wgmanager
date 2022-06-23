#!/bin/sh

wireguard_add_client()
{
	local key="$1"        # client public key
	local ipv4_cidr="$2"  # IPv4 address in CIDR notation, may be empty
	local ipv6_cidr="$3"  # IPv6 address in CIDR notation, may be empty

	local ipv4_address
	local ipv6_address
	local addresses

	ipv4_address=$( echo "$ipv4_cidr" | cut -d '/' -f 1 )
	ipv6_address=$( echo "$ipv6_cidr" | cut -d '/' -f 1 )

	if [ -n "$ipv4_address" ]
	then
		addresses="$ipv4_address/32"
	fi

	if [ -n "$ipv6_address" ]
	then
		if [ -n "$addresses" ]
		then
			addresses="$addresses,$ipv6_address/128"
		else
			addresses="$ipv6_address/128"
		fi
	fi

	wg set "$WIREGUARD_INTERFACE" peer "$key" preshared-key "$ROOT/preshared-key" allowed-ips "$addresses"
}

wireguard_remove_client()
{
	local key="$1"  # client public key

	wg set "$WIREGUARD_INTERFACE" peer "$key" remove
}
