#!/bin/bash

# 限制脚本仅支持基于 Debian/Ubuntu 的系统（即支持 apt-get 的系统）
if ! command -v apt-get &> /dev/null; then
    echo -e "\033[31m此脚本仅支持基于 Debian/Ubuntu 的系统，请在支持 apt-get 的系统上运行！\033[0m"
    exit 1
fi

# 检查并安装必要的依赖，包括 jq 用于解析 JSON
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

# 检测系统架构
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" && "$ARCH" != "x86_64" ]]; then
    echo -e "\033[31m(￣□￣)哇！这个脚本只支持 ARM 和 x86_64 架构哦~ 您的系统架构是：$ARCH\033[0m"
    exit 1
fi

# 获取当前 BBR 状态
CURRENT_ALGO=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
CURRENT_QDISC=$(sysctl net.core.default_qdisc | awk '{print $3}')

# sysctl 配置文件路径
SYSCTL_CONF="/etc/sysctl.d/99-zhongyuan.conf"

# 函数：清理 sysctl.d 中的旧配置
clean_sysctl_conf() {
    if [[ ! -f "$SYSCTL_CONF" ]]; then
        sudo touch "$SYSCTL_CONF"
    fi
    sudo sed -i '/net.core.default_qdisc/d' "$SYSCTL_CONF"
    sudo sed -i '/net.ipv4.tcp_congestion_control/d' "$SYSCTL_CONF"
}

# 函数：询问是否永久保存更改
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

# 函数：从 GitHub 获取最新版本并下载
get_download_links() {
    echo -e "\033[36m正在从 GitHub 获取最新版本信息...\033[0m"
    BASE_URL="https://api.github.com/repos/byJoey/Actions-bbr-v3/releases"
    RELEASE_DATA=$(curl -s "$BASE_URL")

    if [[ "$ARCH" == "aarch64" ]]; then
        TAG_NAME=$(echo "$RELEASE_DATA" | jq -r 'sort_by(.published_at) | reverse | .[] | select(.tag_name | contains("arm64")) | .tag_name' | head -n1)
    elif [[ "$ARCH" == "x86_64" ]]; then
        TAG_NAME=$(echo "$RELEASE_DATA" | jq -r 'sort_by(.published_at) | reverse | .[] | select(.tag_name | contains("x86_64")) | .tag_name' | head -n1)
    fi

    if [[ -z "$TAG_NAME" ]]; then
        echo -e "\033[31m未找到适合当前架构的版本。\033[0m"
        exit 1
    fi

    echo -e "\033[36m找到的最新版本：$TAG_NAME\033[0m"
    ASSET_URLS=$(echo "$RELEASE_DATA" | jq -r --arg tag "$TAG_NAME" '.[] | select(.tag_name == $tag) | .assets[].browser_download_url')

    for URL in $ASSET_URLS; do
        FILE=$(basename "$URL")
        echo -e "\033[36m正在下载文件：$URL\033[0m"
        wget "$URL" -P /tmp/ || { echo -e "\033[31m下载失败：$URL\033[0m"; exit 1; }
    done
}

# 函数：安装下载的包
install_packages() {
    echo -e "\033[36m开始安装下载的包...\033[0m"
    sudo dpkg -i /tmp/linux-*.deb
    sudo update-grub
    echo -e "\033[36m安装完成，请手动重启系统以加载新内核（本脚本已禁用自动重启，确保安全）。\033[0m"
    echo -e "\033[33m请手动输入 \033[1;32mreboot\033[0m\033[33m 命令以重启服务器！\033[0m"
    read -n 1 -s -r -p "按任意键返回..."
}

# 函数：安装指定版本
get_specific_version() {
    BASE_URL="https://api.github.com/repos/byJoey/Actions-bbr-v3/releases"
    RELEASE_DATA=$(curl -s "$BASE_URL")

    if [[ "$ARCH" == "aarch64" ]]; then
        MATCH_TAGS=$(echo "$RELEASE_DATA" | jq -r '.[] | select(.tag_name | contains("arm64")) | .tag_name')
    else
        MATCH_TAGS=$(echo "$RELEASE_DATA" | jq -r '.[] | select(.tag_name | contains("x86_64")) | .tag_name')
    fi

    if [[ -z "$MATCH_TAGS" ]]; then
        echo -e "\033[31m未找到适合当前架构的版本。\033[0m"
        exit 1
    fi

    echo -e "\033[36m以下为适用于当前架构的版本：\033[0m"
    IFS=$'\n' read -rd '' -a TAG_ARRAY <<<"$MATCH_TAGS"

    for i in "${!TAG_ARRAY[@]}"; do
        echo -e "\033[33m $((i+1)). ${TAG_ARRAY[$i]}\033[0m"
    done

    echo -n -e "\033[36m请输入要安装的版本编号（例如 1）：\033[0m"
    read -r CHOICE
    INDEX=$((CHOICE-1))

    if [[ -z "${TAG_ARRAY[$INDEX]}" ]]; then
        echo -e "\033[31m输入无效编号，取消操作。\033[0m"
        exit 1
    fi

    SELECTED_TAG="${TAG_ARRAY[$INDEX]}"
    echo -e "\033[36m已选择版本：\033[0m\033[1;32m$SELECTED_TAG\033[0m"

    ASSET_URLS=$(echo "$RELEASE_DATA" | jq -r --arg tag "$SELECTED_TAG" '.[] | select(.tag_name == $tag) | .assets[].browser_download_url')

    for URL in $ASSET_URLS; do
        FILE=$(basename "$URL")
        echo -e "\033[36m下载中：$URL\033[0m"
        wget "$URL" -P /tmp/ || { echo -e "\033[31m下载失败：$URL\033[0m"; exit 1; }
    done
}

# 美化输出的分隔线
print_separator() {
    echo -e "\033[34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
}

# 欢迎信息与作者信息展示
print_separator
echo -e "\033[1;35m(☆ω☆)✧*｡ 欢迎来到 BBR 管理脚本世界哒！ ✧*｡(☆ω☆)\033[0m"
print_separator
echo -e "\033[36m当前 TCP 拥塞控制算法：\033[0m\033[1;32m$CURRENT_ALGO\033[0m"
echo -e "\033[36m当前队列管理算法：\033[0m\033[1;32m$CURRENT_QDISC\033[0m"
print_separator
echo -e "\033[1;33m作者：zhong yuan\033[0m"
print_separator

# 提示用户选择操作
echo -e "\033[1;33m╭( ･ㅂ･)و ✧ 你可以选择以下操作哦：\033[0m"
echo -e "\033[33m 1. ️ 安装或更新 BBR v3\033[0m"
echo -e "\033[33m 2. 检查是否为 BBR v3\033[0m"
echo -e "\033[33m 3. ⚡ 使用 BBR + FQ 加速\033[0m"
echo -e "\033[33m 4. ⚡ 使用 BBR + FQ_PIE 加速\033[0m"
echo -e "\033[33m 5. ⚡ 使用 BBR + CAKE 加速\033[0m"
echo -e "\033[33m 6. ️ 卸载\033[0m"
echo -e "\033[33m 0. 返回主菜单\033[0m"
print_separator
echo -n -e "\033[36m请选择一个操作 (0-6) (｡･ω･｡): \033[0m"
read -r ACTION

case "$ACTION" in
    0)
        exit 0
        ;;
    1)
        echo -e "\033[1;31m【高风险操作警告】\033[0m"
        echo -e "\033[33m您即将安装或更新 BBR v3 内核，这可能导致：\033[0m"
        echo -e "\033[33m- 系统内核被替换，部分 VPS/云服务器可能无法启动\033[0m"
        echo -e "\033[33m- 网络异常、丢失 SSH 连接、甚至系统无法启动\033[0m"
        echo -e "\033[33m- 请确保已备份重要数据，并知晓如何通过控制台救援\033[0m"
        echo -e "\033[33m- 如为生产环境/重要服务器，强烈建议不要随意更换内核！\033[0m"
        echo -n -e "\033[1;31m是否继续？(y/N): \033[0m"
        read -r confirm_risk
        if [[ ! "$confirm_risk" =~ ^[Yy]$ ]]; then
            echo -e "\033[33m操作已取消。\033[0m"
            read -n 1 -s -r -p "按任意键返回..."
            return
        fi
        echo -e "\033[1;32m٩(｡•́‿•̀｡)۶ 您选择了安装或更新 BBR v3！\033[0m"
        sudo apt remove --purge $(dpkg -l | grep "joeyblog" | awk '{print $2}') -y
        get_download_links
        install_packages
        read -n 1 -s -r -p "按任意键返回..."
        ;;
    2)
        echo -e "\033[1;32m(｡･ω･｡) 检查是否为 BBR v3...\033[0m"
        if modinfo tcp_bbr &> /dev/null; then
            BBR_VERSION=$(modinfo tcp_bbr | awk '/^version:/ {print $2}')
            if [[ "$BBR_VERSION" == "3" ]]; then
                echo -e "\033[36m检测到 BBR 模块版本：\033[0m\033[1;32m$BBR_VERSION\033[0m"
            else
                echo -e "\033[33m(￣﹃￣) 检测到 BBR 模块，但版本是：$BBR_VERSION，不是 v3！\033[0m"
                read -n 1 -s -r -p "按任意键返回..."
                exit 1
            fi
        fi
        CURRENT_ALGO=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
        if [[ "$CURRENT_ALGO" == "bbr" ]]; then
            echo -e "\033[36m当前 TCP 拥塞控制算法：\033[0m\033[1;32m$CURRENT_ALGO\033[0m"
        else
            echo -e "\033[31m(⊙﹏⊙) 当前算法不是 bbr，而是：$CURRENT_ALGO\033[0m"
            read -n 1 -s -r -p "按任意键返回..."
            exit 1
        fi
        echo -e "\033[1;32mヽ(✿ﾟ▽ﾟ)ノ 检测完成，BBR v3 已正确安装并生效！\033[0m"
        read -n 1 -s -r -p "按任意键返回..."
        ;;
    3)
        echo -e "\033[1;32m(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ 使用 BBR + FQ 加速！\033[0m"
        ALGO="bbr"
        QDISC="fq"
        ask_to_save
        read -n 1 -s -r -p "按任意键返回..."
        ;;
    4)
        echo -e "\033[1;32m٩(•‿•)۶ 使用 BBR + FQ_PIE 加速！\033[0m"
        ALGO="bbr"
        QDISC="fq_pie"
        ask_to_save
        read -n 1 -s -r -p "按任意键返回..."
        ;;
    5)
        echo -e "\033[1;32m(ﾉ≧∀≦)ﾉ 使用 BBR + CAKE 加速！\033[0m"
        ALGO="bbr"
        QDISC="cake"
        ask_to_save
        read -n 1 -s -r -p "按任意键返回..."
        ;;
    6)
        echo -e "\033[1;31m【高风险操作警告】\033[0m"
        echo -e "\033[33m您即将卸载 BBR 内核，这可能导致：\033[0m"
        echo -e "\033[33m- 系统内核被移除，若无其他可用内核，系统将无法启动\033[0m"
        echo -e "\033[33m- 网络异常、丢失 SSH 连接、甚至系统无法启动\033[0m"
        echo -e "\033[33m- 请确保已备份重要数据，并知晓如何通过控制台救援\033[0m"
        echo -e "\033[33m- 如为生产环境/重要服务器，强烈建议不要随意卸载内核！\033[0m"
        echo -n -e "\033[1;31m是否继续？(y/N): \033[0m"
        read -r confirm_risk
        if [[ ! "$confirm_risk" =~ ^[Yy]$ ]]; then
            echo -e "\033[33m操作已取消。\033[0m"
            read -n 1 -s -r -p "按任意键返回..."
            return
        fi
        echo -e "\033[1;32mヽ(・∀・)ノ 您选择了卸载 BBR 内核！\033[0m"
        sudo apt remove --purge $(dpkg -l | grep "joeyblog" | awk '{print $2}') -y
        echo -e "\033[33m如需重启服务器，请手动输入 \033[1;32mreboot\033[0m\033[33m 命令！\033[0m"
        read -n 1 -s -r -p "按任意键返回..."
        ;;
    *)
        echo -e "\033[31m(￣▽￣)ゞ 无效的选项，请输入 0-6 之间的数字哦~\033[0m"
        read -n 1 -s -r -p "按任意键返回..."
        ;;
esac
