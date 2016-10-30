#!/bin/bash
#
# Creates/updates dashboards for each container based on Docker-Container-Status template
#
# This is a modified version of https://github.com/Kentik/docker-monitor/blob/master/create-dashboards.sh
#
# Usage:
#
#   ./init-dashboard.sh
#

GRAFANA_URL='http://localhost:3000/'
GRAFANA_API_URL='http://localhost:3000/api/'
GRAFANA_LOGIN='admin'
GRAFANA_PASSWORD='foobar'

NEWLINE='
'
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function help {
  echo "Usage: init-dashboard.sh [options...]"
  echo "Options: (H) means HTTP/HTTPS only, (F) means FTP only"
  echo " -h, --help      Prints this content"
  echo " -i, --init      Initializes default Grafana dashboards (default: true)"
  echo " -e, --exclude   Excludes containers from 'Docker Container Status' dashboard"
  echo "                           (default: all environment containers are excluded)"
  echo "Examples:"
  echo "     ./init-dashboard.sh"
  echo "     ./init-dashboard.sh --init=false --exclude=\"prometheus_node-exporter_1,prometheus_alertmanager_1\"" 
}

INIT=true
EXCLUDES='prometheus,prometheus_cadvisor_1,prometheus_node-exporter_1,prometheus_alertmanager_1,prometheus_grafana_1'
EXCLUDES_ARRAY=()

function load_params {
  SHORT=hi:e:
  LONG=help,init:,exclude:

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
      -e|--exclude)
	      EXCLUDES="$2"
        shift 2
	      ;;
	    -i|--init)
        INIT=$2
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

echo "Excluded Containers: ${EXCLUDES}"

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

function ensure_grafana_dashboard {
  DASHBOARD_PATH=$1
  TEMP_DIR=$(mktemp -d)
  TEMP_FILE="${TEMP_DIR}/dashboard"

  # Need to wrap the dashboard json, and make sure the dashboard's "id" is null for insert
  echo '{"dashboard":' > $TEMP_FILE
  cat $DASHBOARD_PATH | sed -E 's/^"  id": [0-9]+,$/"  id": null,/' >> $TEMP_FILE
  echo ', "overwrite": true }' >> $TEMP_FILE

  curl --cookie "${COOKIEJAR}" \
       -X POST \
       --silent \
       -H 'Content-Type: application/json;charset=UTF-8' \
       --data "@${TEMP_FILE}" \
       "${GRAFANA_API_URL}dashboards/db" > /dev/null 2>&1
  unlink $TEMP_FILE
  rmdir $TEMP_DIR
}

function prepare_container_from_template {
  ID=$1
  CONTAINER=$2
  echo $(cat "Container.json.tmpl" \
    | sed -e "s|___ID___|$ID|g" \
    | sed -e "s|___CONTAINER___|$CONTAINER|g" \
    )
    
}

function setup_grafana_dashboard {
  if [[ $INIT == true ]]; then
    # Modified version of https://grafana.net/dashboards/179
    echo "Creating dashboard 'Docker Dashboard'"
    ensure_grafana_dashboard "Docker-Dashboard.json"
    RET=$?
    if [ "${RET}" -ne "0" ]; then
      echo "An error occurred"
      exit 1
    fi
    
    # Modified version of https://grafana.net/dashboards/395
    echo "Creating dashboard 'Docker Host & Container Overview'"
    ensure_grafana_dashboard "Docker-Host-And-Container-Overview.json"
    RET=$?
    if [ "${RET}" -ne "0" ]; then
      echo "An error occurred"
      exit 1
    fi
  fi
  
	echo "Creating dashboard 'Docker Container Status' with the following containers:"
  PANELS=""
  NAMES=""
  ID=0
  IFS=$NEWLINE
  for x in `docker ps`; do
    CONTAINER_ID=`echo $x | awk '{print $1}'`
    CONTAINER=`echo $x | awk 'END {print $NF}'`

    # Skip the header
    if [ "${CONTAINER_ID}" = "CONTAINER" ]; then
      continue
    fi
    
    if [[ " ${EXCLUDES_ARRAY[@]} " =~ " ${CONTAINER} " ]]; then
      continue
    fi
    
    ID=$[$ID + 1]
    
    echo " - ${CONTAINER}"
    if [ -n "$PANELS" ]; then
      PANELS=$PANELS","$NEWLINE
      NAMES=$NAMES"|"
    fi
    PANELS=$PANELS$(prepare_container_from_template ${ID} ${CONTAINER})
    NAMES=$NAMES$CONTAINER
  done
  
  TEMP_DIR=$(mktemp -d)
  echo "$PANELS" > "${TEMP_DIR}/panels"
  cp Docker-Container-Status.json.tmpl "${TEMP_DIR}/dashboard.tmpl"
  cd ${TEMP_DIR}
  sed -i "s/___NAMES___/$NAMES/g" dashboard.tmpl
  csplit -s dashboard.tmpl '/___PANELS___/'
  sed -i "s|___PANELS___||g" xx01
  cat xx00 panels xx01 > dashboard
  
	ensure_grafana_dashboard "${TEMP_DIR}/dashboard"
  RET=$?
  rm -rf $TEMP_DIR
  if [ "${RET}" -ne "0" ]; then
    echo "An error occurred"
    exit 1
  fi
  
  echo "Done"
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
  
setup_grafana_dashboard

