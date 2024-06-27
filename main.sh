#!/bin/bash

# 主菜单
function main_menu() {
  while true; do
    clear
    echo "=========两岸猿声啼不住，轻舟已过万重山。========="
    echo "请选择项目:"
    echo "--------------------节点类--------------------"
    echo "000. Airchains"
    echo "001. Nubit"
    echo "--------------------挖矿类--------------------"
    echo "--------------------已停用---------------------"
    echo "---------------------其他----------------------"
    echo "0. 退出脚本"
    read -p "请输入选项: " OPTION

    case $OPTION in

    000) wget -O airchains.sh https://raw.githubusercontent.com/helvenk/node_scripts/master/airchains.sh && chmod +x airchains.sh && ./airchains.sh ;;
    001) wget -O nubit.sh https://raw.githubusercontent.com/a3165458/nubit.sh/main/nubit.sh && chmod +x nubit.sh && ./nubit.sh ;;

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

# 显示主菜单
main_menu
