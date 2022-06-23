#!/bin/sh

# path to the master server root directory
ROOT=$( dirname "$0" )"/.."

. "$ROOT/master.cfg"

. "$ROOT/scripts/util.sh"
. "$ROOT/scripts/api.sh"

USERNAME="$1"

# make sure the username contains only allowed characters
if ! check_name "$USERNAME"
then
	log_info "Invalid user name '$USERNAME'"
	response_ok "{\"status\":\"invalid_name\"}"
	exit 1
fi

if ! [ -d "$ROOT/db/$USERNAME" ]
then
	log_info "User $USERNAME does not exist"
	response_ok "{\"status\":\"unknown_user\"}"
	exit 1
fi

log_info "Removing user $USERNAME"

if ! remove_user_from_shadow "$USERNAME"
then
	log_error "Failed to remove user $USERNAME from the shadow file"
	response_server_error
	exit 1
fi

find "$ROOT/db/$USERNAME/" -mindepth 1 -maxdepth 1 -type d -exec basename {} ';' | while read -r DEVICE
do
	log_info "Removing device $USERNAME:$DEVICE"
	remove_device "$USERNAME" "$DEVICE"
done

rm -r -f "$ROOT/db/$USERNAME"

if [ -d "$ROOT/db/$USERNAME" ]
then
	log_error "Failed to remove user $USERNAME from the database"
	response_server_error
	exit 1
fi

response_ok
