#!/bin/sh

# path to the master server root directory
ROOT=$( dirname "$0" )"/.."

. "$ROOT/master.cfg"

. "$ROOT/scripts/util.sh"
. "$ROOT/scripts/api.sh"

SESSION="$1"
DEVICE="$2"

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

if ! [ -d "$ROOT/db/$USERNAME/$DEVICE" ]
then
	log_info "Device $USERNAME:$DEVICE does not exist"
	response_ok "{\"status\":\"unknown_device\"}"
	exit 1
fi

log_info "Obtaining configuration for device $USERNAME:$DEVICE"

DEVICE_CONFIG=$( base64 -w 0 "$ROOT/db/$USERNAME/$DEVICE/config" )

response_ok "{\"status\":\"success\",\"session\":\"$SESSION_REFRESH\",\"config\":\"$DEVICE_CONFIG\"}"
