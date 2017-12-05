#!/bin/bash

#====================================================
#	System Request:Debian 7+/Ubuntu 14.04+/Centos 6+
#	Author:	wulabing
#	Dscription: V2ray ws+tls onekey 
#	Version: 1.0
#	Blog: https://www.wulabing.com
#	Official document: www.v2ray.com
#====================================================

#fonts color
Green="\033[32m" 
Red="\033[31m" 
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#notification information
Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"
Notification="${Yellow}[注意]${Font}"

v2ray_conf_dir="/etc/v2ray"
nginx_conf_dir="/etc/nginx/conf.d"
v2ray_conf="${v2ray_conf_dir}/config.json"
nginx_conf="${nginx_conf_dir}/v2ray.conf"
is_root(){
    if [ `id -u` -eq 0 ]
        then echo -e "${OK} ${GreenBG} 当前用户是root用户，进入安装流程 ${Font} "
    else
        echo -e "${Error} ${RedBG} 当前用户不是root用户，请切换到root用户后重新执行脚本 ${Font}" 
        exit 1
    fi
}
time_modify(){
    apt-get install ntpdate -y

    if [[ $? -ne 0 ]];then
        echo -e "${Error} ${RedBG} ntpdate 时间同步服务安装失败，请根据错误提示进行修复 ${Font}"
        exit 2
    else
        echo -e "${OK} ntpdate 时间同步服务安装成功"
    fi

    service ntp stop

    echo -e "${Info} 正在进行时间同步"
    ntpdate time.nist.gov

    if [[ $? -eq 0 ]];then 
        echo -e "${OK} ${GreenBG} 时间同步成功 ${Font}"
        echo -e "${OK} ${GreenBG} 当前系统时间 `date -R`（请注意时区间时间换算，换算后时间误差应为三分钟以内）${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} 时间同步失败，请检查ntpdate服务是否正常工作 ${Font}"
    fi 
}
dependency_install(){
    apt-get update
    apt-get install wget curl -y
    apt-get install bc
    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} bc 安装完成 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} bc 安装失败 ${Font}"
        exit 1
    fi
}
modify_port_UUID(){
    let PORT=$RANDOM+10000
    UUID=$(cat /proc/sys/kernel/random/uuid)
    sed -i "/\"port\"/c  \    \"port\":${PORT}," ${v2ray_conf}
    sed -i "/\"id\"/c \\\t  \"id\":\"${UUID}\"," ${v2ray_conf}
}
modify_nginx(){
    sed -i "/server_name/c \\\tserver_name ${domain};" ${nginx_conf}
    sed -i "/proxy_pass/c \\\tproxy_pass http://127.0.0.1:${PORT};" ${nginx_conf}
}
v2ray_install(){
    if [[ -d /root/v2ray ]];then
        rm -rf /root/v2ray
    fi

    mkdir -p /root/v2ray && cd /root/v2ray
    wget https://install.direct/go.sh

    if [[ -f go.sh ]];then
        source go.sh --force 
        if [[ $? -eq 0 ]];then
            echo -e "${OK} ${GreenBG} V2ray 安装成功 ${Font}"
            echo -e "${Green} Port: ${PORT} ${Font}"
            echo -e "${Grenn} UUID: ${UUID} ${Font}"
        else 
            echo -e "${Error} ${RedBG} V2ray 安装失败，请检查相关依赖是否正确安装 ${Font}"
            exit 3
        fi
    else
        echo -e "${OK} ${GreenBG} V2ray 安装文件下载失败，请检查下载地址是否可用 ${Font}"
        exit 4
    fi
}
nginx_install(){
    apt-get install nginx -y
    if [[ -d /etc/nginx ]];then
        echo -e "${OK} ${GreenBG} nginx 安装完成 ${Font}"
    else
        echo -e "${Error} ${RedBG} nginx 安装失败 ${Font}"
        exit 5
    fi
}
ssl_install(){
   
    apt-get install socat netcat -y

    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} SSL 证书生成脚本依赖安装成功 ${Font}"
    else
        echo -e "${Error} ${RedBG} SSL 证书生成脚本依赖安装失败 ${Font}"
        exit 6
    fi
    curl  https://get.acme.sh | sh

    if [[ $? -eq 0 ]];then
            echo -e "${OK} ${GreenBG} SSL 证书生成脚本安装成功 ${Font}"
    else
        echo -e "${Error} ${RedBG} SSL 证书生成脚本安装失败，请检查相关依赖是否正常安装 ${Font}"
        exit 7
    fi

}
domain_check(){
    stty erase '^H' && read -p "请输入你的域名信息(eg:www.wulabing.com):" domain
    domain_ip=`ping ${domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_ip=`ifconfig eth0 | grep 'inet ' | sed s/^.*addr://g | sed s/Bcast.*$//g`
    echo -e "域名dns解析IP：${domain_ip}"
    echo -e "本机IP: ${local_ip}"
    sleep 2
    if [[ $(echo ${local_ip}|tr '.' '+'|bc) -eq $(echo ${domain_ip}|tr '.' '+'|bc) ]];then
        echo -e "${OK} ${GreenBG} 域名dns解析IP  与 本机IP 匹配 ${Font}"
    else
        echo -e "${Error} ${RedBG} 域名dns解析IP 与 本机IP 不匹配 安装终止 ${Font}"
        exit 1
    fi
}
port_exist_check(){
    if [[ 0 -eq `netstat -tlpn | grep "$1"| wc -l` ]];then
        echo -e "${OK} ${GreenBG} $1 端口未被占用 ${Font}"
    else
        echo -e "${Error} ${RedBG} $1 端口被占用，请检查占用进程 结束后重新运行脚本 ${Font}"
        netstat -tlpn | grep "$1"
        exit 1
    fi
}
acme(){
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256
    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} SSL 证书生成成功 ${Font}"
        ~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
        if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} 证书配置成功 ${Font}"
        fi
    else
        echo -e "${Error} ${RedBG} SSL 证书生成失败 ${Font}"
        exit 1
    fi
}
v2ray_conf_add(){
    cat>${v2ray_conf_dir}/config.json<<EOF
{
  "inbound": {
    "port": 10000,
    "listen":"127.0.0.1",
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "b831381d-6324-4d53-ad4f-8cda48b30811",
          "alterId": 64
        }
      ]
    },
    "streamSettings":{
      "network":"ws",
      "wsSettings": {
      "path": "/ray"
      }
    }
  },
  "outbound": {
    "protocol": "freedom",
    "settings": {}
  }
}
EOF

modify_port_UUID
    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} V2ray 配置修改成功 ${Font}"
    else
        echo -e "${Error} ${RedBG} V2ray 配置修改失败 ${Font}"
        exit 6
    fi
}
nginx_conf_add(){
    touch ${nginx_conf_dir}/v2ray.conf
    cat>${nginx_conf_dir}/v2ray.conf<<EOF
    server {
        listen  443 ssl;
        ssl on;
        ssl_certificate       /etc/v2ray/v2ray.crt;
        ssl_certificate_key   /etc/v2ray/v2ray.key;
        ssl_protocols         TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers           HIGH:!aNULL:!MD5;
        server_name           serveraddr.com;
        location /ray {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        }
}
EOF

modify_nginx
    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} Nginx 配置修改成功 ${Font}"
    else
        echo -e "${Error} ${RedBG} Nginx 配置修改失败 ${Font}"
        exit 6
    fi

}

show_information(){
    clear
    echo -e "${OK} ${Green} V2ray+ws+tls 安装成功 "
    echo -e "${Red} V2ray 配置信息 ${Font}"
    echo -e "${Red} 地址（address）:${Font} ${domain} "
    echo -e "${Red} 端口（port）：${Font} 443 "
    echo -e "${Red} 用户id（id）：${Font} ${UUID}"
    echo -e "${Red} 额外id（alterId）：${Font} 64"
    echo -e "${Red} 加密方式（security）：${Font} 自适应 "
    echo -e "${Red} 传输协议（network）：${Font} ws "
    echo -e "${Red} 伪装类型（type）：${Font} none "
    echo -e "${Red} 伪装域名：${Font} ray "
    echo -e "${Red} 底层传输安全：${Font} tls "



}
main(){
    is_root
    dependency_install
    time_modify
    domain_check
    v2ray_install
    port_exist_check 80
    port_exist_check 443
    ssl_install
    acme
    nginx_install
    v2ray_conf_add
    nginx_conf_add
    echo -e "${OK} ${Green} V2ray+ws+tls 安装成功 ${Font} "
    show_information
}

main