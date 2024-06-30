# 脚本命令备忘

################# 检查 root ########################
if [ "$(id -u)" != "0" ]; then
  echo "此脚本需要以root用户权限运行。"
  echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
  exit 1
fi
################# 检查 root ########################

################# 检查 git ########################
if ! command -v git &>/dev/null; then
  # 如果 Git 未安装，则进行安装
  echo "未检测到 Git，正在安装..."
  sudo apt install git -y
else
  # 如果 Git 已安装，则不做任何操作
  echo "Git 已安装。"
fi
################# 检查 git ########################

################# 检查 go ########################
if command -v go >/dev/null 2>&1; then
  echo "Go 环境已安装"
else
  echo "Go 环境未安装，正在安装..."
  sudo rm -rf /usr/local/go
  curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
  echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >>$HOME/.bash_profile
  source $HOME/.bash_profile
  go version
fi

################# 检查 go ########################

################ 检查 nodejs #######################
function install_nodejs_and_npm() {
  if command -v node >/dev/null 2>&1; then
    echo "Node.js 已安装"
  else
    echo "Node.js 未安装，正在安装..."
    curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    sudo apt-get install -y nodejs
  fi

  if command -v npm >/dev/null 2>&1; then
    echo "npm 已安装"
  else
    echo "npm 未安装，正在安装..."
    sudo apt-get install -y npm
  fi
}
################ 检查 nodejs #######################

################## 检查 PM2 ########################
function install_pm2() {
  if command -v pm2 >/dev/null 2>&1; then
    echo "PM2 已安装"
  else
    echo "PM2 未安装，正在安装..."
    npm install pm2@latest -g
  fi
}
################## 检查 PM2 ########################

################## 查看教程 ########################
function view_doc() {
  URL="https://medium.com/@smeb_y"
  echo "教程地址：$URL"
  echo -e "\033]8;;$URL\033\\点此打开\033]8;;\033\\"
}
################## 查看教程 ########################

################## 创建后台定时脚本 #################
function create_screen_script() {
  NAME="xxx"
  screen -X -S $NAME quit

  echo '#!/bin/bash

while true; do
  echo "running"
  sleep 6
done' | sudo tee "$NAME.sh"
  screen -dmS "$NAME" bash "./$NAME.sh"
  echo "请使用 screen -r $NAME 查看日志"
}
################## 创建后台定时脚本 #################

#################### 主菜单 ######################
function main_menu() {
  while true; do
    clear
    echo "脚本以及教程参考自推特用户大赌哥 @y95277777 ，免费开源，请勿相信收费"
    echo "======================= xxx节点安装 ================================"
    echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
    echo "节点社区 Discord 社群:https://discord.gg/GbMV5EcNWF"
    echo "退出脚本，请按键盘ctrl c退出即可"
    echo "请选择要执行的操作:"
    echo "1. 安装节点"
    echo "2. 查看教程"
    echo "3. 查看钱包"
    echo "4. 删除节点"
    read -p "请输入选项: " OPTION

    case $OPTION in
    1) install_node ;;
    2) view_doc ;;
    3) view_wallet ;;
    4) delete_node ;;
    *) echo "无效选项。" ;;
    esac
    echo "按任意键返回主菜单..."
    read -n 1
  done

}

main_menu
#################### 主菜单 ######################
