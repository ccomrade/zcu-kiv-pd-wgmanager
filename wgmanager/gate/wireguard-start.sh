#!/bin/sh

# path to the gate server root directory
ROOT=$( dirname "$0" )

. "$ROOT/gate.cfg"

. "$ROOT/scripts/util.sh"
. "$ROOT/callbacks.sh"

die()
{
	log_error "$1"

	exit 1
}

log_info "Using WireGuard interface $WIREGUARD_INTERFACE"

ip link add dev "$WIREGUARD_INTERFACE" type wireguard || die "Failed to create WireGuard interface"

if [ -n "$GATE_ADDRESS_IPV4" ]
then
	log_info "Using IPv4 address $GATE_ADDRESS_IPV4"

	ip -4 addr add "$GATE_ADDRESS_IPV4" dev "$WIREGUARD_INTERFACE" || die "Failed to set IPv4 address"
fi

if [ -n "$GATE_ADDRESS_IPV6" ]
then
	log_info "Using IPv6 address $GATE_ADDRESS_IPV6"

	ip -6 addr add "$GATE_ADDRESS_IPV6" dev "$WIREGUARD_INTERFACE" || die "Failed to set IPv6 address"
fi

wg set "$WIREGUARD_INTERFACE" listen-port "$WIREGUARD_LISTEN_PORT" private-key "$ROOT/private-key" || die "WireGuard init failed"

ip link set "$WIREGUARD_INTERFACE" up || die "Failed to bring up WireGuard interface"

( OnStart )
