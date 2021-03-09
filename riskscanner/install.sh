#!/bin/bash
CURRENT_DIR=$(
   cd "$(dirname "$0")"
   pwd
)
os=`uname -a`
function log() {
   message="[RiskScanner Log]: $1 "
   echo -e "${message}" 2>&1 | tee -a ${CURRENT_DIR}/install.log
}

args=$@

docker_config_folder="/etc/docker"

compose_files="-f docker-compose-core.yml"

if [ -f /usr/local/bin/rsctl ]; then
   RS_BASE=`grep "^RS_BASE=" /usr/local/bin/rsctl | cut -d'=' -f2`
fi

set -a
if [[ $RS_BASE ]] && [[ -f $RS_BASE/riskscanner/.env ]]; then
   source $RS_BASE/riskscanner/.env
   RS_TAG=`grep "^RS_TAG=" install.conf | cut -d'=' -f2`
else
   if [[ $os =~ 'Darwin' ]];then
      sed -i -e "s#RS_BASE=.*#RS_BASE=~#g" ${CURRENT_DIR}/install.conf
   fi
   source ${CURRENT_DIR}/install.conf
fi
set +a

RS_RUN_BASE=${RS_BASE}/riskscanner
mkdir -p ${RS_RUN_BASE}
cp -r ./riskscanner ${RS_BASE}/


conf_folder=${RS_RUN_BASE}/conf
mkdir -p $conf_folder
templates_folder=${RS_RUN_BASE}/templates
cp -r $templates_folder/* $conf_folder
cd $templates_folder

conf_template_files=( riskscanner.properties )
for i in ${conf_template_files[@]}; do
   if [ -f $i ]; then
      envsubst < $i > $conf_folder/$i
   fi
done
envsubst < ${CURRENT_DIR}/riskscanner/bin/mysql/init.sql > ${RS_RUN_BASE}/bin/mysql/init.sql

cd ${CURRENT_DIR}
sed -i -e "s#RS_BASE=.*#RS_BASE=${RS_BASE}#g" rsctl
cp rsctl /usr/local/bin && chmod +x /usr/local/bin/rsctl
ln -s /usr/local/bin/rsctl /usr/bin/rsctl 2>/dev/null


echo -e "======================= 开始安装 =======================" 2>&1 | tee -a ${CURRENT_DIR}/install.log

echo "time: $(date)"

#Install docker & docker-compose
##Install Latest Stable Docker Release
if which docker >/dev/null; then
   log "检测到 Docker 已安装，跳过安装步骤"
   log "启动 Docker "
   service docker start 2>&1 | tee -a ${CURRENT_DIR}/install.log
else
   if [[ -d docker ]]; then
      log "... 离线安装 docker"
      cp docker/bin/* /usr/bin/
      cp docker/service/docker.service /etc/systemd/system/
      chmod +x /usr/bin/docker*
      chmod 754 /etc/systemd/system/docker.service
      log "... 启动 docker"
      service docker start 2>&1 | tee -a ${CURRENT_DIR}/install.log

   else
      log "... 在线安装 docker"
      curl -fsSL https://get.docker.com -o get-docker.sh 2>&1 | tee -a ${CURRENT_DIR}/install.log
      sudo sh get-docker.sh 2>&1 | tee -a ${CURRENT_DIR}/install.log
      log "... 启动 docker"
      service docker start 2>&1 | tee -a ${CURRENT_DIR}/install.log
   fi

   if [ ! -d "$docker_config_folder" ];then
      mkdir -p "$docker_config_folder"
   fi

EOF
      service docker restart 2>&1 | tee -a ${CURRENT_DIR}/install.log
   fi



##Install Latest Stable Docker Compose Release
if which docker-compose >/dev/null; then
   log "检测到 Docker Compose 已安装，跳过安装步骤"
else
   if [[ -d docker ]]; then
      log "... 离线安装 docker-compose"
      cp docker/bin/docker-compose /usr/bin/
      chmod +x /usr/bin/docker-compose
   else
      log "... 在线安装 docker-compose"
      COMPOSEVERSION=$(curl -s https://github.com/docker/compose/releases/latest/download 2>&1 | grep -Po [0-9]+\.[0-9]+\.[0-9]+)
      curl -L "https://github.com/docker/compose/releases/download/$COMPOSEVERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose 2>&1 | tee -a ${CURRENT_DIR}/install.log
      chmod +x /usr/local/bin/docker-compose
      ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
   fi
fi

cd ${RS_RUN_BASE}
env | grep RS_ >.env


if [ ${RS_EXTERNAL_MYSQL} = "false" ]; then
   mkdir -p ${RS_RUN_BASE}/data/mysql
   compose_files="${compose_files} -f docker-compose-mysql.yml"
   sed -i -e "s#\${RS_MYSQL_DB}#${RS_MYSQL_DB}#g" ${RS_RUN_BASE}/bin/mysql/init.sql
else
   sed -i -e "/#RS_EXTERNAL_MYSQL=false/{N;N;N;d;}" ${RS_RUN_BASE}/docker-compose*
fi

export COMPOSE_HTTP_TIMEOUT=180
cd ${CURRENT_DIR}
# 加载镜像
if [[ -d images ]]; then
   log "加载镜像"
   for i in $(ls images); do
      docker load -i images/$i 2>&1 | tee -a ${CURRENT_DIR}/install.log
   done
else
   log "拉取镜像"
   cd ${RS_RUN_BASE}
   docker-compose $compose_files pull 2>&1 | tee -a ${CURRENT_DIR}/install.log
   cd -
fi

log "配置 RiskScanner Service"
\cp ${RS_RUN_BASE}/bin/riskscanner/riskscanner.service /etc/init.d/riskscanner
chmod a+x /etc/init.d/riskscanner
chkconfig --add riskscanner
riskscannerService=`grep "service riskscanner start" /etc/rc.d/rc.local | wc -l`
if [ "$riskscannerService" -eq 0 ]; then
   echo "sleep 10" >> /etc/rc.d/rc.local
   echo "service riskscanner start" >> /etc/rc.d/rc.local
fi
chmod +x /etc/rc.d/rc.local
if [ `grep "vm.max_map_count" /etc/sysctl.conf | wc -l` -eq 0 ];then
   sysctl -w vm.max_map_count=262144
   echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fi

if [ `grep "net.ipv4.ip_forward" /etc/sysctl.conf | wc -l` -eq 0 ];then
   sysctl -w net.ipv4.ip_forward=1
   echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
else
   sed -i '/net.ipv4.ip_forward/ s/\(.*= \).*/\11/' /etc/sysctl.conf
fi



log "启动服务"
cd ${RS_RUN_BASE} && docker-compose $compose_files up -d 2>&1 | tee -a ${CURRENT_DIR}/install.log

rsctl status 2>&1 | tee -a ${CURRENT_DIR}/install.log

echo -e "======================= 安装完成 =======================\n" 2>&1 | tee -a ${CURRENT_DIR}/install.log

echo -e "请通过以下方式访问:\n URL: http://\$LOCAL_IP:${RS_PORT}\n 用户名: admin\n 初始密码: riskscanner" 2>&1 | tee -a ${CURRENT_DIR}/install.log
echo -e "您可以使用命令 'rsctl status' 检查服务运行情况.\n" 2>&1 | tee -a ${CURRENT_DIR}/install.log-a ${CURRENT_DIR}/install.log
