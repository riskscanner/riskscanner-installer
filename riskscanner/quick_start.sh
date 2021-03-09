#Install Latest Stable RiskScanner Release
os=$(uname -a)
# 支持MacOS
if [[ $os =~ 'Darwin' ]]; then
  echo 暂时不支持 MacOS 安装
  #VERSION=$(curl -s https://github.com/RiskScanner/riskscanner/releases/latest |grep -Eo 'v[0-9]+.[0-9]+.[0-9]+')
else
  VERSION=$(curl -s https://github.com/RiskScanner/riskscanner/releases/latest/download 2>&1 | grep -Po '[0-9]+\.[0-9]+\.[0-9]+.*(?=")')
fi

wget --no-check-certificate https://github.com/RiskScanner/riskscanner/releases/latest/download/riskscanner-release-${VERSION}-offline.tar.gz
#curl -s https://api.github.com/repos/RiskScanner/riskscanner/releases/latest | grep browser_download_url | grep online | cut -d '"' -f 4 | wget -qi -

tar zxvf riskscanner-release-${VERSION}-offline.tar.gz

cd riskscanner-release-${VERSION}-offline/installer

/bin/bash install.sh