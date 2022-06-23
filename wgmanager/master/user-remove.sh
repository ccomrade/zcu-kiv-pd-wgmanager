#!/bin/sh

# path to the master server root directory
ROOT=$( dirname "$0" )

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

if [ "$#" -ne 1 ]
then
	echo "Usage: $0 USERNAME" 1>&2
	exit 2
fi

USERNAME="$1"

[ -n "$USERNAME" ] || die "Username cannot be empty!"

# acquire database lock and process the request
flock "$ROOT/db" "$ROOT/scripts/api-user-remove.sh" "$USERNAME" || die "Failed to remove user $USERNAME!"

echo "Removed user $USERNAME"
