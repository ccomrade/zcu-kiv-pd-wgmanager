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

( OnStop )

ip link delete "$WIREGUARD_INTERFACE" || die "Failed to remove WireGuard interface"
