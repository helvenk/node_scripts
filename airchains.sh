#!/bin/bash

# 检查是否已安装 build-essential
if dpkg-query -W build-essential >/dev/null 2>&1; then
  echo "build-essential 已安装，跳过安装步骤。"
else
  echo "安装 build-essential..."
  sudo apt update
  sudo apt install -y build-essential
fi

# 检查是否已安装 git
if command -v git >/dev/null 2>&1; then
  echo "git 已安装，跳过安装步骤。"
else
  echo "安装 git..."
  sudo apt update
  sudo apt install -y git
fi

# 检查是否已安装 jq
if command -v jq >/dev/null 2>&1; then
  echo "jq 已安装，跳过安装步骤。"
else
  echo "安装 jq..."
  sudo apt update
  sudo apt install -y jq
fi

# 检查是否已安装 screen
if command -v screen >/dev/null 2>&1; then
  echo "screen 已安装，跳过安装步骤。"
else
  echo "安装 screen..."
  sudo apt update
  sudo apt install -y screen
fi

# 检查是否已安装 go
if command -v go >/dev/null 2>&1; then
  echo "go 已安装，跳过安装步骤。"
else
  echo "下载并安装 Go..."
  wget -c https://golang.org/dl/go1.22.4.linux-amd64.tar.gz -O - | sudo tar -xz -C /usr/local
  echo 'export PATH=$PATH:/usr/local/go/bin' >>~/.bash_profile
  source ~/.bash_profile
fi

# 验证安装后的 Go 版本
echo "当前 Go 版本："
go version

function install_node() {
  cd $HOME
  echo "下载 Github 仓库"
  git clone https://github.com/airchains-network/wasm-station.git
  git clone https://github.com/airchains-network/tracks.git

  echo "设置 Wasm Station"
  cd wasm-station
  go mod tidy
  /bin/bash ./scripts/local-setup.sh

  sudo tee /etc/systemd/system/wasmstationd.service <<EOF >/dev/null
[Unit]
Description=wasmstationd
After=network.target

[Service]
User=$USER
ExecStart=$HOME/wasm-station/build/wasmstationd start --api.enable
Restart=always
RestartSec=3
LimitNOFILE=10000

[Install]
WantedBy=multi-user.target
EOF

  echo "运行 Wasm Station"
  sudo systemctl daemon-reload &&
    sudo systemctl enable wasmstationd &&
    sudo systemctl start wasmstationd

  cd
  echo "设置 DA"
  wget https://github.com/airchains-network/tracks/releases/download/v0.0.2/eigenlayer
  sudo chmod +x eigenlayer
  sudo mv eigenlayer /usr/local/bin/eigenlayer
  # 定义文件路径
  EIGEN_KEY="$HOME/.eigenlayer/operator_keys/wallet.ecdsa.key.json"
  # 检查文件是否存在
  if [ -f "$EIGEN_KEY" ]; then
    echo "DA 钱包文件 $EIGEN_KEY 已存在，删除文件"
    rm -f "$EIGEN_KEY"
  else
    echo "DA 钱包文件 $EIGEN_KEY 不存在，执行创建密钥操作"
    # 执行创建密钥命令
    echo "123" | eigenlayer operator keys create --key-type ecdsa --insecure wallet
  fi

  sudo rm -rf ~/.tracks
  cd $HOME/tracks
  go mod tidy

  # 提示用户输入公钥和节点名
  read -p "请输入上面显示的 Public Key hex: " dakey
  read -p "请输入节点名: " moniker

  # 执行 Go 命令，替换用户输入的值
  go run cmd/main.go init \
    --daRpc "disperser-holesky.eigenda.xyz" \
    --daKey "$dakey" \
    --daType "eigen" \
    --moniker "$moniker" \
    --stationRpc "http://127.0.0.1:26657" \
    --stationAPI "http://127.0.0.1:1317" \
    --stationType "wasm"

  # 定义文件路径
  AIR_KEY="$HOME/.tracks/junction-accounts/keys/wallet.wallet.json"
  # 检查文件是否存在
  if [ -f "$AIR_KEY" ]; then
    echo "AIR 钱包文件 $AIR_KEY 已存在，删除文件"
    rm -f "$AIR_KEY"
  else
    echo "AIR 钱包文件 $AIR_KEY 不存在，执行创建密钥操作"
    # 执行创建密钥命令
    go run cmd/main.go keys junction --accountName wallet --accountPath $HOME/.tracks/junction-accounts/keys
  fi

  echo "初始化 prover"
  go run cmd/main.go prover v1WASM

  CONFIG_PATH="$HOME/.tracks/config/sequencer.toml"

  # 从配置文件中提取 nodeid
  NODE_ID=$(grep 'node_id =' $CONFIG_PATH | awk -F'"' '{print $2}')

  # 从钱包文件中提取 air 开头的钱包地址
  AIR_ADDRESS=$(jq -r '.address' $AIR_KEY)

  # 获取本机 IP 地址
  LOCAL_IP=$(hostname -I | awk '{print $1}')

  # 定义 JSON RPC URL 和其他参数
  JSON_RPC="https://airchains-rpc.kubenode.xyz/"
  INFO="WASM Track"
  TRACKS="air_address"
  BOOTSTRAP_NODE="/ip4/$LOCAL_IP/tcp/2300/p2p/$NODE_ID"

  echo "请进入 DC 频道 https://discord.com/channels/1116269224449548359/1238910689188511835"
  echo "发送命令 \$faucet $AIR_ADDRESS 进行领水\n"
  echo "或者进入 https://airchains.faucetme.pro/ 连接 DC 后输入地址 $AIR_ADDRESS 领水"

  # 询问用户是否要继续执行
  read -p "是否已经领水完毕要继续执行？(yes/no): " choice

  if [[ "$choice" != "yes" ]]; then
    echo "脚本已终止。"
    exit 0
  fi

  # 如果用户选择继续，则执行以下操作
  echo "继续执行脚本..."

  # 询问用户是否要继续执行
  read -p "请输入 RPC 地址？(默认值$JSON_RPC): " rpc_input

  if [[ "$rpc_input" != "" ]]; then
    JSON_RPC = $rpc_input
  fi

  echo "使用 RPC: $JSON_RPC"

  # 运行 tracks create-station 命令
  create_station_cmd="go run cmd/main.go create-station \
    --accountName wallet \
    --accountPath $HOME/.tracks/junction-accounts/keys \
    --jsonRPC \"$JSON_RPC\" \
    --info \"$INFO\" \
    --tracks \"$AIR_ADDRESS\" \
    --bootstrapNode \"/ip4/$LOCAL_IP/tcp/2300/p2p/$NODE_ID\""

  echo "修改默认的 gas price"
  sed -i 's/gasFees := fmt.Sprintf("%damf", gas)/gasFees := fmt.Sprintf("%damf", 2*gas)/' "$HOME/tracks/junction/verifyPod.go"
  sed -i 's/gasFees := fmt.Sprintf("%damf", gas)/gasFees := fmt.Sprintf("%damf", 2*gas)/' "$HOME/tracks/junction/validateVRF.go"
  sed -i 's/gasFees := fmt.Sprintf("%damf", gas)/gasFees := fmt.Sprintf("%damf", 3*gas)/' "$HOME/tracks/junction/submitPod.go"

  echo "创建 station"
  echo "$create_station_cmd"

  # 执行命令
  eval "$create_station_cmd"
  sudo tee /etc/systemd/system/stationd.service >/dev/null <<EOF
[Unit]
Description=station track service
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/tracks/
ExecStart=$(which go) run cmd/main.go start
Restart=always
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

  echo "启动 station"
  sudo systemctl daemon-reload
  sudo systemctl enable stationd
  sudo systemctl restart stationd

  echo "创建刷 TX 脚本"
  cd
  addr=$($HOME/wasm-station/build/wasmstationd keys show node --keyring-backend test -a)
  sudo tee tx.sh >/dev/null <<EOF
#!/bin/bash

while true; do
  $HOME/wasm-station/build/wasmstationd tx bank send node ${addr} 1stake --from node --chain-id station-1 --keyring-backend test -y 
  sleep 6  # Add a sleep to avoid overwhelming the system or network
done
EOF
  screen -dmS tx bash tx.sh
}

function stationd_log() {
  journalctl -u stationd -f
}

function wasmstationd_log() {
  journalctl -u wasmstationd -f
}

function private_key() {
  #evmos私钥#
  cd $HOME/data/airchains/evm-station/ && /bin/bash ./scripts/local-keys.sh
  #airchain助记词#
  cat $HOME/.tracks/junction-accounts/keys/wallet.wallet.json

}

function restart_node() {
  sudo systemctl restart wasmstationd.service
  sudo systemctl restart stationd.service
}

function rollback() {
  sudo systemctl stop stationd
  cd ~/tracks
  git pull
  go run cmd/main.go rollback
  go run cmd/main.go rollback
  go run cmd/main.go rollback
  sudo systemctl restart stationd
  sudo journalctl -u stationd -f --no-hostname -o cat
}

function delete_node() {
  sudo systemctl stop wasmstationd.service
  sudo systemctl stop stationd.service
  sudo systemctl disable wasmstationd.service
  sudo systemctl disable stationd.service
  sudo pkill -9 wasmstationd
  sudo pkill -9 stationd
  sudo rm -rf .wasmstationd
  sudo rm -rf .tracks
  sudo journalctl --vacuum-time=1s

}

# 主菜单
function main_menu() {
  while true; do
    clear
    echo "请选择要执行的操作:"
    echo "1. 安装节点"
    echo "2. 查看wasmstationd状态"
    echo "3. 查看stationd状态"
    echo "4. 导出所有私钥"
    echo "5. 重启节点"
    echo "6. 回滚 stationd"
    echo "6. 删除节点"
    read -p "请输入选项（1-7）: " OPTION

    case $OPTION in
    1) install_node ;;
    2) wasmstationd_log ;;
    3) stationd_log ;;
    4) private_key ;;
    5) restart_node ;;
    6) rollback ;;
    7) delete_node ;;
    *) echo "无效选项。" ;;
    esac
    echo "按任意键返回主菜单..."
    read -n 1
  done

}

# 显示主菜单
main_menu
