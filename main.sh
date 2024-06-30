#!/bin/bash

function run_command() {
  wget -O "${1}" https://raw.githubusercontent.com/helvenk/node_scripts/master/"${1}" && chmod +x "${1}" && ./"${1}"
}

function run_command_daduge() {
  wget -O "${1}" https://raw.githubusercontent.com/a3165458/"${1}"/master/"${1}" && chmod +x "${1}" && ./"${1}"
}

function main_menu() {
  while true; do
    clear
    echo "=========两岸猿声啼不住，轻舟已过万重山。========="
    echo "请选择项目:"
    echo "--------------------节点类--------------------"
    echo "000. Airchains"
    echo "001. Nubit"
    echo "002. Aleo"
    echo "--------------------挖矿类--------------------"
    echo "--------------------已停用---------------------"
    echo "---------------------其他----------------------"
    echo "999. 更新脚本"
    echo "0. 退出脚本"
    read -p "请输入选项: " OPTION

    case $OPTION in

    000) run_command airchains.sh ;;
    001) run_command_daduge nubit.sh ;;
    002) run_command aleo.sh ;;

    999) wget -O node_scripts.sh https://bit.ly/4eULdS7 && chmod +x node_scripts.sh && ./node_scripts.sh ;;

    0)
      echo "退出脚本。"
      exit 0
      ;;
    *)
      echo "无效选项，请重新输入。"
      sleep 3
      ;;
    esac
    echo "按任意键返回主菜单..."
    read -n 1
  done
}

main_menu
