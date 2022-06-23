#!/bin/sh

# path to the master server root directory
ROOT=$( dirname "$0" )"/.."

. "$ROOT/master.cfg"

. "$ROOT/scripts/util.sh"
. "$ROOT/scripts/api.sh"
. "$ROOT/scripts/wireguard.sh"

SESSION="$1"
DEVICE="$2"
DESCRIPTION="$3"

if ! validate_session
then
	log_info "Invalid session '$SESSION'"
	response_ok "{\"status\":\"invalid_session\"}"
	exit 1
fi

# make sure the device name contains only allowed characters
if ! check_name "$DEVICE"
then
	log_info "Invalid device name '$DEVICE' for user $USERNAME"
	response_ok "{\"status\":\"invalid_name\"}"
	exit 1
fi

if [ -d "$ROOT/db/$USERNAME/$DEVICE" ]
then
	log_info "Device $USERNAME:$DEVICE already exists"
	response_ok "{\"status\":\"device_exists\"}"
	exit 1
fi

DEVICE_COUNT=$( find "$ROOT/db/$USERNAME/" -mindepth 1 -maxdepth 1 -type d | wc -l )

if [ "$DEVICE_COUNT" -ge "$MAX_DEVICES" ]
then
	log_info "Maximum device count reached for user $USERNAME"
	response_ok "{\"status\":\"max_device_count\"}"
	exit 1
fi

log_info "Adding device $USERNAME:$DEVICE"

cleanup()
{
	local address_ipv4
	local address_ipv6

	if [ -s "$ROOT/db/$USERNAME/$DEVICE/address-ipv4" ]
	then
		address_ipv4=$( cat "$ROOT/db/$USERNAME/$DEVICE/address-ipv4" )
		free_address "ipv4" "$address_ipv4"
	fi

	if [ -s "$ROOT/db/$USERNAME/$DEVICE/address-ipv6" ]
	then
		address_ipv6=$( cat "$ROOT/db/$USERNAME/$DEVICE/address-ipv6" )
		free_address "ipv6" "$address_ipv6"
	fi

	rm -r -f "$ROOT/db/$USERNAME/$DEVICE"
}

DATABASE_OWNER=$( stat -c '%U:%G' "$ROOT/db" )

if ! mkdir "$ROOT/db/$USERNAME/$DEVICE" || ! chown "$DATABASE_OWNER" "$ROOT/db/$USERNAME/$DEVICE"
then
	cleanup
	log_error "Failed to add device $USERNAME:$DEVICE to the database"
	response_server_error
	exit 1
fi

log_info "Database entry created"

if ! wireguard_generate_keys "$USERNAME" "$DEVICE"
then
	cleanup
	log_error "Failed to generate keys for device $USERNAME:$DEVICE"
	response_server_error
	exit 1
fi

log_info "Keys generated"

touch "$ROOT/db/$USERNAME/$DEVICE/description"

# store device description encoded in Base64
[ -n "$DESCRIPTION" ] && echo "$DESCRIPTION" > "$ROOT/db/$USERNAME/$DEVICE/description"

touch "$ROOT/db/$USERNAME/$DEVICE/address-ipv4"
touch "$ROOT/db/$USERNAME/$DEVICE/address-ipv6"

if [ "$ENABLE_IPV4" = "yes" ]
then
	if ! allocate_address "ipv4" > "$ROOT/db/$USERNAME/$DEVICE/address-ipv4"
	then
		cleanup
		log_error "Failed to allocate IPv4 address for device $USERNAME:$DEVICE"
		response_server_error
		exit 1
	fi
fi

if [ "$ENABLE_IPV6" = "yes" ]
then
	if ! allocate_address "ipv6" > "$ROOT/db/$USERNAME/$DEVICE/address-ipv6"
	then
		cleanup
		log_error "Failed to allocate IPv6 address for device $USERNAME:$DEVICE"
		response_server_error
		exit 1
	fi
fi

log_info "Addresses allocated"

GATE_INFO=$( choose_gate_server )

log_info "Using gate server $GATE_INFO"

echo "$GATE_INFO" > "$ROOT/db/$USERNAME/$DEVICE/gate"

if ! wireguard_create_client_config "$USERNAME" "$DEVICE"
then
	cleanup
	log_error "Failed to create configuration file for device $USERNAME:$DEVICE"
	response_server_error
	exit 1
fi

log_info "Configuration file created"

GATE_LOCAL_ADDRESS=$( echo "$GATE_INFO" | cut -d '|' -f 1 )

# register the new device on its gate server
if ! gate_client "add" "$USERNAME" "$DEVICE" "$GATE_LOCAL_ADDRESS"
then
	cleanup
	log_error "Failed to register device $USERNAME:$DEVICE on gate server $GATE_INFO"
	response_server_error
	exit 1
fi

log_info "Device registered on its gate server"

response_ok "{\"status\":\"success\",\"session\":\"$SESSION_REFRESH\"}"
