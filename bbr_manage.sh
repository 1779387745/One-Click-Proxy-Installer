#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

while true; do
    clear
    echo -e "${CYAN}BBR管理："
    bbr_status=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr && echo 已开启 || echo 未开启)
    echo -e "当前BBR状态：${GREEN}$bbr_status${NC}"
    echo "  1. 开启BBR"
    echo "  2. 关闭BBR"
    echo "  0. 返回"
    read -p "请输入选项 [0-2]: " bbr_opt
    case "$bbr_opt" in
        1)
            sudo modprobe tcp_bbr
            echo 'net.core.default_qdisc=fq' | sudo tee -a /etc/sysctl.conf
            echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.conf
            sudo sysctl -p
            echo "BBR已开启。"
            ;;
        2)
            sudo sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
            sudo sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
            sudo sysctl -p
            echo "BBR已关闭。"
            ;;
        0)
            break
            ;;
        *)
            echo "操作已取消。"
            ;;
    esac
    read -n 1 -s -r -p "按任意键返回..."
done 
