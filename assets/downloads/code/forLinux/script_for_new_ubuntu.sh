#!/bin/bash
# 环境：Ubuntu/WSL2，NVIDIA-GPU(默认已安装驱动，可以顺利使用命令nvidia-smi。)
# 使用方法：`bash config_script.sh [--in-container]`

# 0. 准备参数和最基础的安装包
in_container=false    # 默认要执行所有模块（即非容器的场景）
while [[ $# -gt 0 ]]; do
  case "$1" in
    --in-container)
      in_container=true
      shift
      ;;
    *)      # 忽略其他参数
      shift
      ;;
  esac
done

if [ -z "$(command -v sudo)" ]; then
  apt install sudo -y
else
  echo "- - - - already has sudo."
fi
sudo apt update
sudo apt install tzdata      # 时区包，cmake的依赖包。安装有交互，因此放在最前。

if [ -z "$(command -v update-ca-certificates)" ]; then
  sudo apt install ca-certificates -y
else
  echo "- - - - already has ca-certificates."
fi


# 1. 配置 apt 源（默认清华源）
codename=$(grep VERSION_CODENAME /etc/os-release | cut -d'=' -f2)
sources_list="/etc/apt/sources.list"
backup_sources_list="/etc/apt/sources.list.backup"

which_mirror="tsinghua"  # 可以设置为 "tsinghua" 或 "aliyun"

if grep -q "archive.ubuntu.com" "$sources_list"; then
  sudo cp "$sources_list" "$backup_sources_list"
  
  if [ "$which_mirror" == "tsinghua" ]; then
    sudo tee "$sources_list" > /dev/null <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename main restricted universe multiverse
#deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename main restricted universe multiverse

deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-updates main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-updates main restricted universe multiverse

deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-backports main restricted universe multiverse
#deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-backports main restricted universe multiverse

deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-security main restricted universe multiverse
#deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-security main restricted universe multiverse
EOF
  elif [ "$which_mirror" == "aliyun" ]; then
    sudo tee "$sources_list" > /dev/null <<EOF
#deb-src http://mirrors.aliyun.com/ubuntu/ $codename main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $codename main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $codename-security main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu/ $codename-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $codename-updates main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu/ $codename-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $codename-backports main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu/ $codename-backports main restricted universe multiverse
EOF
  else
    echo "- - - - - Invalid apt mirror choice."
    exit 1
  fi
  
else
  echo "Already using $which_mirror mirrors."
fi
sudo apt update
sudo apt upgrade -y


# 2. 安装基础软件包
check_and_install() {
  local package=$1
  if ! command -v $package &> /dev/null; then
    echo "- - - - - Installing $package..."    
    sudo apt install -y $package
  else
    echo "- - - - - $package is already installed."
  fi
}
    # 注：psmisc用于pstree
packages=("wget" "curl" "git" "vim" "net-tools" "iputils-ping" "htop" "tmux" 
"zsh" "kmod" "g++" "gcc" "cmake" "psmisc" "language-pack-en" "tree")
for package in "${packages[@]}"; do
  check_and_install $package
done


# 3. 安装 oh-my-zsh(前提：zsh已经安装了)
wget -O install_ohmyzsh.sh https://gitee.com/mirrors/ohmyzsh/raw/master/tools/install.sh
sed -i 's/REPO:-ohmyzsh\/ohmyzsh/REPO:-jamesray0713\/ohmyzsh/' install_ohmyzsh.sh
sed -i 's/REMOTE:-https:\/\/github/REMOTE:-https:\/\/gitee/' install_ohmyzsh.sh
sudo chmod +x install_ohmyzsh.sh
echo "yes" | ./install_ohmyzsh.sh -y
rm install_ohmyzsh.sh
    # 插件
cd ~/.oh-my-zsh/custom/plugins
git clone https://gitee.com/jamesray0713/zsh-autosuggestions
git clone https://gitee.com/jamesray0713/zsh-syntax-highlighting

sed -i 's/ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' ~/.zshrc
sed -i 's/plugins=(git)/plugins=( git zsh-autosuggestions zsh-syntax-highlighting )/' ~/.zshrc
    # 改抬头
sed -i 's/PROMPT+=.*/PROMPT+=\x27 %{$fg[cyan]%}[$PWD]%{$reset_color%} $(git_prompt_info)\x27/' ~/.oh-my-zsh/themes/robbyrussell.zsh-theme
    # 设为默认sh
echo 'if [ -t 1 ]; then exec zsh; fi' >> ~/.bashrc
source ~/.bashrc    # 注释掉也没毛病
#source ~/.zshrc    # bash中无法加载zsh配置
cd ~
echo "- - - - - ohmyzsh installed.  remember to modify 'pip source'."



if [ "$in_container" = true ]; then
  echo "- - - - - Finished! installed all 3 steps."
else


  # 4. 安装 Miniconda。可根据需求, 去tuna官网中查找合适的`file`，或直接用最新版`Miniconda3-latest-Linux-$arch.sh`
  arch=$(uname -m)
  file="Miniconda3-py39_23.5.2-0-Linux-$arch.sh"
  conda_dir="$HOME/Miniconda3"
  wget https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/$file
  echo "- - - - - miniconda-install.sh downloaded."
  bash $file -b -p $conda_dir
  rm $file
      # 因为是静默安装，要手动初始化conda。
  $conda_dir/bin/conda init
      # 但其init命令无法识别shell，只会自动对bash初始化。而此时我们是在zsh里执行的上一步，还需将初始化脚本复制到.zshrc。
  matched_content=$(awk '/# >>> conda initialize >>>/,/# <<< conda initialize <<<$/' ~/.bashrc)
  modified_content=$(echo "$matched_content" | sed 's/shell\.bash/shell.zsh/')
  echo "$modified_content" >> ~/.zshrc
      # 更新终端后，你能看到(base)的抬头了
  #source ~/.zshrc  # 脚本环境是bash，无法执行.zshrc

      # 配置 conda的清华源
  condarc_path=~/.condarc
  if [ ! -f "$condarc_path" ]; then
    touch "$condarc_path"
  fi
cat <<EOL > "$condarc_path"
channels:
  - defaults
show_channel_urls: true
default_channels:
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r
custom_channels:
  conda-forge: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
  msys2: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
  bioconda: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
  menpo: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
  pytorch: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
  simpleitk: https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
EOL
  #source ~/.zshrc
  echo "- - - - - miniconda3 is already installed."


  # 5.（可选）安装docker。如果想快速复现别人项目，这是必备的。
        ## 先安装docker engine
  if command -v docker >/dev/null 2>&1; then
    echo "- - - - - yes, have installed Docker Engine."
  else
    echo "- - - - - Installing Docker Engine."
    sudo apt install -y ca-certificates curl gnupg
    # 添加官方的gpgkey
    sudo mkdir -m 0755 -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # 设置软件库
    codename=$(grep VERSION_CODENAME /etc/os-release | cut -d'=' -f2)
    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$codename")" stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    # 安装docker引擎
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    source ~/.bashrc    # 注释掉也没毛病
    sudo service docker start
    # 使当前用户有足够的权限连接到 Docker 守护进程
    if [ "$(id -u)" != "0" ]; then
      sudo usermod -aG docker $USER
    fi
    echo "- - - - - $(docker -v)"
    
    docker run hello-world > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "- - - - - Successful! execuating 'docker hello world."
    fi  
  fi
      ## 后更换docker镜像源
  docker_config="/etc/docker/daemon.json"
  backup_suffix=".bak"
  if [ ! -d "/etc/docker" ]; then
    sudo mkdir -p /etc/docker
  fi

  if [ -f "$docker_config" ]; then
    if grep -q "mirror" "$docker_config"; then
      echo "We already have a Docker mirror configured."
    else
      sudo cp "$docker_config" "$docker_config$backup_suffix"
      echo "{\"registry-mirrors\": [\"https://a8wy8vas.mirror.aliyuncs.com\"]}" | sudo tee "$docker_config" > /dev/null
      echo "- - - - - Added a new Docker mirror."
    fi
  else
    echo "{\"registry-mirrors\": [\"https://a8wy8vas.mirror.aliyuncs.com\"]}" | sudo tee "$docker_config" > /dev/null
    echo "- - - - - Added a new Docker mirror."
  fi
  sudo service docker stop
  sudo service docker start



  # 6.（可选）深度学习基础配置—— 装NVIDIA Container Toolkit: 当想在容器里跑GPU，就得给本宿主机装 Toolkit
      # 建立package repository 和 GPG key
  if [ -f "/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg" ]; then
    echo "- - - - - we have already set a NVIDIA repository."
  else
    echo "- - - - - setting a NVIDIA repository..."
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
      && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
      && curl -s -L https://nvidia.github.io/libnvidia-container/experimental/$distribution/libnvidia-container.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
  fi
  sudo apt update 
      # 安装
  sudo apt install -y nvidia-container-toolkit
  echo "- - - - - installed.."
      # 设置Docker daemon 守护进程识别Nvidia容器Runtime
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo service docker restart
      # 测试。终端会输出你的GPU的算力。
  docker run --rm -it --gpus=all nvcr.io/nvidia/k8s/cuda-sample:nbody nbody -gpu -benchmark
  if [ $? -eq 0 ]; then
    echo "- - - - - Successfully installed toolkit."
  else
    echo "- - - - - Failed to install toolkit."
    exit 1
  fi

  echo "- - - - - Finished! installed all 6 steps."
fi



# 7. 安装vscode CLI。用于更便捷地进行远程开发
echo "- - - - - installing vscode CLI"
mkdir ~/packages
arch=$(uname -m)
if [ "$arch" == "x86_64" ]; then
  curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' --output ~/packages/vscode_cli.tar.gz
  tar -xf vscode_cli.tar.gz
else
    echo "- - - - - The arch is not x86_64, please install vscode CLI manually."
fi
