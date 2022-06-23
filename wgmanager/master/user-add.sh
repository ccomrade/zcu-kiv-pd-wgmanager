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

read_password "Password: "

if [ -t 0 ]
then
	PASSWORD_REPEAT="$PASSWORD"
	read_password "Password Again: "

	[ "$PASSWORD" = "$PASSWORD_REPEAT" ] || die "Passwords are not the same!"
fi

PASSWORD_ENCRYPTED=$( encrypt_password "$PASSWORD" )

[ -n "$PASSWORD_ENCRYPTED" ] || die "Password encryption failed!"

# acquire database lock and process the request
flock "$ROOT/db" "$ROOT/scripts/api-user-create.sh" "$USERNAME" "$PASSWORD_ENCRYPTED" || die "Failed to add user $USERNAME!"

echo "Added user $USERNAME"
