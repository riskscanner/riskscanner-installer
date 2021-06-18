#!/bin/bash
#

function prepare_check() {
  isRoot=`id -u -n | grep root | wc -l`
  if [ "x$isRoot" != "x1" ]; then
      echo -e "[\033[31m ERROR \033[0m] Please use root to execute the installation script (请用 root 用户执行安装脚本)"
      exit 1
  fi
  processor=`cat /proc/cpuinfo| grep "processor"| wc -l`
  if [ $processor -lt 2 ]; then
      echo -e "[\033[31m ERROR \033[0m] The CPU is less than 2 cores (CPU 小于 2核，riskscanner 所在机器的 CPU 需要至少 2核)"
      exit 1
  fi
  memTotal=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
  if [ $memTotal -lt 7500000 ]; then
      echo -e "[\033[31m ERROR \033[0m] Memory less than 8G (内存小于 8G，riskscanner 所在机器的内存需要至少 8G)"
      exit 1
  fi
}

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
  echo "download install script to /opt/riskscanner-installe (开始下载安装脚本到 /opt/riskscanner-installe)"
  Version=$(curl -s 'https://api.github.com/repos/riskscanner/riskscanner/releases/latest' | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
  if [ ! "$Version" ]; then
    echo -e "[\033[31m ERROR \033[0m] Network Failed (请检查网络是否正常或尝试重新执行脚本)"
  fi
  cd /opt
  if [ ! -d "/opt/riskscanner-installer-$Version" ]; then
    wget -qO riskscanner-installer-$Version.tar.gz https://github.com/riskscanner/riskscanner-installer/releases/download/$Version/riskscanner-installer-$Version.tar.gz || {
      rm -rf /opt/riskscanner-installer-$Version.tar.gz
      echo -e "[\033[31m ERROR \033[0m] Failed to download riskscanner-installer (下载 riskscanner-installer 失败, 请检查网络是否正常或尝试重新执行脚本)"
      exit 1
    }
    tar -xf /opt/riskscanner-installer-$Version.tar.gz -C /opt || {
      rm -rf /opt/riskscanner-installer-$Version
      echo -e "[\033[31m ERROR \033[0m] Failed to unzip riskscanner-installe (解压 riskscanner-installer 失败, 请检查网络是否正常或尝试重新执行脚本)"
      exit 1
    }
    rm -rf /opt/riskscanner-installer-$Version.tar.gz
  fi
  cd /opt/riskscanner-installer-$Version
  ./rsctl.sh install
}

function main(){
  prepare_check
  prepare_install
  get_installer
}
main