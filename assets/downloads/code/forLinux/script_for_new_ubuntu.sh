#!/bin/bash
# 该脚本可快速配置一个Ubuntu新系统的生产环境: 
#   建新用户; 国内软件源; 基础软件包; 安装omz; ssh服务及远程端口转发; 
#   clash代理; conda和poetry; docker; code-server; NVIDIA容器工具包.

# 使用对象: 可以是Ubuntu独立主机, docker容器, WSL2, 云服务器.
# 使用方法: 
#   1. 准备目录: `sudo mkdir /z_pub; sudo chmod 777 /z_pub; cd /z_pub` 
#   2. 下载: `sudo apt install -y wget; wget http://assets.taddream.site/downloads/code/script_for_new_ubuntu.sh -O cfgOS.sh`
#   2. 修改: 按照你的需求, 在文件底部函数`main_base`中修改变量、注释掉不想要的函数模块.  
#   3. 执行: `bash /z_pub/cfgOS.sh | tee /z_pub/cfgOS.log`


set -e
# 👉 👉 👉 👉 变量预设 👈 👈 👈 👈 
## 这些预设的变量会根据实际情况进行`覆盖`,`忽略`.
set_vars(){
    unq_nm="my-wsl24"       # 主机名, 用作唯一识别标志
    # 创建新用户
    new_user="ray"
    user_psd="963."
    user_psd_old="963."     # 如果执行脚本的用户不是root, 则一定要知道当前用户的sudo密码.
    # 修改软件源
    apt_mirror="tsinghua"   # 其他: aliyun, ustc, huawei, tencent
    # 配置ssh服务
    new_port=2222
    pri_key="$HOME/.ssh/general_rsa"
    # 配置端口转发. 
    jumper_ip="-"  
    jumper_port="22"
    jumper_user="ray"
    jumper_psd="963."
    port_map_to_jumper="18087"  # 用于本机的ssh端口`new_port`映射到跳板机的`port_map_to_jumper`端口. 如果jumper是云服务器, 记得去`控制台安全组`打开相应端口.
        # 公钥来自: MF_M9pro-win11-ray-"C:\Users\ray\.ssh\general_rsa.pub"
    pubkey_to_me="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCqXu2pwhZNkSWkctwz6KC5xzoLefAscZJrqwRFwxuZYi+8lStjg2g0MLHvzYA4RA1ZmO4IhzrSRcEYcEtKYlc1BFESek2f/gyrKNbgUwJrswYpEEpis9QX3BAooYAQLAc28iTA3S6rY2zb2MMprKXF3lNy8Nao+9xEPxQBH+ZHxKTLxFwV9gDN+TmWk30OS7dXWm3XKVk9zC/WFCTPP/mnNcDnVXSvTSIhZlArJKH2gQX1cFAiYZIU9R0r5+HpefCjc8NvL4nvKNIrPj0jhR7J9sxiYpdDvvb3jObTMr4Q8HUmS1WVfMsDorHRceIlFapG42YtJWrVRTTBBWsZCoMqEQAIJJd3XpbZCdQMkQsjQeEeCxKxLKGoGciNMJsIYkhvv8sPML/wTfl+3gf3G6K3oNNa1KRgeH+wXOk3NhSJA8lCEgPfSZ+IxWzG3IbY1563JK6fa/mYKNY+QKl7hlHwN7zuN0jI86J3FqeinoqjKmoKUFfnnPdUuc1IWISDE/695YzL33ZJYOKNQJEjPgA6VOuJzBiRN6cLLpuJbWcsGD+ZtcbUFY6AWbr+aTE1yL+14FckGVWPTJN4iqJySaQ3hKiJ80CwZXbjKJX+T3uywwj4gQtsUCYTsT2D4zTjQ7tqHf9+alhocdmlLVbRHTpsPRWyVUAe3ycwJcc5I+zJqw== raymond0820h@gmail.com"
    # 配置代理
        # (备用方法) 以`用户名+密码`使用其他机器的clash服务, 值来自远程机器的clash的config.yaml的`authentication`  
    proxy_usr_psd="---:---"
        # (当本机是jumper, 且你想安装clash时才使用) 直接取用clash`订阅配置文件`的url资源
    clash_cfg_file_url="-"
        # (当你想在本机安装clash, 且想每日更新订阅时才使用) 订阅url, 用于生成`订阅配置文件`
    sub_list_url="https://su.xfjhchr.com:8888/api/v1/client/subscribe?token=--你的token--"   # 
    # code-server的端口转发
    coder_pwd="0AEBFEE0D40DD083576D44591871D6F9"
    coder_port="18080"
    CF_dns_api_token="-"
    coder_domain="-"

    ## 系统变量
    PKGS_DIR=$HOME/packages
    LOGS_DIR=$HOME/logs
    codename=$(awk -F= '/^VERSION_CODENAME=/ {print $2}' /etc/os-release)
    codeid=$(awk -F= '/^ID=/ {print $2}' /etc/os-release)
    # if [ -f /.dockerenv ]; then
    #     http_proxy="http://172.17.0.1:7890"
    # else
    http_proxy="http://127.0.0.1:7890"
    # fi
    pxy_env="export HTTP_PROXY=$http_proxy
export HTTPS_PROXY=$http_proxy"
    cd "$HOME"
}
    
# 👉 👉 👉 👉 11大函数模块 & 若干辅助函数 👈 👈 👈 👈 
# helper: 统一service、systemctl命令.   用法:`sys_ctl <operate> <svcName>`
    # 注: wsl2下的service命令里没有enable.
sys_ctl() {
    local operate="$1"
    local svcName="$2"
    if [ -z "$svcName" ] || [ -z "$operate" ]; then
        echo "💡 Usage: sys_ctl <operate> <svcName>"
        return 1
    fi
    if systemctl > /dev/null >&1; then
        sudo systemctl "$operate" "$svcName"
    else
        sudo service "$svcName" "$operate"
    fi
}

# helper: 追加编写说明书. 用法: `mk_manual "..."`
mk_manual() {
    echo -e "$1" | tee -a "$LOGS_DIR/README_cfgOS.txt"
}



# 0. 预装最基础软件包.  用法: `install_basebase_pkgs`
    # 只在`用户为root`时才判断是否安装, 因为普通用户下一定都已经安装了的.
    # `tzdata`: 时区包，cmake的依赖包。
install_basebase_pkgs() {
    echo "✨ ✨ INSTALLING: basebase packages... ✨ ✨"
    if [ "$(id -u)" -eq 0 ]; then
        packages=("sudo" "tzdata" "ca-certificates")
        for package in "${packages[@]}"; do
            if ! dpkg -l | grep -q "^ii  $package"; then
                DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"
                echo "  ✅ Installed: $package"
            else    echo "  ✅ Already installed: $package"
            fi
        done
        # 安装tzdata时放弃了交互, 这里手动设置时区配置
        echo "Asia/Shanghai" > /etc/timezone
        ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
        dpkg-reconfigure -f noninteractive tzdata
    fi
}

# 1. 自定义新用户.    用法: `config_new_user <new_user>`
config_new_user() {
    echo "✨ ✨ CONFIGING: create a new user with sudo authority... ✨ ✨"
    local new_user="$1"
    # 提前退出: 当前用户名正是`目标用户名`
    if [ "$(whoami)" = "$new_user" ]; then
        cd "$HOME"
        mkdir "$PKGS_DIR" || true
        mkdir "$LOGS_DIR" || true
        rm "$LOGS_DIR/README_cfgOS.txt" &> /dev/null || true
        mk_manual "✨ ✨ README: 脚本配置后, 系统使用须知 ✨ ✨\n\n"
        mk_manual "当前主机名字: $unq_nm"
        mk_manual "当前操作系统: $(uname -a)\n"
        mk_manual "- 已进入主力用户: $new_user "
        if [ "$new_user" != "root" ]; then
            mk_manual "  该用户密码是: $user_psd, 具有免密使用sudo的权限."
        fi
        return 0
    fi

    local current_script=$(realpath "$0")
    if ! id "$new_user" &>/dev/null; then
        # 创建新用户
            # 若当前是root:
        if [ "$(id -u)" -eq 0 ]; then
            useradd -m -s /bin/bash "$new_user"
            # 如果在wsl2, 可设当前用户为`默认用户`. (重启wsl2才生效)
            if uname -a |grep -q microsoft; then
                echo -e "[user]\ndefault=$new_user" >> /etc/wsl.conf
            fi
            # 若当前是其他用户(非目标用户)
        else 
            echo "$user_psd_old" | sudo -S useradd -m -s /bin/bash "$new_user"
        fi
        # 设置新密码👉 加入sudo组👉 免密使用sudo
        echo "$new_user:$user_psd" | sudo chpasswd
        sudo usermod -aG sudo "$new_user"
        echo "$new_user ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
        echo "  ✅ Created user: $new_user"
        # 当该函数在终端中使用, 提前退出.
        if echo "$current_script" | grep -q "bin"; then return 0; fi
    else
        sudo usermod -aG sudo "$new_user"
        echo "$new_user ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
    fi
    # 新用户身份重新执行当前脚本
    sudo su - "$new_user" -c "
        echo -e \"\n\n\n✨ ✨ ✨ ✨ enter the sub-shell of $new_user ✨ ✨ ✨ ✨\"
        echo \"cur_user: \$USER, script_path: $current_script\"
        bash $current_script"
    exit 0
}

# 2. 配置软件源. 该方法可独立于当前脚本使用, 仅限`Ubuntu`   用法: `config_domestic_apt_sources [<apt_mirror>]`
config_domestic_apt_sources() {
    echo "✨ ✨ CONFIGING: apt mirror to $apt_mirror... ✨ ✨"
    local apt_mirror="${1:-"tsinghua"}"
    local sources_list="/etc/apt/sources.list"
    local backup_sources_list="/etc/apt/sources.list.backup"
    local url=""
    local subfix=""
    # 提前退出
    if grep -q "tsinghua\|aliyun\|ustc\|huawei\|tencent" "$sources_list"; then
        sudo apt-get update
        echo "  ✅ Already configured apt mirror" && return 0
    fi

    case "$apt_mirror" in
        "tsinghua")
            url="https://mirrors.tuna.tsinghua.edu.cn/$codeid/"
            ;;
        "aliyun")
            url="http://mirrors.aliyun.com/$codeid/"
            ;;
        "ustc")
            url="https://mirrors.ustc.edu.cn/$codeid/"
            ;;
        "huawei")
            url="https://mirrors.huaweicloud.com/$codeid/"
            ;;
        "tencent")
            url="https://mirrors.cloud.tencent.com/$codeid/"
            ;;
    esac
    case "$codeid" in
        "ubuntu")
            subfix="main restricted universe multiverse"
            ;;
        "debian")
            subfix="main contrib non-free non-free-firmware"
            ;;
    esac
    sudo mv "$sources_list" "$backup_sources_list" || true
    sudo mv "$sources_list.d/ubuntu.sources" "$sources_list.d/ubuntu.sources.bak" || true
    # sources_list中只配置 deb 源就足够了, 除非你需要查看或修改软件的源代码. 这样可以节省一些磁盘空间并加快 apt-get update 的速度。
    sudo tee "$sources_list" > /dev/null <<EOF
deb ${url} ${codename} ${subfix}
deb ${url} ${codename}-updates ${subfix}
deb ${url} ${codename}-backports ${subfix}
EOF
    sudo apt-get update
    sudo apt-get upgrade -y
    mk_manual "- 已配置新的apt源: 详见 $sources_list" || true
}

# 3. 安装基础软件包
install_basic_pkgs() {
    echo "✨ ✨ INSTALLING: basic packages... ✨ ✨"
    packages=(
        # 注：build-essential会安装编译器（如 gcc）、make 等基本开发工具  "g++" "gcc" "gnupg" 
        # psmisc用于pstree
        # "build-essential" # "language-pack-en"
        "git" "vim" 
        "curl" "wget" "iproute2" "iputils-ping" "telnet" "dnsutils"
        "htop" "psmisc" 
        "tree" "tar" "gzip" 
        "zsh" "tmux" 
        "ssh" "openssh-client" "sshpass" 
        "kmod" 
    )

    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package"; then
            echo "  👉 install package: ${package}"
            sudo apt-get install -y $package
        else
            echo "  👉 no need to install: $package."
        fi
    done
    mk_manual "- 已安装基础软件包: ${packages[*]}"
}

# 4. 安装 oh-my-zsh     用法: `install_ohmyzsh`
install_ohmyzsh() {
    echo "✨ ✨ INSTALLING: ohmyzsh... ✨ ✨"
    # 提前退出  [ $(ps -p $$ -o comm=) = "zsh" ] &&
    [ -d ~/.oh-my-zsh ] && echo "  ✅ Already installed omzsh." && return 0 || true
    # 安装zsh 
    command -v zsh &> /dev/null || sudo apt-get install -y zsh
    # 安装ohmyzsh
    cd "$PKGS_DIR"
    wget -O "install_ohmyzsh.sh" https://gitee.com/mirrors/ohmyzsh/raw/master/tools/install.sh
    sed -i 's/REPO:-ohmyzsh\/ohmyzsh/REPO:-jamesray0713\/ohmyzsh/' "install_ohmyzsh.sh"
    sed -i 's/REMOTE:-https:\/\/github/REMOTE:-https:\/\/gitee/' "install_ohmyzsh.sh"
    sudo chmod +x "install_ohmyzsh.sh"
    echo "yes" | ./install_ohmyzsh.sh -y
    # 安装插件
    cd ~/.oh-my-zsh/custom/plugins
    git clone https://gitee.com/jamesray0713/zsh-autosuggestions
    git clone https://gitee.com/jamesray0713/zsh-syntax-highlighting
    # 配置主题
    sed -i 's/ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' ~/.zshrc
    sed -i 's/plugins=(git)/plugins=( git zsh-autosuggestions zsh-syntax-highlighting )/' ~/.zshrc
    # 改抬头
    sed -i 's/PROMPT+=.*/PROMPT+=\x27 %{$fg[cyan]%}[$PWD]%{$reset_color%} $(git_prompt_info)\x27/' ~/.oh-my-zsh/themes/robbyrussell.zsh-theme
    # 设为默认shell
    echo 'if [ -t 1 ]; then exec zsh; fi' >> ~/.bashrc
    # 注: 在脚本环境中, source命令并不会产生作用. 因为source只会重载变量等, 而不会立即切换shell 
    # source $HOME/.bashrc  
    cd "$HOME"
    mk_manual "- 已安装oh-my-zsh"
}

# 5.确保ssh-server可用   用法: `config_sshd`
# shellcheck disable=SC2120
config_sshd() {
    echo "✨ ✨ CONFIGING: open ssh-server... ✨ ✨"
    local SSHD_CONFIG="/etc/ssh/sshd_config"
    local cur_port="$new_port"
    local cfg_cnt="\n# ray's cfg \nPort $new_port \nPubkeyAuthentication yes"

    # 安装ssh-server
    dpkg -l | grep -q "openssh-server" || sudo apt-get install -y openssh-server
    # 生成主机秘钥(`/etc/ssh/...`)。非常必要, 用于别人连接本机时, 别人生成的known_hosts条目.
    sudo ssh-keygen -A
    # 配置: 改端口等
    if ! grep -q "^PubkeyAuthentication yes" $SSHD_CONFIG; then
        sudo cp $SSHD_CONFIG "$SSHD_CONFIG.bak"
        if [[ "$(curl -s ifconfig.me)" = "$jumper_ip" ]]; then
            cfg_cnt="\n# ray's cfg \nPubkeyAuthentication yes \nGatewayPorts yes \nAllowTcpForwarding yes"
        fi
        echo -e "$cfg_cnt" | sudo tee -a $SSHD_CONFIG
    fi
    # 设置: 服务开机自启
    sys_ctl enable ssh || echo "sudo service ssh restart" >> "$HOME/.zshrc" || true 
    # 设置: 写入`本机作为ssh服务端时的公钥`
    echo "$pubkey_to_me" >> "$HOME/.ssh/authorized_keys"
    # 启动、测试
    sys_ctl restart ssh
    sleep 2         # until nc -z localhost "$new_port"; do sleep 0.1; done
    sshpass -p "$user_psd" ssh -p "$cur_port" localhost \
         -o StrictHostKeyChecking=no -o ConnectTimeout=5 exit 
    echo "  ✅ ssh-server starts to run."
    mk_manual "- 已开启ssh-server, 配置内容有: \n$cfg_cnt"
}

# 5-1(helper). 一个完整的ssh连接的过程. 使用范围不限于本脚本
    # 使用前提: 这里规定, 除了jumper自身而外的任何一台机器(<target_name>) 想经ssh被访问之前, 都须将其ssh端口远程转发给<jumper_ip>
    # 使用方法: `exec_ssh_to [<target_name>] [<target_user>] [<target_ip>] [<target_port>] [<target_psd>]`
    # 最终效果: 用`ssh $target_name`就可以安全连接到目标机器.
exec_ssh_to() {
    if [[ "$1" = "-h" ]]; then
        echo " exec_ssh_to [目标机器名字] [目标用户] [目标机器IP] [目标端口] [目标用户的密码]"
        echo "   by default: \"exec_ssh_to\" = \"exec_ssh_to jumper ray 60.204.232.126 22 963.\""
        return 0
    fi
    local target_name="${1:-"jumper"}"  # 目标的名称(自定义)
    local target_user="${2:-"ray"}"     # 目标的用户名
    local target_port="${4:-"22"}"      # 可以是jumper自己的ssh端口, 也可以是其他机器(target_name)在jumper上的ssh远程转发端口.
    local target_psd="${5:-"963."}"     # 目标的用户名的密码
    if [ -z "$jumper_ip" ] || [ "$jumper_ip" = "-" ]; then
        local jumper_ip="${3:-"60.204.232.126"}"
    fi
    # 提前退出
    if [[ "$jumper_ip" = "$(curl -s ifconfig.me)" ]]; then return 0; fi
    ssh "$target_name" exit && echo "  ✅ Already could ssh to $target_name." && return 0 || true
    # 生成秘钥对
    local pri_key="$HOME/.ssh/general_rsa"
    yes | ssh-keygen -t rsa -b 4096 -C "From-$unq_nm-$new_user-To-aywr - raymond0820h@gmail.com" -f "$pri_key" -N ""
    # 发送公钥给 target_name (要sleep, 否则无法传递用户密码)
    sleep 2
    sshpass -p "$target_psd" ssh-copy-id -o StrictHostKeyChecking=no -i "$pri_key.pub" -p $target_port $target_user@$jumper_ip
    # 配置target_name 的连接信息
    local ssh_cfg="$HOME/.ssh/config"
    tee -a "$ssh_cfg" <<EOF
Host $target_name
    HostName $jumper_ip
    Port $target_port
    User $target_user
    ServerAliveInterval 60
    IdentityFile $pri_key
EOF
    # 测试target_name 可连
    if ssh "$target_name" -o StrictHostKeyChecking=no -o ConnectTimeout=5 exit; then
        echo "  ✅ 'ssh $target_name' successfully."
    else
        echo "  ❌ ❌ connect to $target_name failed. Please check it."
    fi
}

# 6. 开启远程端口转发, 用于没有公网IP的机器      用法: `config_portforwarding` 
config_portforwarding() {
    echo "✨ ✨ CONFIGING: open port-forwarding... ✨ ✨"
    # 提前退出
    if [[ "$(curl -s ifconfig.me)" = "$jumper_ip" ]]; then
        echo "  ✅ Already in jumper, no need to PF." && return 0; 
    fi
    if pgrep -f "ssh -gfnNTR" &> /dev/null; then
        echo "  ✅ Already running port forwarding." && return 0
    fi
    # 配置好与jumper的连接
    exec_ssh_to jumper $jumper_user $jumper_port $jumper_psd
    mk_manual  "- 已可访问跳板机: 'ssh jumper' "
    # 开启端口转发
    ssh -gfnNTR $port_map_to_jumper:localhost:$new_port jumper \
        -o StrictHostKeyChecking=no > "$LOGS_DIR/port-forwarding.log"
    
    echo "  💡 设置端口转发开机自启."
    if ! grep -q "ssh -gfnNTR" "$HOME/.zshrc"; then
        cat << EOF >> "$HOME/.zshrc"

# 端口转发
if ! pgrep -f "gfnNTR $port_map_to_jumper" > /dev/null; then
    ssh -gfnNTR $port_map_to_jumper:localhost:$new_port jumper -o StrictHostKeyChecking=no > $LOGS_DIR/port-forwarding.log
    echo "💡💡 Done: Remote-Port-Forwarding. Connect to 'cur host cur user' as below: "
    echo "  ssh -p $port_map_to_jumper $new_user@$jumper_ip -i ~/.ssh/your-secret-key"
    echo "  or use password: $user_psd"
fi
EOF
    fi
    echo "  ✅ Port-Forwarding successfully! Please use: "
    echo "      ssh -p ${port_map_to_jumper} ${new_user}@${jumper_ip} "
    mk_manual "- 已开启ssh远程端口转发, 且刷新终端就能自动重启."
}


# 7-1 (helper func) 使clash自动更新订阅列表. 该函数可在脚本外单独使用.    用法: `config_proxy_clash_auto_update [<sub_list_url>]`
config_proxy_clash_auto_update() {
    # 准备变量
    if [[ "$1" = "-h" ]]; then
        echo " config_proxy_clash_auto_update [<sub_list_url>]"
        return 0
    fi
    if [ -z "$sub_list_url" ]; then local sub_list_url="$1"; fi
    if [ -z "$PKGS_DIR" ]; then local PKGS_DIR="$HOME/packages"; fi

    local clash_cfg_dir="$HOME/.config/clash"
    local SC_HOME="$PKGS_DIR/subconverter"
    cd "$PKGS_DIR"

    # 准备配置文件生成工具subconverter
    echo "  ✨ CONFIGING: auto update sub-list in clash... ✨"
        # 下载👉 解压👉 软链接使全局可用    
    if ! command -v subconverter; then
        wget http://assets.taddream.site/downloads/proxy-tools/transfor-tools/subconverter_linux64.tar.gz
        tar -zxvf subconverter_linux64.tar.gz
        sudo ln -sf "$SC_HOME/subconverter" /usr/local/bin/subconverter
    fi
        # 把`订阅url`写入subconverter的`generate.ini`配置文件
    sed -i '/ssy2clash/,$d' "$SC_HOME/generate.ini"     # 尝试删除原有的自定义配置
    cat << EOF >> "$SC_HOME"/generate.ini

[ssy2clash]
path=config.yml
target=clash
url=${sub_list_url}
EOF

    # 提前退出
    if crontab -l 2>/dev/null | grep -q "sub_list_update_daily.sh"; then
        echo "  ✅ 已存在定时任务: 每日0点更新订阅列表 & 重启clash."
        bash $clash_cfg_dir/sub_list_update_daily.sh
        return 0
    fi

    # 制作每日定时任务: `订阅更新` 和 `重启clash`
    echo "  🗒️ 制作定时任务脚本: $clash_cfg_dir/sub_list_update_daily.sh"
    cat << EOF > "$clash_cfg_dir/sub_list_update_daily.sh"
# 每日订阅更新 & clash服务自动重启
cd "$SC_HOME"
http_proxy="http://127.0.0.1:7890" https_proxy="http://127.0.0.1:7890" subconverter -g --artifact "ssy2clash"
cp "$clash_cfg_dir/config.yaml" "$clash_cfg_dir/config.yaml.bak" || true
cp "$SC_HOME/config.yml" "$clash_cfg_dir/config.yaml"
pkill clash || true
cd $HOME
nohup clash > "$LOGS_DIR/clash.log" 2>&1 & 

cur_remain=\$(grep '下次重置剩余' $clash_cfg_dir/config.yaml | sed -n 's/.*下次重置剩余：\([0-9.]*\) 天.*/\1/p' | head -n 1)
echo "💡 💡 \$(date) , [clash及订阅列表]已更新, 距下次重置剩余: \$cur_remain 天. "
EOF
    echo "0 0 * * * /bin/bash $clash_cfg_dir/sub_list_update_daily.sh >> $LOGS_DIR/clash_sub_list_update_daily.log 2>&1" | crontab -
    echo "  ✅ 已设置定时任务: 每日0点更新订阅列表 & 重启clash."
}

# 7-1. 配置代理方式一   用法: `config_proxy_clash`   
    # 该方法是在本地安装、配置代理工具并自动更新订阅
config_proxy_clash() {
    echo "✨ ✨ CONFIGING: proxy tool clash-v1.18.0... ✨ ✨"
    pkill -f clash || true
    local arch=$(dpkg --print-architecture)
    local clash_url="http://assets.taddream.site/downloads/proxy-tools/clash-archived/clash-linux-$arch-v1.18.0.gz"
    local clash_bin="/usr/local/bin/clash"
    local clash_conf_dir="$HOME/.config/clash"

    # 下载clash-v1.18.0👉 解压到`$clash_bin`👉 设置权限👉 测试安装成功
    if ! clash -v > /dev/null 2>&1; then
        cd "$PKGS_DIR"
        wget "$clash_url" -O clash-linux-$arch-v1.18.0.gz
        gzip -dc clash-linux-amd64-v1.18.0.gz > clash
        sudo mv clash "$clash_bin"
        sudo chmod +x "$clash_bin"
        echo "  ✅ 1- Clash installed."
        # 下载Country.mmdb
        mkdir -p $clash_conf_dir
        wget http://assets.taddream.site/downloads/proxy-tools/Country.mmdb -O $clash_conf_dir/Country.mmdb
    fi
    # 配置config.yaml. 
        # 弃用: 因为`手动复制文本内容`的方法, 可能带来编码报错. 
            # echo "$clash_cfg_cnt" | tee "$clash_conf_dir/config.yaml" > /dev/null

        # 改为: `远程复制文本文件`的方法: 这里`母文件`来自远程主机`jumper`.
        # if:  本机不是jumper → 用scp从jumper下载. (前提: 需先在jumper上安装好clash)
        # else:本机是jumper → 用url下载. (前提: 需先把配置文件上传, 有盗链风险)
    scp jumper:/home/ray/.config/clash/config.yaml "$clash_conf_dir/config.yaml" \
    || wget $clash_cfg_file_url -O "$clash_conf_dir/config.yaml"
    # 后台启动服务
    nohup clash > "$LOGS_DIR/clash.log" 2>&1 &
    echo "  ✅ 2- Clash configed and started background."
    # 测试
    sleep 1
    status_code=$(curl -x "$http_proxy" -LI google.com -o /dev/null -s -w "%{http_code}" || true)
    if [ "$status_code" -eq 200 ]; then
        echo "  ✅ 3- bingo to google.com!"
    else
        echo "  ❌ ${status_code}, clash install and config failed." && return 1
    fi

    # 使clash自动更新订阅列表
    config_proxy_clash_auto_update "$sub_list_url"

    # 后处理
    if ! grep -q "clash" "$HOME/.zshrc"; then
        tee -a "$HOME/.zshrc" << EOF

# 使用本机的clash代理服务
if ! pgrep -f "clash" > /dev/null; then
    nohup clash > $LOGS_DIR/clash.log 2>&1 &
fi
$pxy_env
echo "💡💡 Already set 'HTTPS_PROXY', based on local 'clash' with everyday update."
EOF
    fi
    mk_manual "- 已安装clash, 且配置了每日定时任务: 刷新订阅列表 & 重启clash."
    mk_manual "  - 定时任务的脚本: $clash_conf_dir/sub_list_update_daily.sh"
    mk_manual "  - 查看定时任务列表: crontab -l"
}

# 7-2. 配置代理方式二   用法: `config_proxy_noclash` 
    # 该方法可独立于当前脚本单独使用.
    # 该方法把安装工具、更新订阅的工作交给了你的`公网主机`, 本机只需配置`http_proxy`, 更简单高效
config_proxy_noclash() {
    echo "✨ ✨ CONFIGING: http_proxy ... ✨ ✨"
    echo "  ⚠️ ⚠️  请事先确保公网主机/宿主机的clash已运行."

    # 提前退出: 已配置http_proxy.
    status_code=$(curl -x "$http_proxy" -LI google.com -o /dev/null -s -w "%{http_code}" || true)
    if [ "$status_code" -eq 200 ] || env | grep -q "HTTPS_PROXY"; then
        echo "  ✅ Already has HTTP_PROXY, skip." && return 0
    fi

    # 提前退出: 如果本机是容器, 则直接使用宿主机的7890端口  ⚠️ 更新: 该方法舍弃, 改为下面方案2: 容器内的代理也用公网主机的.
        # if [ -f "/.dockerenv" ]; then
        #     echo -e "\n# 代理 \n$pxy_env" | tee -a "$HOME/.zshrc"
        #     echo "  ✅ set HTTP_PROXY in docker." 
        #     return 0
        # fi

    # 方案1(备用), clash配置授权密码. 下面的`proxy_user1:proxy_pass1`需要去你的公网主机里面
    #   的`$HOME/.config/clash/config.yaml`里添加`authentication:\n  - "proxy_user1:proxy_pass1"`后重启.
    # export http_proxy="http://$proxy_user1:$proxy_pass1@$jumper_ip:7890"
    #     # 开机自启
    # echo -e "\nexport http_proxy=http://$proxy_user1:$proxy_pass1@$jumper_ip:7890\nexport http_proxy=http://$proxy_user:$proxy_psd@$jumper_ip:7890" >> "$HOME/.zshrc"

    # 方案2, 用ssh把本地7890端口映射到公网
    pkill -f "ssh -qCNf" || true
    sshpass -p "$jumper_psd" ssh -qCNf -o StrictHostKeyChecking=no -L 7890:127.0.0.1:7890 $jumper_user@$jumper_ip
        # 开机自启
    if ! grep -q "ssh -qCNf" "$HOME/.zshrc"; then
        tee -a "$HOME/.zshrc" << EOF

# 使用cvm的clash服务                                                                                                                                 
if ! pgrep -f "ssh -qCNf" > /dev/null; then
    sshpass -p "$jumper_psd" ssh -qCNf -o StrictHostKeyChecking=no -L 7890:127.0.0.1:7890 $jumper_user@$jumper_ip
fi
$pxy_env
echo "💡💡 Already set 'HTTPS_PROXY', based on '$jumper_ip:7890'."
EOF
    fi

    # 测试
    status_code=$(curl -x "$http_proxy" -LI google.com -o /dev/null -s -w "%{http_code}" || true)
    if [ "$status_code" -eq 200 ]; then
        echo "  ✅ bingo to google.com! 调用跳板机的 127.0.0.1:7890 端口生效."
    else
        echo "  ❌ ${status_code}, failed with http_proxy." && return 1
    fi
    mk_manual "- 已配置clash代理: 是用的ssh隧道连接到的公网主机上的clash服务. 该功能开机自启." || true
    mk_manual "  - 如果有问题, 请杀死并重启\"ssh -qCNf\"进程, 或检查公网主机的clash服务. " || true
}
    
 
# 8. 安装conda和poetry  用法: `install_miniforge_poetry`
install_miniforge_poetry() {
    echo "✨ ✨ INSTALLING: Miniforge and poetry... ✨ ✨"
    local CONDA_BIN="$HOME/miniforge3/bin"
    # Miniforge: 是轻量版conda, 内含mamba、pypy3等
    if "$CONDA_BIN/mamba" --version > /dev/null 2>&1; then
        echo "  ✅ Miniforge is already installed."
    else
        # 安装
        cd "$PKGS_DIR"
        http_proxy="" https_proxy="" curl -L -O "https://mirrors.tuna.tsinghua.edu.cn/github-release/conda-forge/miniforge/LatestRelease/Miniforge3-$(uname)-$(uname -m).sh"
        bash "Miniforge-pypy3-$(uname)-$(uname -m).sh" -b -p $HOME/miniforge3
        # echo -e "\nexport PATH=$CONDA_BIN:$HOME/miniforge3/condabin:\$PATH" >> ~/.zshrc   TODO: 似乎此工作在conda init中已经做了
        # 配置-初始化脚本: 若zsh中没有, 就从bashrc获取
        "$CONDA_BIN/mamba" init
        if  ! grep -q "conda initialize" "$HOME/.zshrc"; then
            local matched_content=$(awk '/# >>> conda initialize >>>/,/# <<< conda initialize <<<$/' "$HOME/.bashrc")
            local modified_content=$(echo "$matched_content" | sed 's/shell\.bash/shell.zsh/')
            echo -e "\n$modified_content" >> "$HOME/.zshrc"
        fi
        echo "  ✅ mamba version: $($CONDA_BIN/mamba --version)"
    fi
    # poetry: 一个项目一个虚拟环境.
    local POETRY_DIR="$HOME/.local/bin"
    local POETRY_BIN="$POETRY_DIR/poetry"
    if "$POETRY_BIN" --version &> /dev/null; then
        echo "  ✅ poetry is already installed."
    else
        if curl -x "$http_proxy" -sSL https://install.python-poetry.org \
        | HTTPS_PROXY="$http_proxy" python3 - ; then
            # sudo apt install python3-poetry
            echo -e "\nexport PATH=$POETRY_DIR:\$PATH" >> "$HOME/.zshrc"
            echo "  ✅ poetry version: $("$POETRY_BIN" --version)"
            "$POETRY_BIN" config virtualenvs.in-project true
        else
            echo "  ❌ Failed to install poetry. Please try later." 
        fi
    fi
    mk_manual "- 已安装python相关工具: 环境管理(miniforge), 包管理(poetry)."
}

# 9.（可选）安装docker。    用法: `install_docker`
    # 如果想快速复现别人项目，这是必备的。
install_docker() {
    echo "✨ ✨ Installing Docker Engine... ✨ ✨"
    # 提前退出
    if [ -f /.dockerenv ] || docker -v; then
        echo "  ✅ is a container or install docker already, no need to install again."
        return 0
    fi
    # 安装
        # 添加官方的gpg-key
    sudo mkdir -m 0755 -p /etc/apt/keyrings
    curl -x "$http_proxy" -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg

        # 设置软件库
    # local docker_official_repository="https://download.docker.com/linux/ubuntu"           # 官方docker源
    local docker_aliyun_repository="https://mirrors.aliyun.com/docker-ce/linux/ubuntu"    # 阿里云的镜像，国内选它，因为下载速度快
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $docker_aliyun_repository \
        $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # 安装docker引擎
    sudo apt-get update 
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 
    sys_ctl start docker 
    echo "  ✅ installed: $(docker -v)"

    # 配置
        # 当前用户加入docker组 (使用时可以免`sudo`) ⚠️ 重启终端才能生效
    sudo usermod -aG docker $USER
        # 用代理 (系统的https_proxy变量) 给docker的pull加速
    if ! sudo docker info | grep -q "HTTPS"; then
        local dkr_serve_dir="/etc/systemd/system/docker.service.d"
        sudo mkdir -p "$dkr_serve_dir"
        sudo tee -a "$dkr_serve_dir/http-proxy.conf" << EOF
[Service]
Environment="HTTPS_PROXY=$http_proxy"
Environment="HTTP_PROXY=$http_proxy"
Environment="NO_PROXY=localhost,127.0.0.1,::1"
EOF
    fi
    sudo systemctl daemon-reload || echo "  ⚠️ failed with 'systemctl daemon-reload', maybe cause there is in WSL2."
    sys_ctl restart docker \
    && echo "  ✅ configed: proxy for docker."

    # 测试 (这里必须得`sudo`, 因为当前脚本无法通过重启终端来更新`group`)
    if sudo docker run hello-world; then
        echo "  ✅ docker runs container successfully."
        mk_manual "- 已安装docker引擎, 并配置了代理加速镜像拉取. 查看是否有代理: docker info | grep -i proxy "
    else
        echo "  ❌ docker install failed. Please check it." && return 1
    fi  
}


# 10. (可选) 安装code-server。  用法: `install_code_server`
install_code_server() {
    echo "✨ ✨ INSTALLING: code-server... ✨ ✨"
    # 安装: 使本地可访问该服务
    if ! sys_ctl status "code-server@$USER" > /dev/null; then
        echo "  1️⃣ install and make a code-server service." 
        curl -x "$http_proxy" -fsSL https://code-server.dev/install.sh | HTTPS_PROXY="$http_proxy" sh
        # 设置密码
        local cs_cfg_dir="$HOME/.config/code-server"
        mkdir -p "$cs_cfg_dir" 
        cd "$cs_cfg_dir"
        echo -e "bind-addr: 0.0.0.0:8080 \nauth: password \npassword: $coder_pwd \nlog: info" \
        | tee "$cs_cfg_dir/config.yaml" 
        # 设为系统服务且开机自启
        # nohup code-server > $LOGS_DIR/code-server.log 2>&1 &  # 手动启动服务
        sys_ctl enable "code-server@$USER" \
        || echo -e "\n sudo service code-server@$USER restart" | tee -a "$HOME/.zshrc"
        sys_ctl restart "code-server@$USER"
        sleep 2
        if curl -I http://127.0.0.1:8080; then
            mk_manual "- ✅ 已启动code-server服务, 可在本地浏览器用 http://localhost:8080 访问, 密码是 $coder_pwd"
        else
            echo "  ❌ failed to start code-server." && return 1
        fi
    fi

    # 配置: 把8080转发到云服的18080端口.  
    # TODO: `http+ip+port`的模式不够安全, 需要用Caddy对自己的域名做反代. 但此前配置时被卡在'域名未备案'的问题上.
        # 提前退出
    if [[ "$(curl -s ifconfig.me)" = "$jumper_ip" ]]; then
        coder_port="8080"
    fi
    local coder_url="http://$jumper_ip:$coder_port"
    if curl -I "$coder_url" | grep -q "200"; then
        mk_manual "     你还能通过 $coder_url 在任何地方访问本机的code-server."
        return 0
    fi
        # 若本机不是jumper, 则用远程端口转发, 将8080端口暴露到jumper的指定端口 $coder_port
    if [[ "$(curl -s ifconfig.me)" != "$jumper_ip" ]]; then
        pkill -f "gfnNTR $coder_port" || true
        ssh -gfnNTR $coder_port:localhost:8080 jumper
        mk_manual "     本机的8080已暴露, 可在任意地方使用 $coder_url 访问本机的code-server."
        # 写入zshrc
        tee -a "$HOME/.zshrc" << EOF

# vscode-web
echo "💡💡 code-server service is on, if '$coder_url' not available, "
echo "      use below first: \"ssh -gfnNTR $coder_port:localhost:8080 jumper\" . "
EOF
    fi
}

# 11.（可选）深度学习基础配置—— 装NVIDIA Container Toolkit
#   前提: 默认已安装显卡驱动，可执行nvidia-smi.  
#   必要性: 当想在容器里跑GPU，就得给宿主机装 Toolkit. 
install_nvidia_tools() {
    echo "✨ ✨ INSTALLING: NVIDIA Container Toolkit; CUDA; CUDNN... ✨ ✨"
    # 提前退出
    if dpkg -l |grep -q "libnvidia-container-tools"; then
        echo "  ✅ NVIDIA Container Toolkit is already installed." && return 0
    fi
    # 安装&配置NCT
    local nct_gpg_file="/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
        # 建立GPG key 和 package repository
    curl -x "$http_proxy" -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | sudo gpg --dearmor --batch --yes -o $nct_gpg_file \
    && curl -x "$http_proxy" -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed "s#deb https://#deb [signed-by=$nct_gpg_file] https://#g" \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    sudo apt-get update 
        # 安装
    sudo apt-get install -y nvidia-container-toolkit
        # 设置Docker daemon 守护进程识别Nvidia容器Runtime
    sudo nvidia-ctk runtime configure --runtime=docker
    sys_ctl restart docker
        # 测试, 将看到你的GPU的算力。
    if sudo docker run --rm -it --gpus=all nvcr.io/nvidia/k8s/cuda-sample:nbody nbody -gpu -benchmark; then
        echo "  ✅ installed nvidia-container-toolkit."
    else
        echo "  ❌ failed to install nvidia-container-toolkit." && return 1
    fi

    mk_manual "- 已安装nvidia-container-toolkit, 本机的docker容器里可以跑GPU了."
}

# 12. 在zshrc中设计一些快捷功能
config_zshrc() {
    tee -a "$HOME/.zshrc" > /dev/null << EOF
# 快捷功能
alias pkill-ssh="pkill -f 'ssh .*'"
EOF
}

# 👉 👉 👉 👉 执行计划 👈 👈 👈 👈
# 根据操作系统配置的不同场景和你的需求, 注释掉不需要安装的模块.  
main_base() {
    # 变量
    set_vars
    unq_nm="ray-freqtrade"
    jumper_ip="60.204.232.126"
    # 机器为内网普通独立主机时, 一般需设置:
        # port_map_to_jumper="18087"
    # 机器为jumper时, 一般需设置:
        # sub_list_url="-"
        # clash_cfg_file_url="-"    # 即从`sub_list_url`解析出代理配置文件, 然后传到自己的CDN得到的URL.
    # 机器为docker容器时, 一般需设置:
        # new_user="root"
    new_user="ftuser"

    # 模块
    install_basebase_pkgs
    config_new_user "$new_user"
    config_domestic_apt_sources "$apt_mirror"
    install_basic_pkgs
    install_ohmyzsh
    if [[ $sub_list_url =~ [a-z0-9]{10}$ ]]; then
        exec_ssh_to "jumper"
        config_proxy_clash              # 备用: 配本地的clash, 更复杂的配置.
    else
        config_proxy_noclash            # ⚠️port转发1⚠️ 常用: 调用云端或宿主机的clash, 简单方便.
    fi

    #    ⬆️以上模块都是必须的, 请勿注释. ⬇️以下模块为可选的. 
    # install_miniforge_poetry
    # if [ ! -f "/.dockerenv" ]; then     # 如果不在docker里
    #     config_sshd
    #     config_portforwarding           # ⚠️port转发2⚠️
    #     install_code_server             # ⚠️port转发3⚠️
    #     install_docker
    #     if command -v nvidia-smi > /dev/null; then
    #         install_nvidia_tools
    #     fi
    # fi
    echo "✨ ✨ INSTALLATION AND CONFIGURATION COMPLETE! ✨ ✨"
    echo "✨ ✨ 请重启系统以使配置生效."
    echo "✨ ✨ 新系统使用必读, 请查看 $LOGS_DIR/README_cfgOS.txt."
}
main_base
