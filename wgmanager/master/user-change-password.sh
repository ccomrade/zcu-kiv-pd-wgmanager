#!/bin/sh

# path to the master server root directory
ROOT=$( dirname "$0" )

. "$ROOT/master.cfg"

. "$ROOT/scripts/util.sh"
. "$ROOT/scripts/api.sh"  # encrypt_password

die()
{
	if [ -t 2 ]
	then
		echo "\033[1;31m$1\033[0m" 1>&2
	else
		echo "$1" 1>&2
	fi

	exit 1
}

read_password()
{
	if [ -t 0 ]
	then
		printf "%s" "$1"

		stty -echo
		read -r PASSWORD
		stty echo

		echo
	else
		read -r PASSWORD
	fi

	[ -n "$PASSWORD" ] || die "Password cannot be empty!"
}

if [ "$#" -ne 1 ]
then
	echo "Usage: $0 USERNAME" 1>&2
	exit 2
fi

USERNAME="$1"

[ -n "$USERNAME" ] || die "Username cannot be empty!"

read_password "Old Password: "
OLD_PASSWORD="$PASSWORD"

read_password "New Password: "
NEW_PASSWORD="$PASSWORD"

if [ -t 0 ]
then
	read_password "New Password Again: "
	NEW_PASSWORD_REPEAT="$PASSWORD"

	[ "$NEW_PASSWORD" = "$NEW_PASSWORD_REPEAT" ] || die "New passwords are not the same!"
fi

OLD_PASSWORD_ENCRYPTED=$( encrypt_password "$OLD_PASSWORD" )
NEW_PASSWORD_ENCRYPTED=$( encrypt_password "$NEW_PASSWORD" )

[ -n "$OLD_PASSWORD_ENCRYPTED" ] && [ -n "$NEW_PASSWORD_ENCRYPTED" ] || die "Password encryption failed!"

# acquire database lock and process the request
if ! flock "$ROOT/db" "$ROOT/scripts/api-user-change-password.sh" "$USERNAME" "$OLD_PASSWORD_ENCRYPTED" "$NEW_PASSWORD_ENCRYPTED"
then
	die "Failed to change password of user $USERNAME!"
fi

echo "Changed password of user $USERNAME"
