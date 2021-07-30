#!/usr/bin/env bash
#
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

. "${BASE_DIR}/utils.sh"

target=$1

function upgrade_config() {
  volume_dir=$(get_config VOLUME_DIR)
  \cp -rf config_init/conf/version "${volume_dir}/conf/version"

  current_version=$(get_config CURRENT_VERSION)
  if [ -z "${current_version}" ]; then
    set_config CURRENT_VERSION "${VERSION}"
  fi

  if [[ "${SHELL}" == "/bin/bash" ]]; then
    if grep -q "alias rsctl=" ~/.bashrc; then
      sed -i 's@alias rsctl=.*@@g' ~/.bashrc
      unalias rsctl
      . ~/.bashrc
    fi
  fi
}

function update_config_if_need() {
  prepare_config
  upgrade_config
}

function backup_db() {
  docker_network_check
  if docker ps | grep rs_scanner >/dev/null; then
      docker stop rs_scanner
      docker rm rs_scanner
      sleep 2s
      echo
  fi
  if [[ "${SKIP_BACKUP_DB}" != "1" ]]; then
    if ! bash "${SCRIPT_DIR}/5_db_backup.sh"; then
      confirm="n"
      read_from_input confirm "$(gettext 'Failed to backup the database. Continue to upgrade')?" "y/n" "${confirm}"
      if [[ "${confirm}" == "n" ]]; then
        exit 1
      fi
    fi
  else
    echo "SKIP_BACKUP_DB=${SKIP_BACKUP_DB}, $(gettext 'Skip database backup')"
  fi
}

function clear_images() {
  current_version=$(get_config CURRENT_VERSION)
  if [[ "${current_version}" != "${to_version}" ]]; then
    confirm="n"
    docker images | grep x-lab/ | grep "${current_version}" | awk '{print $3}' | xargs docker rmi -f
  fi
  echo_done
}

function main() {
  confirm="n"
  to_version="${VERSION}"
  if [[ -n "${target}" ]]; then
    to_version="${target}"
  fi
  if [[ "${to_version}" && "${to_version}" != "${VERSION}" ]]; then
    sed -i "s@VERSION=.*@VERSION=${to_version}@g" "${PROJECT_DIR}/static.env"
    export VERSION=${to_version}
  fi
  echo
  update_config_if_need

  echo_yellow "\n3. $(gettext 'Upgrade Docker image')"
  bash "${SCRIPT_DIR}/3_load_images.sh"

  echo_yellow "\n4. $(gettext 'Backup database')"
  backup_db

  echo_yellow "\n5. $(gettext 'Cleanup Image')"
  clear_images

  echo_yellow "\n6. $(gettext 'Upgrade successfully. You can now restart the program')"
  echo "cd ${PROJECT_DIR}"
  echo "./rsctl.sh start"
  set_current_version

  cd ${PROJECT_DIR} || exit 1
  ./rsctl.sh start
}

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  main
fi
