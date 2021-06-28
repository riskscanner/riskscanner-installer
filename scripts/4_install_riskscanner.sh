#!/usr/bin/env bash
#

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=./util.sh
. "${BASE_DIR}/utils.sh"

function pre_install() {
  if ! command -v systemctl &>/dev/null; then
    command -v docker >/dev/null || {
      log_error "$(gettext 'The current Linux system does not support systemd management. Please deploy docker by yourself before running this script again')"
      exit 1
    }
    command -v docker-compose >/dev/null || {
      log_error "$(gettext 'The current Linux system does not support systemd management. Please deploy docker-compose by yourself before running this script again')"
      exit 1
    }
  fi
}

function post_install() {
  echo_green "\n>>> $(gettext 'The Installation is Complete')"
  HOST=$(ip addr | grep 'state UP' -A2 | grep inet | grep -Ev '(127.0.0.1|inet6|docker)' | awk '{print $2}' | tr -d "addr:" | head -n 1 | cut -d / -f1)
  if [ ! "$HOST" ]; then
      HOST=$(hostname -I | cut -d ' ' -f1)
  fi
  HTTP_PORT=$(get_config HTTP_PORT)

  echo_yellow "1. $(gettext 'You can use the following command to start, and then visit')"
  echo "./rsctl.sh start"

  echo_yellow "\n2. $(gettext 'Other management commands')"
  echo "./rsctl.sh stop"
  echo "./rsctl.sh restart"
  echo "./rsctl.sh backup"
  echo "./rsctl.sh upgrade"
  echo "$(gettext 'For more commands, you can enter ./rsctl.sh --help to understand')"

  echo_yellow "\n3. $(gettext 'Web access')"
  echo "http://${HOST}:${HTTP_PORT}"
  echo "$(gettext 'Default username'): admin  $(gettext 'Default password'): riskscanner"

  echo_yellow "\n4. $(gettext 'More information')"
  echo "$(gettext 'Offical Website'): https://www.riskscanner.io/"
  echo "$(gettext 'Documentation'): https://docs.riskscanner.io/"
  echo -e "\n\n"
}

function main() {
  echo_logo
  pre_install
  prepare_config
  set_current_version
  echo_green "\n>>> $(gettext 'Install and Configure Docker')"
  if ! bash "${BASE_DIR}/2_install_docker.sh"; then
    exit 1
  fi
  echo_green "\n>>> $(gettext 'Loading Docker Image')"
  if ! bash "${BASE_DIR}/3_load_images.sh"; then
    exit 1
  fi
  echo_green "\n>>> $(gettext 'Install and Configure RiskScanner')"
  if ! bash "${BASE_DIR}/1_config_riskscanner.sh"; then
    exit 1
  fi
  post_install
}

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  main
fi
