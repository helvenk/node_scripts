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

function install_pm2() {
  if command -v pm2 >/dev/null 2>&1; then
    echo "PM2 已安装"
  else
    echo "PM2 未安装，正在安装..."
    npm install pm2@latest -g
  fi
}
################## 检查 PM2 ########################

function view_doc() {
  URL="https://medium.com/@smeb_y/aleo-%E6%BF%80%E5%8A%B1%E6%B5%8B%E8%AF%95%E7%BD%91%E5%9B%BE%E6%96%87%E5%8F%82%E4%B8%8E%E6%95%99%E7%A8%8B-%E9%80%82%E7%94%A8%E4%BA%8E%E9%9A%BE%E6%B0%91%E9%85%8D%E7%BD%AE-2774420162b0"
  echo "教程地址：$URL"
  echo -e "\033]8;;$URL\033\\点此打开\033]8;;\033\\"
}

function view_logs() {
  pm2 logs aleo-pool-prover
}

function uninstall_node() {
  pm2 stop aleo-pool-prover
  rm -r aleo-pool-prover
}

function install_node() {
  install_nodejs_and_npm
  install_pm2

  wget -O aleo-pool-prover https://github.com/zkrush/aleo-pool-client/releases/download/v1.5-testnet-beta/aleo-pool-prover
  chmod +x aleo-pool-prover

  read -p "是否已在 zkrush 添加挖矿账户？(y/N): " choice
  if [[ "$choice" != "y" ]]; then
    echo "请添加挖矿账户后再重新运行命令：https://pool.zkrush.com/zh-hant/personal/miner"
    exit 0
  fi

  pool="wss://aleo.zkrush.com:3333"
  read -p "输入 zkrush 账户名称：" account
  read -p "输入 worker 名称(随便取一个，名字不要太短)：" worker

  pm2 start ./aleo-pool-prover --name "aleo-pool-prover" -- --pool $pool --account $account --worker-name $worker
}

function main_menu() {
  while true; do
    clear
    echo "脚本以及教程参考自推特用户大赌哥 @y95277777 ，免费开源，请勿相信收费"
    echo "======================= Aleo 矿池节点 ================================"
    echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
    echo "节点社区 Discord 社群:https://discord.gg/GbMV5EcNWF"
    echo "退出脚本，请按键盘ctrl c退出即可"
    echo "请选择要执行的操作:"
    echo "1. 安装节点"
    echo "2. 查看教程"
    echo "3. 查看日志"
    echo "4. 卸载节点 "
    read -p "请输入选项: " OPTION

    case $OPTION in
    1) install_node ;;
    2) view_doc ;;
    3) view_logs ;;
    4) uninstall_node ;;
    *) echo "无效选项。" ;;
    esac
    echo "按任意键返回主菜单..."
    read -n 1
  done

}

main_menu
