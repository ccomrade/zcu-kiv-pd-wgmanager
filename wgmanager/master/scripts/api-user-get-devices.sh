#!/bin/sh

# path to the master server root directory
ROOT=$( dirname "$0" )"/.."

. "$ROOT/master.cfg"

. "$ROOT/scripts/util.sh"
. "$ROOT/scripts/api.sh"

SESSION="$1"

if ! validate_session
then
	log_info "Invalid session '$SESSION'"
	response_ok "{\"status\":\"invalid_session\"}"
	exit 1
fi

log_info "Obtaining devices for user $USERNAME"

get_device_info()
{
	local user="$1"
	local device="$2"

	local description
	local address_ipv4
	local address_ipv6

	description=$( cat "$ROOT/db/$user/$device/description" )

	[ "$ENABLE_IPV4" = "yes" ] && address_ipv4=$( cat "$ROOT/db/$user/$device/address-ipv4" )
	[ "$ENABLE_IPV6" = "yes" ] && address_ipv6=$( cat "$ROOT/db/$user/$device/address-ipv6" )

	local address="{\"ipv4\":\"$address_ipv4\",\"ipv6\":\"$address_ipv6\"}"

	printf "%s" "{\"name\":\"$device\",\"description\":\"$description\",\"address\":$address}"
}

DEVICE_LIST=$( find "$ROOT/db/$USERNAME/" -mindepth 1 -maxdepth 1 -type d -exec basename {} ';' | while read -r DEVICE
do
	if [ -z "$FIRST" ]
	then
		FIRST="false"
	else
		printf ","
	fi

	get_device_info "$USERNAME" "$DEVICE"
done )

response_ok "{\"status\":\"success\",\"session\":\"$SESSION_REFRESH\",\"username\":\"$USERNAME\",\"devices\":[$DEVICE_LIST]}"
