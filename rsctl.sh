#!/bin/bash

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=scripts/utils.sh
. "${PROJECT_DIR}/scripts/utils.sh"

action=${1-}
target=${2-}
args=("$@")

function check_config_file() {
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "$(gettext 'Configuration file not found'): ${CONFIG_FILE}"
    echo "$(gettext 'Please install it first')"
    return 3
  fi
  if [[ ! -f .env ]]; then
    ln -s "${CONFIG_FILE}" .env
  fi
}

function pre_check() {
  check_config_file || return 3
}

function usage() {
  echo "RiskScanner $(gettext 'Deployment Management Script')"
  echo
  echo "Usage: "
  echo "  rsctl [COMMAND] [ARGS...]"
  echo "  rsctl --help"
  echo
  echo "Installation Commands: "
  echo "  status     $(gettext 'Status    RiskScanner')"
  echo "  upgrade    $(gettext 'Upgrade   RiskScanner')"
  echo "  reconfig   $(gettext 'Reconfig  RiskScanner')"
  echo
  echo "Management Commands: "
  echo "  start      $(gettext 'Start     RiskScanner')"
  echo "  stop       $(gettext 'Stop      RiskScanner')"
  echo "  down       $(gettext 'Down      RiskScanner')"
  echo "  restart    $(gettext 'Restart   RiskScanner')"
  echo "  uninstall  $(gettext 'Uninstall RiskScanner')"
  echo
  echo "More Commands: "
  echo "  version            $(gettext 'View RiskScanner version')"
  echo "  load_image         $(gettext 'Loading docker image')"
  echo "  backup_db          $(gettext 'Backup database')"
  echo "  restore_db [file]  $(gettext 'Data recovery through database backup file')"
  echo
}

function service_to_docker_name() {
  service=$1
  if [[ "${service:0:3}" != "rs" ]]; then
    service=rs_${service}
  fi
  echo "${service}"
}

EXE=""

function start() {
  ${EXE} up -d
}

function stop() {
  ${EXE} stop
}

function down() {
  ${EXE} down
}

function restart() {
  stop
  echo
  start
}

function check_update() {
  current_version="${VERSION}"
  latest_version=$(get_latest_version)
  if [[ "${current_version}" == "${latest_version}" ]]; then
    echo "$(gettext 'The current version is up to date')"
    return
  fi
  echo "$(gettext 'The latest version is'): ${latest_version}"
  echo "$(gettext 'The current version is'): ${current_version}"
  echo
}

function main() {
  if [[ "${action}" == "help" || "${action}" == "h" || "${action}" == "-h" || "${action}" == "--help" ]]; then
    echo ""
  elif [[ "${action}" == "install" || "${action}" == "reconfig" ]]; then
    echo ""
  else
    pre_check || return 3
    EXE=$(get_docker_compose_cmd_line)
  fi
  case "${action}" in
    install)
      bash "${SCRIPT_DIR}/4_install_riskscanner.sh"
      ;;
    upgrade)
      bash "${SCRIPT_DIR}/7_upgrade.sh" "$target"
      ;;
    check_update)
      check_update
      ;;
    reconfig)
      if [[ -f "${CONFIG_DIR}/rackhd/monorail/config.json" ]]; then
        mv ${CONFIG_DIR}/rackhd/monorail/config.json ${CONFIG_DIR}/rackhd/monorail/config.json.bak-$(date +%F_%T)
      fi
      if [[ -f "${config_dir}/riskscanner.properties" ]]; then
        mv ${config_dir}/riskscanner.properties ${config_dir}/riskscanner.properties.bak-$(date +%F_%T)
      fi
      bash "${SCRIPT_DIR}/1_config_riskscanner.sh"

      mysql_host=$(get_config DB_HOST)
      mysql_port=$(get_config DB_PORT)
      mysql_user=$(get_config DB_USER)
      mysql_pass=$(get_config DB_PASSWORD)
      mysql_db=$(get_config DB_NAME)
      riskscanner_ip=$(get_config RACKSHIFT_IP)
      command="update endpoint set ip='${riskscanner_ip}' where type='main_endpoint';"
      docker run -it --rm riskscanner/mysql:5.7.31 mysql -h${mysql_host} -P${mysql_port} -u${mysql_user} -p${mysql_pass} ${mysql_db} -e "${command}" 2>/dev/null
      if [ $? -eq 0 ]; then
        echo_yellow "\n$(gettext 'Reconfig successfully. You can now restart the program')"
        echo "./rsctl.sh restart"
        echo -e "\n\n"
      else
        log_error "$(gettext 'Reset failed, please try again or check whether the database is normal'). "
        exit 1
      fi
      ;;
    start)
      start
      ;;
    restart)
      restart
      ;;
    stop)
      stop
      ;;
    close)
      close
      ;;
    status)
      ${EXE} ps
      ;;
    down)
      if [[ -z "${target}" ]]; then
        ${EXE} down -v
      else
        ${EXE} stop "${target}" && ${EXE} rm -f "${target}"
      fi
      ;;
    uninstall)
      bash "${SCRIPT_DIR}/8_uninstall.sh"
      ;;
    backup_db)
      bash "${SCRIPT_DIR}/5_db_backup.sh"
      ;;
    restore_db)
      bash "${SCRIPT_DIR}/6_db_restore.sh" "$target"
      ;;
    load_image)
      bash "${SCRIPT_DIR}/3_load_images.sh"
      ;;
    cmd)
      echo "${EXE}"
      ;;
    tail)
      if [[ -z "${target}" ]]; then
        ${EXE} logs --tail 100 -f
      else
        docker_name=$(service_to_docker_name "${target}")
        docker logs -f "${docker_name}" --tail 100
      fi
      ;;
    raw)
      ${EXE} "${args[@]:1}"
      ;;
    help)
      usage
      ;;
    --help)
      usage
      ;;
    -h)
      usage
      ;;
    *)
      echo "No such command: ${action}"
      usage
      ;;
    esac
}

main "$@"
