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

url_encode()
{
	printf "%s" "$1" | jq -s -R -r '@uri'
}

validate_query_string()
{
	# empty query string is valid
	[ -z "$1" ] && return 0

	# add trailing '&' for easier matching
	echo "$1&" | LC_ALL=C grep -q -E '^([A-Za-z0-9\._-]+=([A-Za-z0-9\+\*\.~_-]|%[[:xdigit:]][[:xdigit:]])*&)+$'
}

query_string_get_value()
{
	# TODO: POSIX echo command does not support '-e' option and '\xHH' escape sequence
	echo "$1" | sed 's/&/\n/g' | grep "^$2=" | cut -d '=' -f 2 | sed 's/+/ /g; s/%/\\\\x/g' | xargs echo -e
}

http_redirect()
{
	local url="$1"

	if [ "$SERVER_PROTOCOL" = "HTTP/1.0" ]
	then
		cgi_echo "Status: 302 Moved Temporarily"
	else
		cgi_echo "Status: 303 See Other"
	fi

	[ -n "$SESSION_REFRESH" ] && cgi_echo "Set-Cookie: session=$SESSION_REFRESH; HttpOnly"

	cgi_echo "Location: $url"
	cgi_echo "Content-Length: 0"
	cgi_echo

	exit 0
}

response_begin()
{
	cgi_echo "Status: 200 OK"

	[ -n "$SESSION_REFRESH" ] && cgi_echo "Set-Cookie: session=$SESSION_REFRESH; HttpOnly"
}

create_message_page_content()
{
	local message="$1"

	echo "<!DOCTYPE html>"
	echo "<html lang=\"en\">"
	echo "<head>"
	echo "  <meta charset=\"UTF-8\">"
	echo "  <title>WireGuard VPN Manager</title>"
	echo "</head>"
	echo "<body>"
	echo "  <h1>$message</h1>"
	echo "</body>"
	echo "</html>"
}

show_message_page()
{
	local status="$1"
	local message="$2"

	[ -z "$message" ] && message="$status"

	local content
	local content_length

	content=$( create_message_page_content "$message" )

	content_length=$( echo "$content" | wc -c )

	cgi_echo "Status: $status"
	cgi_echo "Content-Type: text/html"
	cgi_echo "Content-Length: $content_length"
	cgi_echo

	echo "$content"
}

invalid_request()
{
	log_error "Invalid request to '$REQUEST_URI' from $REMOTE_ADDR:$REMOTE_PORT"
	show_message_page "400 Bad Request"
	exit 1
}

server_error()
{
	log_error "Internal server error when processing request to '$REQUEST_URI' from $REMOTE_ADDR:$REMOTE_PORT"
	show_message_page "500 Internal Server Error"
	exit 1
}

show_error()
{
	log_error "Error '$1' when processing request to '$REQUEST_URI' from $REMOTE_ADDR:$REMOTE_PORT"
	show_message_page "200 OK" "$1"
	exit 1
}

show_page()
{
	local content
	local content_length

	content=$( create_page_content )

	content_length=$( echo "$content" | wc -c )

	response_begin

	cgi_echo "Content-Type: text/html"
	cgi_echo "Content-Length: $content_length"
	cgi_echo

	echo "$content"

	exit 0
}

login_redirect()
{
	local continue_param

	continue_param=$( url_encode "$REQUEST_URI" )

	http_redirect "login?continue=$continue_param"
}

init_session()
{
	SESSION=$( echo "$HTTP_COOKIE" | sed 's/; */\n/g' | grep '^session=' | cut -d '=' -f 2- )

	if [ -z "$SESSION" ]
	then
		login_redirect
	fi
}

send_request()
{
	local data="$1"
	local url="$2"

	unset REQUEST_RESULT
	unset REQUEST_STATUS
	unset SESSION_REFRESH

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

	SESSION_REFRESH=$( echo "$REQUEST_RESULT" | jq -r '.session // empty' )
}

encrypt_password()
{
	printf "%s" "$1" | openssl rsautl -encrypt -pubin -inkey "$ROOT/master-server-key.pem" | base64 -w 0
}

check_name()
{
	# empty names are invalid
	echo "$1" | LC_ALL=C grep -q -E '^[a-zA-Z0-9_-]+$'
}
