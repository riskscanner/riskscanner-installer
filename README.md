# RiskScanner 安装管理包

installer 可以安装、部署、更新 管理 RiskScanner

## 安装部署

```bash
cd riskscanner-installer

# 安装，版本是在 static.env 指定的
./rsctl.sh install

# 检查更新
./rsctl.sh check_update

# 升级到 static.env 中的版本
./rsctl.sh upgrade

# 升级到指定版本
./rsctl.sh upgrade v1.2.1
```

## 离线安装
```bash
# 生成离线包
$ cd scripts && bash 0_prepare.sh

# 完成以后将这个包压缩，复制到想安装的机器，直接安装即可
$ ./rsctl.sh install
```

## 管理命令

```bash
# 启动
./rsctl.sh start

# 停止
./rsctl.sh stop

# 重启
./rsctl.sh restart

# 升级
./rsctl.sh upgrade

# 卸载
./rsctl.sh uninstall

# 帮助
./rsctl.sh --help
```

## 配置文件说明

配置文件将会放在 /opt/riskscanner/config 中

```
[root@riskscanner riskscanner]# tree .
├── conf
│   ├── mysql                      
│   │   ├── mysql.cnf               # mysql 配置文件
│   │   └── sql
│   │       └── riskscanner.sql     # mysql 初始化数据库脚本
│   ├── riskscanner.properties      # riskscanner 配置文件
│   └── version                     # 版本文件
└── config
    └── config.txt                  # 主配置文件

4 directories, 5 files
```

### config.txt 说明

config.txt 文件是环境变量式配置文件，会挂在到各个容器中

config-example.txt 有说明，可以参考
