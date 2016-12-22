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
PROMETHEUS_URL='http://localhost:9090'

NEWLINE='
'
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function help {
  echo "Usage: init-environment.sh [options...]"
  echo "Options: (H) means HTTP/HTTPS only, (F) means FTP only"
  echo " -h, --help             Prints this content"
  echo " -p, --prometheus-url   Defines Prometheus datasource url"
  echo " -i, --init-dashboard   Initializes Grafana dashboards (default: true)"
  echo "Examples:"
  echo "     ./init-environment.sh"
  echo "     ./init-environment.sh --init-dashboard=true --prometheus-url=\"http://localhost:9090\""
}

INIT_DASHBOARD=true

function load_params {
  SHORT=hi:,p:
  LONG=help,init-dashboard:,prometheus-url:

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
	    -p|--prometheus-url)
        PROMETHEUS_URL=$2
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
  info "Creating datasource"
  POST_DATA='{"name":"Prometheus","type":"prometheus","url":"'$PROMETHEUS_URL'","access":"direct","isDefault":true}'
  curl --cookie "${COOKIEJAR}" \
       -X POST \
       --silent \
       -H "Content-Type: application/json; charset=utf-8" \
       --data-binary $POST_DATA \
       "${GRAFANA_API_URL}datasources" > /dev/null 2>&1
}

function success {
  echo "$(tput setaf 2)""$*""$(tput sgr0)"
}

function info {
  echo "$(tput bold)""$*""$(tput sgr0)"
}

function error {
  echo "$(tput setaf 1)""$*""$(tput sgr0)" 1>&2
}

function wait_for_grafana {
  docker-compose logs -f | while read LOGLINE
  do
    [[ "${LOGLINE}" == *"grafana"*"Server Listening"*"address="*":3000"* ]] && pkill -P $$ docker-compose && break
    [[ "${LOGLINE}" == *"Initializing HTTP Server"*"address="*":3000"* ]] && pkill -P $$ docker-compose && break
  done
}

info "Starting environment"
docker-compose up -d

info "Waiting for startup completion. Be patient, some things take time ;)"
wait_for_grafana

setup_grafana_session
RET=$?
if [ "${RET}" -ne "0" ]; then
  exit 1
fi

setup_grafana_datasource

if [[ $INIT_DASHBOARD == true ]]; then
  dashboards/init-dashboard.sh --init=true
else
  success "Done"
fi

