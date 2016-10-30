#!/bin/bash
#
# Updates containers on 'Docker Container Status' dashboard
#
# Usage:
#
#   ./update-dashboard.sh
#

GRAFANA_URL='http://localhost:3000/'
GRAFANA_API_URL='http://localhost:3000/api/'
GRAFANA_LOGIN='admin'
GRAFANA_PASSWORD='foobar'

NEWLINE='
'
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

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

COOKIEJAR=$(mktemp)
trap 'unlink ${COOKIEJAR}' EXIT

function setup_grafana_session {
  if ! curl -H 'Content-Type: application/json;charset=UTF-8' \
    --data-binary "{\"user\":\"${GRAFANA_LOGIN}\",\"email\":\"\",\"password\":\"${GRAFANA_PASSWORD}\"}" \
    --cookie-jar "$COOKIEJAR" \
    "${GRAFANA_URL}login" > /dev/null 2>&1 ; then
    echo
    error "Grafana Session: Couldn't store cookies at ${COOKIEJAR}"
    exit 1
  fi
}

function success {
  echo "$(tput setaf 2)""$*""$(tput sgr0)"
}

function info {
  echo "$(tput setaf 3)""$*""$(tput sgr0)"
}

function error {
  echo "$(tput setaf 1)""$*""$(tput sgr0)" 1>&2
}

setup_grafana_session
RET=$?
if [ "${RET}" -ne "0" ]; then
  exit 1
fi

cd dashboards
./init-dashboard.sh --init=false

