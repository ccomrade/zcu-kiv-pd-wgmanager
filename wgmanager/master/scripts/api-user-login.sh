#!/bin/sh

# path to the master server root directory
ROOT=$( dirname "$0" )"/.."

. "$ROOT/master.cfg"

. "$ROOT/scripts/util.sh"
. "$ROOT/scripts/api.sh"

USERNAME="$1"
PASSWORD="$2"  # encrypted password

if ! verify_user_credentials "$USERNAME" "$PASSWORD"
then
	log_info "Invalid login credentials of user $USERNAME"
	response_ok "{\"status\":\"fail\"}"
	exit 1
fi

if ! create_session "$USERNAME"
then
	log_error "Failed to create session for user $USERNAME"
	response_server_error
	exit 1
fi

log_info "User $USERNAME logged in"

response_ok "{\"status\":\"success\",\"session\":\"$SESSION\"}"
