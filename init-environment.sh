#!/bin/bash
#
# Initializes environment for easy startup
#
# Usage:
#
#   ./init-environment.sh
#

GRAFANA_URL='http://localhost:3000/'
GRAFANA_API_URL='http://localhost:3000/api/'
GRAFANA_LOGIN='admin'
GRAFANA_PASSWORD='foobar'

NEWLINE='
'
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function help {
  echo "Usage: init-environment.sh [options...]"
  echo "Options: (H) means HTTP/HTTPS only, (F) means FTP only"
  echo " -h, --help             Prints this content"
  echo " -i, --init-dashboard   Initializes Grafana dashboards (default: true)"
  echo "Examples:"
  echo "     ./init-environment.sh"
  echo "     ./init-environment.sh --init-dashboard=true"
}

INIT_DASHBOARD=true

function load_params {
  SHORT=hi:
  LONG=help,init-dashboard:

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
	    -i|--init-dashboard)
        INIT_DASHBOARD=$2
        shift 2
        ;;
      --)
        shift
        break
        ;;
    esac
  done
}

load_params $@

IFS=$','
EXCLUDES_ARRAY=(${EXCLUDES})
unset IFS

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

function setup_grafana_datasource {
  echo "Creating datasource"
  curl --cookie "${COOKIEJAR}" \
       -X POST \
       --silent \
       -H "Content-Type: application/json; charset=utf-8" \
       --data-binary '{"name":"Prometheus","type":"prometheus","url":"http://localhost:9090","access":"direct","isDefault":true}' \
       "${GRAFANA_API_URL}datasources" > /dev/null 2>&1
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

echo "Starting environment"
docker-compose up -d
echo "Waiting for startup completion"
sleep 20

setup_grafana_session
RET=$?
if [ "${RET}" -ne "0" ]; then
  exit 1
fi

setup_grafana_datasource

if [[ $INIT_DASHBOARD == true ]]; then
  cd dashboards
  ./init-dashboard.sh --init=true
fi

