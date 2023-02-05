#!/bin/bash

. "$(dirname "$(realpath "${BASH_SOURCE}")")"/errorMessages.sh

fail() {
	printf '%s\n' "$1" >&2 ## Send message to stderr.
	exit "${2-1}" ## Return a code specified by $2, or 1 by default.
}

warning() {
	printf '%s\n' "$1" >&2 ## Send message to stderr.
}