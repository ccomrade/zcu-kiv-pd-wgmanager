#!/bin/sh

# path to the gate server root directory
ROOT=$( dirname "$0" )

. "$ROOT/gate.cfg"

. "$ROOT/scripts/util.sh"

GATE_PUBLIC_KEY=$( cat "$ROOT/public-key" )

# inform the master server that we are running and waiting for the initial configuration
if ! send_request "{\"key\":\"$GATE_PUBLIC_KEY\"}" "$MASTER_SERVER_URL/api/gate/started"
then
	log_error "Failed to notify master server"
	exit 1
fi
