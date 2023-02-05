#!/bin/bash

usage() {
  cat - >&2 <<EOF
NAME
    $(basename $0) - Nginx Setup
    Coming soon ...
 
SYNOPSIS
    setup.sh [-h|--help]

REQUIRED ARGUMENTS
  FILE ...
          input files

OPTIONS
  -h, --help
          Prints this and exits

EOF
}

( [[ -n $ZSH_VERSION && $ZSH_EVAL_CONTEXT =~ :file$ ]] || 
  [[ -n $KSH_VERSION && "$(cd -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")" != "$(cd -- "$(dirname -- "${.sh.file}")" && pwd -P)/$(basename -- "${.sh.file}")" ]] || 
  [[ -n $BASH_VERSION ]] && (return 0 2>/dev/null)
) || fail $TIRSVADCLI_NGINXSETUP_HASTOBESOURCES

# clean up
rm -fr $NGINXSETUP_TEMP

VALID_ARGS=$(getopt -o hr: --long help,remote: -- "$@")

if [[ $? -ne 0 ]]; then
    exit 1;
fi

eval set -- "$VALID_ARGS"
while [ : ]; do
  case "$1" in
    -h | --help)
      echo "Processing 'help' option."
      usage
      shift;
      ;;
  esac
done
