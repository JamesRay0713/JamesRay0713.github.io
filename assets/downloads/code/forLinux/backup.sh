# 变量集合
new_user="ray"
user_psd="963."
user_psd_old="-"    # 如果执行脚本的用户不是root, 则一定要知道当前用户的sudo密码.
# 修改软件源
apt_mirror="tsinghua"   # 其他: "aliyun" 或 "ustc"
# 配置ssh服务
new_port=2222   # 本机ssh服务的新端口
need_port_forward=true  # 根据你的需求决定是否开启端口转发, 如果需要, 下面6个变量也许手动设置.
jumper_ip="60.204.232.126"
jumper_port="22"
jumper_user="ray"
jumper_psd="wf852963"
port_map_to_jumper="18087"  # 如果jumper是云服务器, 记得去`控制台安全组`打开相应端口.
pubkey_to_me="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8sRtGt0tWJuWSy4jKWwAfxO1UoFtctaZnZ4cSo3mViDuMWJ/paban5FN4ab/IWmr2mV9MVbgqnXtsFUulEQilaZC3UsBclCPF9gmwZ91/UQXa135dySsc/FMWbIAVPRqNrRHwimiAqITWftJIBVphF+nJtxB17qcDIr8Qi2CoeRkppURNBX9w53H9p/xlnjy4ggc5xvSQs+DJOdL05K6kk9pmro8Oqog5P7rAVMT+AfFBm8nSLWZ8lDZr9+F2grPicRGOW49uXqooXqBKIq8QqCcMk0+JN6AB3qyMQgQY2tOd3V2Zo8khzQDXrj9fFThjZ1kTTD4Wjpyh5lVMIXEOAP8GBeYIEwuFNnzwIoawRgHlndoJGjI4XcqZAr2FLIY2B9BdO2nbZ922QZxjw0+SyIg4TV3bG6ysYI7G0+6mBO8G8kVRqqkDRtouKkiXZ7CVSjUYLooykM70nxnxaKi03zXHyfehS9wJlYKVn/nHCdr4SSL+kn1Ey8EzjhoNLVMEgylBrTjjrbeMVWd9k7G9me48fa9NyZofb3Xc/lwtThW9PCNYmk62bJlGRDzLQSTrir4B9i2hQxGKTIQNvJOWVZbpEswX6u3x/SCuLtwym5ywdgJpI4rUp+hstQ0s1hn1hg4pvbY/0gS8OHX9QOgBHtxMijgoPcEZfwUufAOVMQ== raymond0820h@gmail.com"
# 配置代理
sub_list_url="https://dy.ssysub9.xyz/api/v1/client/subscribe?token=49f0731503d272d3a3fb0a2448aab703"
http_proxy=http://127.0.0.1:7890
https_proxy=http://127.0.0.1:7890

cd $HOME
PKGS_DIR=$HOME/packages
LOGS_DIR=$HOME/logs
## end


if [ -z "$(command -v sudo)" ]; then
    apt install sudo -y
fi
if [ "$(id -u)" -ne 0 ]; then
    echo $user_psd | sudo -S apt update
else
    apt update
fi

declare -A vars=(
    ["key1"]="value1"
    ["key2"]="value2"
    ["key3"]="value3"
)
vars["new_user"]="ray"

 > /dev/null 2>&1



ssh -qCNf -L 7890:127.0.0.1:7890 ray@60.204.232.126
# 7. 安装并配置代理工具clash    用法: `config_proxy`   
    # 仅用于有公网IP的云服务器上, 
config_proxy() {
    echo "✨ ✨ CONFIGING: proxy tool clash-v1.18.0... ✨ ✨"
    # 提前退出
    env | grep proxy > /dev/null && return 0
        # 无需安装clash, 只需配置http_proxy后立即退出
    if $host_already_proxy; then
        # if uname -a | grep -q "WSL"; then local proxy_ip="127.0.0.1"; fi
        # 如果是在docker中, 则用docker0的ip
        if [ -f /.dockerenv ]; then 
            http_proxy="172.17.0.1:7890"
            https_proxy="172.17.0.1:7890"
        fi
        cat << EOF >> $HOME/.zshrc
export http_proxy="$http_proxy"
export https_proxy="$https_proxy"
EOF
        echo "  ✅ Already use http_proxy by LAN of host-machine."
        return 0
    fi
    
    local arch=$(dpkg --print-architecture)
    local clash_url="http://assets.taddream.site/downloads/proxy-tools/clash-archived/clash-linux-$arch-v1.18.0.gz"
    local clash_bin="/usr/local/bin/clash"
    local clash_conf_dir="$HOME/.config/clash"
    local SC_HOME="$PKGS_DIR/subconverter"

    # 下载clash-v1.18.0👉 解压到`$clash_bin`👉 设置权限👉 测试安装成功
    if ! clash -v > /dev/null 2>&1; then
        cd "$PKGS_DIR"
        wget "$clash_url" -O clash-linux-amd64-v1.18.0.gz
        gzip -dc clash-linux-amd64-v1.18.0.gz > clash
        sudo mv clash "$clash_bin"
        sudo chmod +x "$clash_bin"
        echo "  ✅ 1- Clash installation successfully."
        # 下载Country.mmdb
        mkdir -p $clash_conf_dir
        wget http://assets.taddream.site/downloads/proxy-tools/Country.mmdb -O $clash_conf_dir/Country.mmdb
    fi
    # 配置clash的config.yaml
    if [ ! -f "$clash_conf_dir/config.yaml.bak" ]; then
        # 下载配置文件生成工具subconverter👉 解压👉 软连接使全局可用
        wget http://assets.taddream.site/downloads/proxy-tools/transfor-tools/subconverter_linux64.tar.gz
        tar -zxvf subconverter_linux64.tar.gz
        sudo ln -sf "$SC_HOME/subconverter" /usr/local/bin/subconverter
        # 把`订阅url`写入subconverter的`generate.ini`配置文件
        grep -q "ssy2clash" "$SC_HOME/generate.ini" > /dev/null 2>&1 || \
            cat << EOF >> $SC_HOME/generate.ini
[ssy2clash]
path=config.yml
target=clash
url=${sub_list_url}
EOF
        # 执行生成命令👉 结果复制到`config.yaml`
        cd "$SC_HOME"
            # skip-cert-verify可以防止证书验证失败
        subconverter -g --artifact "ssy2clash" --skip-cert-verify
        cp "$clash_conf_dir/config.yaml" "$clash_conf_dir/config.yaml.bak" || true
        cp "$SC_HOME/config.yml" "$clash_conf_dir/config.yaml"
        echo "  ✅ 2- Clash config.yaml successfully."
    fi
    # proxy_url写入`.zshrc`
    if ! grep -q "http_proxy" "$HOME/.zshrc"; then
        cat << EOF >> $HOME/.zshrc

# 代理
export http_proxy=$http_proxy
export https_proxy=$https_proxy
EOF
    fi
    # 后台启动clash服务
    pkill clash || true
    nohup clash > "$LOGS_DIR/clash.log" 2>&1 &

    # 把`订阅更新` 和 `clash开机自启`写入`.zshrc`
    if ! grep -q "nohup clash" "$HOME/.zshrc"; then
        cat << EOF >> "$HOME/.zshrc"

# 订阅更新 & clash服务开启
(
    cd "$SC_HOME"
    subconverter -g --artifact "ssy2clash" --skip-cert-verify > /dev/null
    cp "$clash_conf_dir/config.yaml" "$clash_conf_dir/config.yaml.bak" || true
    cp "$SC_HOME/config.yml" "$clash_conf_dir/config.yaml"
    pkill clash || true
    nohup clash > "$LOGS_DIR/clash.log" 2>&1 & 
    echo "💡 💡 已开启 [clash代理]. "
)
EOF
        echo "  ✅ 3- Clash set to start self boot."
    fi
    # 测试代理可用
    status_code=$(curl -LI google.com -o /dev/null --connect-timeout 10 -s -w "%{http_code}")
    if [ "$status_code" -eq 200 ]; then
        echo "  ✅ 4- bingo to google.com!"
    else
        echo "  ❌ ${status_code}, clash install and config failed."
    fi
}