#!/bin/sh

# path to the master server root directory
ROOT=$( dirname "$0" )"/.."

. "$ROOT/master.cfg"

. "$ROOT/scripts/util.sh"
. "$ROOT/scripts/api.sh"

USERNAME="$1"
PASSWORD="$2"  # encrypted password

# make sure the username contains only allowed characters
if ! check_name "$USERNAME"
then
	log_info "Invalid user name '$USERNAME'"
	response_ok "{\"status\":\"invalid_name\"}"
	exit 1
fi

if [ -d "$ROOT/db/$USERNAME" ]
then
	log_info "User $USERNAME already exists"
	response_ok "{\"status\":\"user_exists\"}"
	exit 1
fi

log_info "Adding user $USERNAME"

cleanup()
{
	rm -r -f "$ROOT/db/$USERNAME"
	remove_user_from_shadow "$USERNAME"
}

DATABASE_OWNER=$( stat -c '%U:%G' "$ROOT/db" )

if ! mkdir "$ROOT/db/$USERNAME" || ! chown "$DATABASE_OWNER" "$ROOT/db/$USERNAME"
then
	cleanup
	log_error "Failed to add user $USERNAME to the database"
	response_server_error
	exit 1
fi

if ! add_user_to_shadow "$USERNAME" "$PASSWORD"
then
	cleanup
	log_error "Failed to add user $USERNAME to the shadow file"
	response_server_error
	exit 1
fi

response_ok
