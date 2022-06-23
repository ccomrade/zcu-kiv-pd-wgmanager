#!/bin/sh

OnClientAdded()
{
	local user="$1"       # user name
	local name="$2"       # device name
	local key="$3"        # device public key
	local ipv4_cidr="$4"  # IPv4 address of the device, in CIDR notation, may be empty
	local ipv6_cidr="$5"  # IPv6 address of the device, in CIDR notation, may be empty

	echo "Running OnClientAdded callbacks..."
}

OnClientRemoved()
{
	local user="$1"       # user name
	local name="$2"       # device name
	local key="$3"        # device public key
	local ipv4_cidr="$4"  # IPv4 address of the device, in CIDR notation, may be empty
	local ipv6_cidr="$5"  # IPv6 address of the device, in CIDR notation, may be empty

	echo "Running OnClientRemoved callbacks..."
}

OnStart()
{
	echo "Running OnStart callbacks..."
}

OnStop()
{
	echo "Running OnStop callbacks..."
}
