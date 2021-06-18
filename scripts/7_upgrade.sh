#!/usr/bin/env bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=./util.sh
. "${BASE_DIR}/utils.sh"
# shellcheck source=./2_install_docker.sh
. "${BASE_DIR}/2_install_docker.sh"

target=$1

function upgrade_config() {
  # 如果配置文件有更新, 则添加到新的配置文件
  cwd=$(pwd)
  cd "${PROJECT_DIR}" || exit

  volume_dir=$(get_config VOLUME_DIR)
  cp -rf config_init/conf/version ${volume_dir}/conf/version

  current_version=$(get_config CURRENT_VERSION)
  if [ -z "${current_version}" ]; then
    set_config CURRENT_VERSION "${VERSION}"
  fi
}

function update_config_if_need() {
  upgrade_config
}

function backup_db() {
  docker_network_check
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

function main() {
  confirm="n"
  to_version="${VERSION}"
  if [[ -n "${target}" ]]; then
    to_version="${target}"
  fi

  read_from_input confirm "$(gettext 'Are you sure you want to update the current version to') ${to_version} ?" "y/n" "${confirm}"
  if [[ "${confirm}" != "y" || -z "${to_version}" ]]; then
    exit 3
  fi

  if [[ "${to_version}" && "${to_version}" != "${VERSION}" ]]; then
    sed -i "s@VERSION=.*@VERSION=${to_version}@g" "${PROJECT_DIR}/static.env"
    export VERSION=${to_version}
  fi
  echo
  update_config_if_need && echo_done || (echo_failed; exit  1)

  echo_yellow "\n1. $(gettext 'Upgrade Docker image')"
  bash "${SCRIPT_DIR}/3_load_images.sh" && echo_done || (echo_failed; exit  1)

  echo_yellow "\n2. $(gettext 'Backup database')"
  backup_db || exit 1

  echo_yellow "\n3. $(gettext 'Upgrade successfully. You can now restart the program')"
  echo "./rsctl.sh restart"
  echo -e "\n\n"
  set_current_version
}

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  main
fi
