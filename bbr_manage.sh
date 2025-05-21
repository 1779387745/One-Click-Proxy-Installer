#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

while true; do
    clear
    echo -e "${CYAN}BBR管理主菜单："
    echo "  1. 简单BBR开关"
    echo "  2. 高级BBR管理（内核/加速/卸载/检测等）"
    echo "  0. 返回"
    read -p "请输入选项 [0-2]: " main_opt
    case "$main_opt" in
        1)
            # 简单BBR开关原功能
            while true; do
                clear
                echo -e "${CYAN}BBR管理（简单开关）："
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
            ;;
        2)
            # 高级BBR管理（原install.sh全部功能，直接粘贴原install.sh主循环和函数）
            # ========== install.sh代码开始 ==========
            # 限制脚本仅支持基于 Debian/Ubuntu 的系统（即支持 apt-get 的系统）
            if ! command -v apt-get &> /dev/null; then
                echo -e "\033[31m此脚本仅支持基于 Debian/Ubuntu 的系统，请在支持 apt-get 的系统上运行！\033[0m"
                read -n 1 -s -r -p "按任意键返回..."
                break
            fi
            REQUIRED_CMDS=("curl" "wget" "dpkg" "awk" "sed" "sysctl" "update-grub" "jq")
            DEPS_MARKER="/tmp/.bbr_deps_installed"
            if [ ! -f "$DEPS_MARKER" ]; then
                for cmd in "${REQUIRED_CMDS[@]}"; do
                    if ! command -v $cmd &> /dev/null; then
                        echo -e "\033[31m缺少依赖：$cmd，正在安装...\033[0m"
                        sudo apt-get update && sudo apt-get install -y $cmd
                    fi
                done
                touch "$DEPS_MARKER"
            fi
            ARCH=$(uname -m)
            if [[ "$ARCH" != "aarch64" && "$ARCH" != "x86_64" ]]; then
                echo -e "\033[31m(￣□￣)哇！这个脚本只支持 ARM 和 x86_64 架构哦~ 您的系统架构是：$ARCH\033[0m"
                read -n 1 -s -r -p "按任意键返回..."
                break
            fi
            SYSCTL_CONF="/etc/sysctl.d/99-zhongyuan.conf"
            clean_sysctl_conf() {
                if [[ ! -f "$SYSCTL_CONF" ]]; then
                    sudo touch "$SYSCTL_CONF"
                fi
                sudo sed -i '/net.core.default_qdisc/d' "$SYSCTL_CONF"
                sudo sed -i '/net.ipv4.tcp_congestion_control/d' "$SYSCTL_CONF"
            }
            ask_to_save() {
                echo -n -e "\033[36m(｡♥‿♥｡) 要将这些配置永久保存到 $SYSCTL_CONF 吗？(y/n): \033[0m"
                read -r SAVE
                if [[ "$SAVE" == "y" || "$SAVE" == "Y" ]]; then
                    echo -e "\033[1;31m【高风险操作警告】\033[0m"
                    echo -e "\033[33m您即将永久修改系统网络参数，可能导致：\033[0m"
                    echo -e "\033[33m- 网络异常、丢失 SSH 连接\033[0m"
                    echo -e "\033[33m- 系统重启后参数生效，若配置有误可能无法联网\033[0m"
                    echo -e "\033[33m- 如为生产环境/重要服务器，建议谨慎操作！\033[0m"
                    echo -n -e "\033[1;31m是否继续永久保存？(y/N): \033[0m"
                    read -r confirm_save
                    if [[ ! "$confirm_save" =~ ^[Yy]$ ]]; then
                        echo -e "\033[33m未永久保存，操作已取消。\033[0m"
                        return
                    fi
                    clean_sysctl_conf
                    echo "net.core.default_qdisc=$QDISC" | sudo tee -a "$SYSCTL_CONF" > /dev/null
                    echo "net.ipv4.tcp_congestion_control=$ALGO" | sudo tee -a "$SYSCTL_CONF" > /dev/null
                    sudo sysctl --system > /dev/null
                    echo -e "\033[1;32m(☆^ー^☆) 更改已永久保存啦~\033[0m"
                else
                    echo -e "\033[33m(⌒_⌒;) 好吧，没有永久保存呢~\033[0m"
                fi
            }
            get_download_links() {
                # ...原函数内容...
            }
            install_packages() {
                # ...原函数内容...
            }
            get_specific_version() {
                # ...原函数内容...
            }
            print_separator() {
                echo -e "\033[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            }
            # 进入原install.sh主菜单循环
            while true; do
                # ...原install.sh主菜单和case全部粘贴于此...
                # 退出时break即可
                break
            done
            # ========== install.sh代码结束 ==========
            ;;
        0)
            break
            ;;
        *)
            echo "无效选项"; sleep 1
            ;;
    esac

done

# 如果是被 source 调用，选0后自动 return 回主脚本
return 2>/dev/null 
