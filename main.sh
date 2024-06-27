#!/bin/bash

# 主菜单
function main_menu() {
  while true; do
    clear
    echo "=========两岸猿声啼不住，轻舟已过万重山。========="
    echo "请选择项目:"
    echo "--------------------节点类项目--------------------"
    echo "000. Airchains 一键部署"
    echo "--------------------挖矿类项目--------------------"
    echo "503. Spectre(CPU) 一键挖矿"
    echo "110. Titan Network 一键挖矿"
    echo "---------------------已停项目---------------------"
    echo "107. Taiko 一键部署[已停用]"
    echo "501. ORE(CPU) -v1 挖矿脚本[已停用]"
    echo "502. ORE(GPU) -v1 挖矿脚本[已停用]"
    echo "101. Babylon 一键部署"
    echo "-----------------------其他----------------------"
    echo "0. 退出脚本"
    read -p "请输入选项: " OPTION

    case $OPTION in

    000) wget -O airchains.sh https://raw.githubusercontent.com/helvenk/node_scripts/master/airchains.sh && chmod +x airchains.sh && ./airchains.sh ;;

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
