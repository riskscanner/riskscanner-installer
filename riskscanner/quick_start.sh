#Install Latest Stable RiskScanner Release
os=$(uname -a)

if [[ $os =~ 'Darwin' ]]; then
  echo 暂时不支持 MacOS 安装
else
  VERSION=$(curl -s https://github.com/riskscanner/riskscanner/releases/latest/download 2>&1 | grep -Po '[0-9]+\.[0-9]+\.[0-9]+.*(?=")' | tr -d 'a-zA-Z')
fi

if [ -z "$VERSION" ]; then
  echo Please check your network,github is unreachable!
  exit
fi

if [ ! -f ./riskscanner-release-${VERSION}.tar.gz ]; then
      wget --no-check-certificate https://github.com/riskscanner/riskscanner/releases/latest/download/riskscanner-release-${VERSION}.tar.gz
fi

if [ ! -f ./riskscanner-release-${VERSION} ]; then
      tar zxvf riskscanner-release-${VERSION}.tar.gz
fi
cd riskscanner-release-${VERSION}

/bin/bash ./install.sh
