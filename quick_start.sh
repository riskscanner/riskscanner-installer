#!/bin/bash
#

Version=dev

function install_soft() {
    if command -v dnf > /dev/null; then
      if [ "$1" == "python" ]; then
        dnf -q -y install python2
        ln -s /usr/bin/python2 /usr/bin/python
      else
        dnf -q -y install $1
      fi
    elif command -v yum > /dev/null; then
      yum -q -y install $1
    elif command -v apt > /dev/null; then
      apt-get -qqy install $1
    elif command -v zypper > /dev/null; then
      zypper -q -n install $1
    elif command -v apk > /dev/null; then
      apk add -q $1
    else
      echo -e "[\033[31m ERROR \033[0m] Please install it first (请先安装) $1 "
      exit 1
    fi
}

function prepare_install() {
  for i in curl wget zip python; do
    command -v $i &>/dev/null || install_soft $i
  done
}

function get_installer() {
  echo "download install script to /opt/riskscanner-installer-${Version} (开始下载安装脚本到 /opt/riskscanner-installer-${Version})"
  cd /opt || exit
  if [ ! -d "/opt/riskscanner-installer-${Version}" ]; then
    timeout 60s wget -qO riskscanner-installer-${Version}.tar.gz https://github.com/riskscanner/riskscanner-installer/releases/download/${Version}/riskscanner-installer-${Version}.tar.gz || {
      rm -rf /opt/riskscanner-installer-${Version}.tar.gz
      echo -e "[\033[31m ERROR \033[0m] Failed to download riskscanner-installer-${Version} (下载 riskscanner-installer-${Version} 失败, 请检查网络是否正常或尝试重新执行脚本)"
      exit 1
    }
    tar -xf /opt/riskscanner-installer-${Version}.tar.gz -C /opt || {
      rm -rf /opt/riskscanner-installer-${Version}
      echo -e "[\033[31m ERROR \033[0m] Failed to unzip riskscanner-installer-${Version} (解压 riskscanner-installer-${Version} 失败, 请检查网络是否正常或尝试重新执行脚本)"
      exit 1
    }
    rm -rf /opt/riskscanner-installer-${Version}.tar.gz
  fi
}

function config_installer() {
  cd /opt/riskscanner-installer-${Version} || exit 1
  sed -i "s/VERSION=.*/VERSION=${Version}/g" /opt/riskscanner-installer-${Version}/static.env
  ./rsctl.sh install
  ./rsctl.sh start
}

function main(){
  prepare_install
  get_installer
  config_installer
}
main
