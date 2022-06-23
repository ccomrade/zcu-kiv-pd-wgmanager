#!/bin/sh

# path to the master server root directory
ROOT=$( dirname "$0" )"/.."

. "$ROOT/master.cfg"

. "$ROOT/scripts/util.sh"
. "$ROOT/scripts/api.sh"

USERNAME="$1"
PASSWORD_OLD="$2"  # encrypted password
PASSWORD_NEW="$3"  # encrypted password

if ! verify_user_credentials "$USERNAME" "$PASSWORD_OLD"
then
	log_info "Invalid credentials of user $USERNAME"
	response_ok "{\"status\":\"fail\"}"
	exit 1
fi

log_info "Changing password of user $USERNAME"

if ! add_user_to_shadow "$USERNAME" "$PASSWORD_NEW"
then
	log_error "Failed to update password of user $USERNAME in the shadow file"
	response_server_error
	exit 1
fi

response_ok
