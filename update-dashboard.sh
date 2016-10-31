#!/bin/bash
#
# Updates containers on 'Docker Container Status' dashboard
#
# Usage:
#
#   ./update-dashboard.sh
#

function help {
  echo "Usage: update-dashboard.sh"
}

function load_params {
  SHORT=h
  LONG=help

  PARSED=`getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@"`
  if [[ $? != 0 ]]; then
    exit 2
  fi
  eval set -- "$PARSED"
  
  while true; do
    case "$1" in
      -h|--help)
        help
        exit 0;
	      ;;
      --)
        shift
        break
        ;;
    esac
  done
}

load_params $@

dashboards/init-dashboard.sh --init=false

