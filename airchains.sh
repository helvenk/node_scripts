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

if command -v junctiond >/dev/null 2>&1; then
  echo "junctiond 已安装，跳过安装步骤。"
else
  echo "安装 junctiond..."
  wget https://github.com/airchains-network/junction/releases/download/v0.1.0/junctiond
  chmod +x junctiond
  sudo mv junctiond /usr/local/bin
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
  fi
  echo "123" | eigenlayer operator keys create --key-type ecdsa --insecure wallet

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

  echo "初始化 prover"
  go run cmd/main.go prover v1WASM

  # 定义文件路径
  AIR_KEY="$HOME/.tracks/junction-accounts/keys/wallet.wallet.json"
  # 检查文件是否存在
  if [ -f "$AIR_KEY" ]; then
    echo "AIR 钱包文件 $AIR_KEY 已存在，删除文件"
    rm -f "$AIR_KEY"
  fi
  # 执行创建密钥命令
  go run cmd/main.go keys junction --accountName wallet --accountPath $HOME/.tracks/junction-accounts/keys

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

  echo "请进入 DC 频道 https://discord.gg/airchains"
  echo "发送命令 \$faucet $AIR_ADDRESS 进行领水"
  echo ""
  echo "或者进入 https://airchains.faucetme.pro/ 连接 DC 后"
  echo "输入地址 $AIR_ADDRESS 领水"
  echo ""

  # 询问用户是否要继续执行
  read -p "是否已经领水完毕要继续执行？(yes/no): " choice

  if [[ "$choice" != "yes" ]]; then
    echo "脚本已终止。"
    exit 0
  fi

  # 如果用户选择继续，则执行以下操作
  echo "继续执行脚本..."

  # 询问用户是否要继续执行
  read -p "请输入 RPC 地址？(直接回车使用默认值 $JSON_RPC): " rpc_input

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
  sed -i 's/gasFees := fmt.Sprintf("%damf", gas)/gasFees := fmt.Sprintf("%damf", 3*gas)/' "$HOME/tracks/junction/verifyPod.go"
  sed -i 's/gasFees := fmt.Sprintf("%damf", gas)/gasFees := fmt.Sprintf("%damf", 3*gas)/' "$HOME/tracks/junction/validateVRF.go"
  sed -i 's/gasFees := fmt.Sprintf("%damf", gas)/gasFees := fmt.Sprintf("%damf", 4*gas)/' "$HOME/tracks/junction/submitPod.go"

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
  restart_node

  echo "创建刷 TX 脚本..."
  cd
  create_tx_script

  echo "创建 station 监控脚本..."
  cd
  create_station_script
}

function create_tx_script() {
  NAME="airchains_tx"
  screen -X -S $NAME quit

  addr=$($HOME/wasm-station/build/wasmstationd keys show node --keyring-backend test -a)
  command="while true; do \
  $HOME/wasm-station/build/wasmstationd tx bank send node ${addr} 1stake --from node --chain-id station-1 --keyring-backend test -y; \
  sleep \$((RANDOM % 3 + 2)); \
  done"

  screen -dmS "$NAME" bash -c "$command"
  echo "请使用 screen -r $NAME 查看日志"
}

function create_station_script() {
  NAME="airchains_station"
  screen -X -S $NAME quit

  #   command='
  # service_name="stationd"
  # gas_string="with gas used"
  # restart_delay=180  # Restart delay in seconds (3 minutes)

  # echo "Script started and it will rollback $service_name if needed..."
  # while true; do
  #   # Get the last 10 lines of service logs
  #   logs=$(systemctl status "$service_name" --no-pager | tail -n 30)

  #   # 检查日志是否每一行都不包含 "module=junction txHash=" 并且每一行都包含 "INF New Block Found module=blocksync"
  #   if ! echo "$logs" | grep -q "module=junction txHash=" && echo "$logs" | grep -q "INF New Block Found module=blocksync"; then
  #     # 如果满足条件，则输出消息和时间戳
  #     echo "[$(date)] No txHash found and all lines contain INF New Block Found, restarting stationd service..."
  #     # 重启服务
  #     sudo systemctl restart wasmstationd.service
  #     sudo systemctl restart stationd.service
  #     # 输出重启服务的时间戳
  #     echo "[$(date)] stationd service restarted."
  #   fi

  #   # Check for both error and gas used strings
  #   if [[ "$logs" =~ $gas_string ]]; then
  #     echo "Found error and gas used in logs, stopping $service_name..."
  #     systemctl stop "$service_name"
  #     cd ~/tracks

  #     echo "Service $service_name stopped, starting rollback..."
  #     go run cmd/main.go rollback
  #     go run cmd/main.go rollback
  #     go run cmd/main.go rollback
  #     echo "Rollback completed, starting $service_name..."
  #     systemctl start "$service_name"
  #     echo "Service $service_name started"
  #   fi

  #   # Sleep for the restart delay
  #   sleep "$restart_delay"
  # done'

  command=$(
    cat <<'EOF'
SERV_NAME="stationd.service"
ERR1="rpc error: code = Unavailable desc = incorrect pod number"
ERR2="rpc error: code = Unknown desc = failed to execute message"
ERR3="Failed to Init VRF"
ERR4="Failed to unmarshal transaction"
ERR5="Failed to Transact Verify pod"
ERR6="VRF record is nil"
ERR7="Failed to Validate VRF"
ALL_ERRS="$ERR1|$ERR2|$ERR3|$ERR4|$ERR5|$ERR6|$ERR7"

function rollback_restart() {
  echo "Stopping..."
  systemctl stop $SERV_NAME
  cd ~/tracks
  roll_times=$((RANDOM % 3 + 1))
  echo "Rolling back $roll_times pods..."
  for ((i = 0; i < $roll_times; i++)); do
    go run ./cmd/main.go rollback
  done
  echo "Restarting..."
  systemctl restart $SERV_NAME
}

while true; do
  log_lines=$(journalctl -u ${SERV_NAME} -n 10)
  last_log_ts=$(($(journalctl --no-pager --output=json -n 1 -u $SERV_NAME | jq -r '.["__REALTIME_TIMESTAMP"]') / 1000000))
  now_ts=$(date +"%s")
  wait_time=$((now_ts - last_log_ts))
  if echo "$log_lines" | grep -Eq "$ALL_ERRS"; then
    echo "Error detected!"
    rollback_restart
  elif [ $wait_time -gt 600 ]; then
    "Long wait!"
    rollback_restart
  else
    echo "listening......"
  fi
  sleep 60
done
EOF
  )

  screen -dmS "$NAME" bash -c "$command"
  echo "请使用 screen -r $NAME 查看日志"
}

function create_balance_script() {
  NAME="airchains_notify"
  screen -X -S $NAME quit

  RPC=$(grep -oP 'JunctionRPC = "\K[^"]*' $HOME/.tracks/config/sequencer.toml)
  ADDR=$(jq -r '.address' $HOME/.tracks/junction-accounts/keys/wallet.wallet.json)

  read -p "输入你的 bark key: " key

  command='while true; do 
  output=$(junctiond query bank balances '"$ADDR"' --node '"$RPC"') 
  amount=$(echo $output | grep -oP "(?<=amount: \")[0-9]+")
  amount=$(awk "BEGIN {printf \"%.6f\", $((amount)) / 1000000}")
  if [ "$amount" -lt 0.1 ]; then 
    curl -X POST https://api.day.app/'"$key"' -d"title=Airchains&body=包租婆没水啦 '"$ADDR"'&copy='"$ADDR"'"; 
  fi 
  sleep 300; 
done'

  screen -dmS "$NAME" bash -c "$command"
  echo "请使用 screen -r $NAME 查看日志"
}

function stationd_log() {
  journalctl -u stationd -f --no-hostname -o cat
}

function wasmstationd_log() {
  journalctl -u wasmstationd -f --no-hostname -o cat
}

function wallet_info() {
  echo ""
  echo "Airchains"
  AIR_KEY=$HOME/.tracks/junction-accounts/keys/wallet.wallet.json
  echo "助记词: $(jq -r '.mnemonic' $AIR_KEY)"
  echo "地址: $(jq -r '.address' $AIR_KEY)"
}

function restart_node() {
  sudo systemctl restart wasmstationd.service
  sudo systemctl restart stationd.service
}

function query_reward() {
  AIR_KEY=$HOME/.tracks/junction-accounts/keys/wallet.wallet.json
  addr=$(jq -r '.address' $AIR_KEY)
  output=$(curl -s 'https://points.airchains.io/api/rewards-table' \
    -H 'accept: */*' \
    -H 'accept-language: zh,zh-CN;q=0.9,en;q=0.8' \
    -H 'content-type: application/json' \
    -H 'origin: https://points.airchains.io' \
    -H 'priority: u=1, i' \
    -H 'referer: https://points.airchains.io/' \
    -H 'sec-ch-ua: "Not/A)Brand";v="8", "Chromium";v="126", "Google Chrome";v="126"' \
    -H 'sec-ch-ua-mobile: ?0' \
    -H 'sec-ch-ua-platform: "Windows"' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: same-origin' \
    -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36' \
    --data-raw "{\"address\":\"$addr\"}")

  echo -e "\naddress: $addr"
  id=$(echo "$output" | jq -r '.data.stations[0].station_id')
  pod=$(echo "$output" | jq -r '.data.stations[0].latest_pod')
  points=$(echo "$output" | jq -r '.data.stations[0].points')
  echo "station_id: $id"
  echo "latest_pod: $pod"
  echo "points: $points"
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

function change_rpc() {
  CONFIG_PATH="$HOME/.tracks/config/sequencer.toml"
  read -p "输入新的 RPC: " rpc
  if [[ "$rpc" != "" ]]; then
    sed -i "s#JunctionRPC = \".*#JunctionRPC = \"$rpc\"#" $CONFIG_PATH
  fi
  echo "修改成功，重启节点..."
  restart_node
}

function query_balance() {
  RPC=$(grep -oP 'JunctionRPC = "\K[^"]*' $HOME/.tracks/config/sequencer.toml)
  ADDRESS=$(jq -r '.address' $HOME/.tracks/junction-accounts/keys/wallet.wallet.json)

  output=$(junctiond query bank balances $ADDRESS --node $RPC)
  amount=$(echo $output | grep -oP '(?<=amount: ")[0-9]+')
  amount=$(awk "BEGIN {printf \"%.6f\", $((amount)) / 1000000}")
  echo "地址：$ADDRESS"
  echo "余额：$amount AMF"
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
    echo "2. 查看 wasmstationd 状态"
    echo "3. 查看 stationd 状态"
    echo "4. 查看积分"
    echo "5. 导出钱包信息"
    echo "6. 查看余额"
    echo "7. 重启节点"
    echo "8. 回滚 stationd"
    echo "9. 修改 RPC"
    echo "10. 创建刷 tx 脚本"
    echo "11. 创建 stationd 监听脚本"
    echo "12. 创建余额通知脚本"
    echo "13. 删除节点"
    read -p "请输入选项: " OPTION

    case $OPTION in
    1) install_node ;;
    2) wasmstationd_log ;;
    3) stationd_log ;;
    4) query_reward ;;
    5) wallet_info ;;
    6) query_balance ;;
    7) restart_node ;;
    8) rollback ;;
    9) change_rpc ;;
    10) create_tx_script ;;
    11) create_station_script ;;
    12) create_balance_script ;;
    13) delete_node ;;
    *) echo "无效选项。" ;;
    esac
    echo "按任意键返回主菜单..."
    read -n 1
  done

}

# 显示主菜单
main_menu
