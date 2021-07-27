#!/usr/bin/env bash
#
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

. "${BASE_DIR}/utils.sh"

function set_volume_dir() {
  echo_yellow "1. $(gettext 'Configure Persistent Directory')"
  volume_dir=$(get_config VOLUME_DIR "/opt/riskscanner")
  confirm="n"
  read_from_input confirm "$(gettext 'Do you need custom persistent store, will use the default directory') ${volume_dir}?" "y/n" "${confirm}"
  if [[ "${confirm}" == "y" ]]; then
    echo
    echo "$(gettext 'To modify the persistent directory such as logs video, you can select your largest disk and create a directory in it, such as') /opt/riskscanner"
    echo "$(gettext 'Note: you can not change it after installation, otherwise the database may be lost')"
    echo
    df -h | grep -Ev "map|devfs|tmpfs|overlay|shm"
    echo
    read_from_input volume_dir "$(gettext 'Persistent storage directory')" "" "${volume_dir}"
    if [[ "${volume_dir}" == "y" ]]; then
      echo_failed
      echo
      set_volume_dir
    fi
  fi
  if [[ ! -d "${volume_dir}" ]]; then
    mkdir -p ${volume_dir}
    cp -R "${PROJECT_DIR}/config_init/conf" ${volume_dir}
  fi
  set_config VOLUME_DIR ${volume_dir}
  if [[ ! -d "${volume_dir}/conf" ]]; then
    cp -R "${PROJECT_DIR}/config_init/conf" ${volume_dir}
  fi
  if [[ ! -d "${volume_dir}/conf/mysql/sql" ]]; then
    mkdir -p "${volume_dir}/conf/mysql/sql"
  fi
  if [[ ! -f "${volume_dir}/conf/mysql/mysql.cnf" ]]; then
    cp "${PROJECT_DIR}/config_init/mysql/mysql.cnf" "${volume_dir}/conf/mysql"
  fi
  if [[ ! -f "${volume_dir}/conf/mysql/sql" ]]; then
    cp "${PROJECT_DIR}/config_init/mysql/riskscanner.sql" "${volume_dir}/conf/mysql/sql"
  fi
  chmod 644 -R "${volume_dir}/conf"
  echo_done
}

function set_external_mysql() {
  mysql_host=$(get_config DB_HOST)
  read_from_input mysql_host "$(gettext 'Please enter MySQL server IP')" "" "${mysql_host}"
  if [[ "${mysql_host}" == "127.0.0.1" || "${mysql_host}" == "localhost" ]]; then
    mysql_host=$(hostname -I | cut -d ' ' -f1)
  fi

  mysql_port=$(get_config DB_PORT)
  read_from_input mysql_port "$(gettext 'Please enter MySQL server port')" "" "${mysql_port}"

  mysql_db=$(get_config DB_NAME)
  read_from_input mysql_db "$(gettext 'Please enter MySQL database name')" "" "${mysql_db}"

  mysql_user=$(get_config DB_USER)
  read_from_input mysql_user "$(gettext 'Please enter MySQL username')" "" "${mysql_user}"

  mysql_pass=$(get_config DB_PASSWORD)
  read_from_input mysql_pass "$(gettext 'Please enter MySQL password')" "" "${mysql_pass}"

  if ! test_mysql_connect "${mysql_host}" "${mysql_port}" "${mysql_user}" "${mysql_pass}" "${mysql_db}"; then
    echo_red "$(gettext 'Failed to connect to database, please reset')"
    echo
    set_mysql
  fi

  set_config DB_HOST "${mysql_host}"
  set_config DB_PORT "${mysql_port}"
  set_config DB_USER "${mysql_user}"
  set_config DB_PASSWORD "${mysql_pass}"
  set_config DB_NAME "${mysql_db}"
  set_config USE_EXTERNAL_MYSQL 1

  volume_dir=$(get_config VOLUME_DIR)
  sed -i "s@jdbc:mysql://mysql:3306@jdbc:mysql://${mysql_host}:${mysql_port}@g" "${volume_dir}/conf/riskscanner.properties"
  sed -i "s@spring.datasource.username=.*@spring.datasource.username=${mysql_user}@g" "${volume_dir}/conf/riskscanner.properties"
  sed -i "s@spring.datasource.password=.*@spring.datasource.password=${mysql_pass}@g" "${volume_dir}/conf/riskscanner.properties"
}

function set_internal_mysql() {
  set_config USE_EXTERNAL_MYSQL 0
  password=$(get_config DB_PASSWORD)
  if [[ -z "${password}" ]]; then
    DB_PASSWORD=$(random_str 26)
    set_config DB_PASSWORD "${DB_PASSWORD}"
    volume_dir=$(get_config VOLUME_DIR)
    sed -i "s@spring.datasource.password=.*@spring.datasource.password=${DB_PASSWORD}@g" "${volume_dir}/conf/riskscanner.properties"
  else
    sed -i "s@spring.datasource.password=.*@spring.datasource.password=${password}@g" "${volume_dir}/conf/riskscanner.properties"
  fi
}

function set_mysql() {
  echo_yellow "\n2. $(gettext 'Configure MySQL')"
  use_external_mysql=$(get_config USE_EXTERNAL_MYSQL)
  confirm="n"
  if [[ "${use_external_mysql}" == "1" ]]; then
    confirm="y"
  fi
  read_from_input confirm "$(gettext 'Do you want to use external MySQL')?" "y/n" "${confirm}"

  if [[ "${confirm}" == "y" ]]; then
    set_external_mysql
  else
    set_internal_mysql
  fi
  echo_done
}

function set_service_port() {
  echo_yellow "\n3. $(gettext 'Configure External Port')"
  http_port=$(get_config HTTP_PORT)
  confirm="n"
  read_from_input confirm "$(gettext 'Do you need to customize the RiskScanner external port')?" "y/n" "${confirm}"
  if [[ "${confirm}" == "y" ]]; then
    read_from_input http_port "$(gettext 'RiskScanner web port')" "" "${http_port}"
    set_config HTTP_PORT "${http_port}"
  fi
  echo_done
}

function init_db() {
  use_external_mysql=$(get_config USE_EXTERNAL_MYSQL)
  if [[ "${use_external_mysql}" == "1" ]]; then
    echo_yellow "\n4. $(gettext 'Init External MySQL')"
    volume_dir=$(get_config VOLUME_DIR)
    docker_network_check
    bash "${BASE_DIR}/6_db_restore.sh" "${volume_dir}/conf/mysql/sql/riskscanner.sql" || {
      echo_failed
      exit 1
    }
    echo_done
  fi
}

function main() {
  set_volume_dir
  set_mysql
  set_service_port
  init_db
}

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
  main
fi
