#!/bin/sh

# path to the master server root directory
ROOT=$( dirname "$0" )"/.."

. "$ROOT/master.cfg"

. "$ROOT/scripts/util.sh"
. "$ROOT/scripts/api.sh"

GATE_KEY="$1"

GATE_INFO=$( echo "$GATE_SERVERS" | sed 's/[[:space:]]\+/\n/g' | grep "|$GATE_KEY$" )

if [ -z "$GATE_INFO" ]
then
	log_info "Unknown gate key $GATE_KEY"
	response_ok "{\"status\":\"unknown_gate\"}"
	exit 1
fi

log_info "Registering all devices of gate $GATE_INFO"

GATE_LOCAL_ADDRESS=$( echo "$GATE_INFO" | cut -d '|' -f 1 )

find "$ROOT/db" -mindepth 2 -maxdepth 2 -type d | while read -r DEVICE_DIRECTORY
do
	if grep -q "^$GATE_INFO$" "$DEVICE_DIRECTORY/gate"
	then
		USERNAME=$( echo "$DEVICE_DIRECTORY" | rev | cut -d '/' -f 2 | rev )
		DEVICE=$(   echo "$DEVICE_DIRECTORY" | rev | cut -d '/' -f 1 | rev )

		if ! gate_client "add" "$USERNAME" "$DEVICE" "$GATE_LOCAL_ADDRESS"
		then
			log_error "Failed to register device $USERNAME:$DEVICE to gate $GATE_INFO"
			response_ok "{\"status\":\"gate_error\"}"
			exit 1
		fi
	fi
done

response_ok
