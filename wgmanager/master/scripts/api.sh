#!/bin/sh

check_name()
{
	# empty names are invalid
	echo "$1" | LC_ALL=C grep -q -E '^[a-zA-Z0-9_-]+$'
}

encrypt_password()
{
	printf "%s" "$1" | openssl rsautl -encrypt -pubin -inkey "$ROOT/public-key.pem" | base64 -w 0
}

decrypt_password()
{
	printf "%s" "$1" | base64 --decode | openssl rsautl -decrypt -inkey "$ROOT/private-key.pem"
}

add_user_to_shadow()
{
	local user="$1"
	local password="$2"  # encrypted password

	# make sure the username contains only allowed characters
	check_name "$user" || return 1

	local password_plain

	# decode and decrypt the password
	password_plain=$( decrypt_password "$password" ) || return 1

	# add new user or update password of existing user
	printf "%s" "$password_plain" | htpasswd -i -B -C 10 "$ROOT/shadow" "$user"
}

remove_user_from_shadow()
{
	local user="$1"

	grep -q "^$user:" "$ROOT/shadow" && htpasswd -D "$ROOT/shadow" "$user"
}

verify_user_credentials()
{
	local user="$1"
	local password="$2"  # encrypted password

	# make sure the username contains only allowed characters
	check_name "$user" || return 1

	local password_plain

	# decode and decrypt the password
	password_plain=$( decrypt_password "$password" ) || return 1

	# check if the login credentials are correct
	printf "%s" "$password_plain" | htpasswd -i -B -v "$ROOT/shadow" "$user"
}

get_user_password_hash()
{
	grep "^$1:" "$ROOT/shadow" | cut -d ':' -f 2
}

encode_session()
{
	# '/' => '.'
	# '=' => '_'
	printf "%s:%s:%s" "$1" "$2" "$3" | base64 -w 0 | sed 's/\//\./g; s/=/_/g'
}

decode_session()
{
	# '.' => '/'
	# '_' => '='
	echo "$1" | sed 's/\./\//g; s/_/=/g' | base64 --decode
}

generate_session_token()
{
	local user="$1"
	local timestamp="$2"

	[ -n "$timestamp" ] || return 1

	local key

	# use directly bcrypt hash of user password as secret key for HMAC
	key=$( get_user_password_hash "$user" )

	[ -n "$key" ] || return 1

	printf "%s:%s" "$user" "$timestamp" | openssl sha256 -hmac "$key" | sed 's/^.* //'  # remove '(stdin)= '
}

create_session()
{
	local user="$1"

	local current_timestamp
	local token

	# unix timestamp
	current_timestamp=$( date '+%s' )

	# generate access token
	token=$( generate_session_token "$user" "$current_timestamp" )

	[ -n "$token" ] || return 1

	# encode all the session data into single string
	SESSION=$( encode_session "$user" "$current_timestamp" "$token" )
}

validate_session()
{
	local session_decoded

	session_decoded=$( decode_session "$SESSION" ) || return 1

	USERNAME=$( echo "$session_decoded" | cut -d ':' -f 1 )

	# make sure the username contains only allowed characters
	check_name "$USERNAME" || return 1

	local timestamp
	local token
	local expected_token

	timestamp=$( echo "$session_decoded" | cut -d ':' -f 2 )
	token=$(     echo "$session_decoded" | cut -d ':' -f 3 )

	expected_token=$( generate_session_token "$USERNAME" "$timestamp" )

	# check if the token is valid
	[ "$token" = "$expected_token" ] || return 1

	local current_timestamp
	local timestamp_diff

	current_timestamp=$( date '+%s' )

	timestamp_diff=$(( $current_timestamp - $timestamp ))

	# future timestamps are invalid
	[ "$timestamp_diff" -ge 0 ] || return 1

	unset SESSION_REFRESH

	if [ "$timestamp_diff" -gt "$SESSION_TIMEOUT_SECS" ]
	then
		# session has expired and needs to be renewed

		if [ "$timestamp_diff" -gt "$SESSION_REFRESH_SECS" ]
		then
			# session cannot be renewed
			log_info "Expired session of user $USERNAME"
			response_ok "{\"status\":\"session_expired\"}"
			exit 1
		fi

		local current_token

		# generate new token
		current_token=$( generate_session_token "$USERNAME" "$current_timestamp" )

		# the new session must be added to response sent to client
		SESSION_REFRESH=$( encode_session "$USERNAME" "$current_timestamp" "$current_token" )

		log_info "Renewed session for user $USERNAME"
	fi
}

allocate_address()
{
	local address_type="$1"  # 'ipv4' or 'ipv6'

	local address

	# get the first available address
	address=$( head -n 1 "$ROOT/pool-$address_type" )

	# maybe the pool is empty
	[ -n "$address" ] || return 1

	# remove the address from the pool
	sed -i '1d' "$ROOT/pool-$address_type" || return 1

	log_info "Address $address taken from the pool"

	echo "$address"
}

free_address()
{
	local address_type="$1"  # 'ipv4' or 'ipv6'
	local address="$2"

	[ -n "$address" ] || return 1

	# put the address back to the pool
	echo "$address" >> "$ROOT/pool-$address_type"

	log_info "Address $address added back to the pool"
}

choose_gate_server()
{
	local gates

	gates=$( find "$ROOT/db" -type f -name "gate" -exec cat {} '+'; echo "$GATE_SERVERS" | sed 's/[[:space:]]\+/\n/g' )

	# get the least used gate server
	echo "$gates" | sort | uniq -c | sort -n | head -n 1 | sed 's/^ *//' | cut -d ' ' -f 2
}

gate_client()
{
	local action="$1"  # 'add' or 'remove'
	local user="$2"
	local device="$3"
	local gate_local_address="$4"

	local key
	local address_ipv4
	local address_ipv6

	# WireGuard keys are already encoded in Base64
	key=$( cat "$ROOT/db/$user/$device/public-key" )

	[ "$ENABLE_IPV4" = "yes" ] && address_ipv4=$( cat "$ROOT/db/$user/$device/address-ipv4" )
	[ "$ENABLE_IPV6" = "yes" ] && address_ipv6=$( cat "$ROOT/db/$user/$device/address-ipv6" )

	local address="{\"ipv4\":\"$address_ipv4\",\"ipv6\":\"$address_ipv6\"}"

	local client="{\"user\":\"$user\",\"device\":\"$device\",\"key\":\"$key\",\"address\":$address}"

	# register or deregister the device on the gate server
	send_request "$client" "http://$gate_local_address/cgi-bin/api/client/$action"
}

remove_device()
{
	local user="$1"
	local device="$2"

	[ -n "$user" ] && [ -n "$device" ] && [ -d "$ROOT/db/$user/$device" ] || return 1

	local gate_local_address
	local address_ipv4
	local address_ipv6

	gate_local_address=$( cat "$ROOT/db/$user/$device/gate" | cut -d '|' -f 1 )

	# deregister the device from its gate server
	gate_client "remove" "$user" "$device" "$gate_local_address"

	if [ -s "$ROOT/db/$user/$device/address-ipv4" ]
	then
		address_ipv4=$( cat "$ROOT/db/$user/$device/address-ipv4" )
		free_address "ipv4" "$address_ipv4"
	fi

	if [ -s "$ROOT/db/$user/$device/address-ipv6" ]
	then
		address_ipv6=$( cat "$ROOT/db/$user/$device/address-ipv6" )
		free_address "ipv6" "$address_ipv6"
	fi

	# remove the device from our database
	rm -r -f "$ROOT/db/$user/$device"
}
