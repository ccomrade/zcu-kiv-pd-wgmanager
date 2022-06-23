#!/bin/sh

log_info()
{
	echo "<6>$1" 1>&2
}

log_error()
{
	echo "<3>$1" 1>&2
}

cgi_echo()
{
	printf "%s\r\n" "$1"
}

response()
{
	local status="$1"
	local content="$2"

	local content_length

	[ -z "$content" ] && content="{}"

	content_length=$( echo "$content" | wc -c )

	cgi_echo "Status: $status"
	cgi_echo "Content-Type: application/json"
	cgi_echo "Content-Length: $content_length"
	cgi_echo

	echo "$content"
}

response_ok()
{
	local content="$1"

	[ -z "$content" ] && content="{\"status\":\"success\"}"

	response "200 OK" "$content"
}

response_invalid_request()
{
	local content="$1"

	[ -z "$content" ] && content="{\"status\":\"invalid_request\"}"

	response "400 Bad Request" "$content"
}

response_server_error()
{
	local content="$1"

	[ -z "$content" ] && content="{\"status\":\"error\"}"

	response "500 Internal Server Error" "$content"
}

send_request()
{
	local data="$1"
	local url="$2"

	unset REQUEST_RESULT
	unset REQUEST_STATUS

	if ! REQUEST_RESULT=$( curl -s -S --request POST --header "Content-Type: application/json" --data "$data" "$url" )
	then
		log_error "Request to $url failed"
		return 1
	fi

	if ! REQUEST_STATUS=$( echo "$REQUEST_RESULT" | jq -r '.status // empty' ) || [ "$REQUEST_STATUS" != "success" ]
	then
		log_error "Request to $url failed with result: $REQUEST_RESULT"
		return 1
	fi
}
