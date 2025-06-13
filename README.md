


# One-Click-Proxy-Installer 一键安装脚本

## 🌟 简介

- 真正适合小白折腾的脚本！当然，大白也可以按需服用哦！
- 可设置快捷启动命令：`box`或`x`等命令。方便以后快速进入本脚本，查看与配置。


本脚本用于在 Linux 服务器上快速安装、配置和管理 [Sing-Box](https://github.com/SagerNet/sing-box)，特别针对 Hysteria2 和 VLESS Reality 协议优化。

---

## ✨ 使用方法

**更新系统(可选)：**

```bash
apt-get update && apt-get install -y curl
```
**命令1. 下载脚本并启动：(报错则更新系统或下载curl)(安装命令不要去做一个保存后面会优化启动命令)**

```bash
curl -fsSL "https://github.com/shangguancaiyun/One-Click-Proxy-Installer/raw/main/lvhy.sh" -o lvhy.sh &&
curl -fsSL "https://github.com/shangguancaiyun/One-Click-Proxy-Installer/raw/main/modify_node_params.sh" -o modify_node_params.sh &&
curl -fsSL "https://github.com/shangguancaiyun/One-Click-Proxy-Installer/raw/main/bbr_manage.sh" -o bbr_manage.sh &&
curl -fsSL "https://github.com/shangguancaiyun/One-Click-Proxy-Installer/raw/main/install.sh" -o install.sh &&
chmod +x lvhy.sh modify_node_params.sh bbr_manage.sh install.sh &&
bash ./lvhy.sh
```

**命令2. 再次运行可启动脚本，之后可快捷命令： `box`**

```bash
sudo bash lvhy.sh
```

脚本将以 root 权限运行，并显示主菜单。

**3. 按提示选择菜单，输入数字即可完成安装和管理。**

- 1：一键安装 Hysteria2 + Reality（共存）
- 2：只装 Hysteria2
- 3：只装 Reality (VLESS)
- 其他选项可管理服务、查看/编辑配置、卸载等

**4. 安装完成后，终端会显示所有节点和二维码，直接扫码或复制即可食用。**

---

## 常见问题

- **需要 root 权限**：请用 `sudo` 运行脚本。
- **依赖自动安装**：脚本会自动检测并安装 curl、openssl、qrencode 等依赖。
- **配置文件路径**：`/usr/local/etc/sing-box/config.json`
- **导入信息保存**：上次安装的节点信息会自动保存，可随时通过菜单查看。
- **防火墙端口**：如有防火墙，需放行你选择的端口（如 443、8443）。

---

## 菜单选项说明：你会看到类似的页面

```
================================================
 Sing-Box Hysteria2 & Reality 管理脚本
================================================
 作者: Zhong Yuan
================================================
安装选项:
  1. 安装 Hysteria2 + Reality (共存)
  2. 单独安装 Hysteria2(建议)
  3. 单独安装 Reality (VLESS)
------------------------------------------------
管理选项:
  4. 启动 Sing-box 服务
  5. 停止 Sing-box 服务
  6. 重启 Sing-box 服务
  7. 查看 Sing-box 服务状态
  8. 查看 Sing-box 实时日志
  9. 查看当前配置文件
 10. 编辑当前配置文件 (使用 nano)
 11. 显示上次保存的导入信息 (含二维码)
------------------------------------------------
其他选项:
 12. 更新 Sing-box 内核 (使用官方beta脚本)
 13. 卸载 Sing-box
  0. 退出脚本
================================================
```

---

## 注意事项

- **防火墙**：只需放行相关端口。
  - 例如 Reality 用 443，Hysteria2 用 8443：
    ```bash
    sudo ufw allow 443/tcp
    sudo ufw allow 8443/tcp
    sudo ufw allow 8443/udp # Hysteria2 需要 UDP
    sudo ufw reload
    ```
- **端口选择：选 443、8443、80、8080 这类常见端口，更容易伪装成正常网站流量。当然，选择其他端口也可以联通！**

- **在线订阅转换网站**：[订阅转换](https://sub.crazyact.com/)

---

## 推荐工具箱/三方客户端/实用网站

- [老王一键工具箱](https://github.com/eooce/ssh_tool)：此工具，适合小白用户轻松搭建上网节点，跟我的脚本一样简单好用，轻松上手！

```bash
curl -fsSL https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh -o ssh_tool.sh && chmod +x ssh_tool.sh && ./ssh_tool.sh#建议快捷命令改为 w 避免冲突！
```

- [科技lion一键脚本](https://kejilion.sh/index-zh-CN.html)：适合无基础小白网站的建设与维护。

```bash
bash <(curl -sL kejilion.sh)#建议快捷命令改为 i
```

- 安卓/iOS/PC 推荐客户端：
  - [Karing](https://github.com/KaringX/karing/releases)（全平台免费开源，强烈推荐）
  - [nekobox](https://github.com/MatsuriDayo/NekoBoxForAndroid/releases)
  - [husi](https://github.com/xchacha20-poly1305/husi/releases)
  - [Clash-Meta](https://github.com/MetaCubeX/ClashMetaForAndroid/releases)
  - [hiddify](https://github.com/hiddify/hiddify-next/releases)
  - [v2rayNG](https://github.com/2dust/v2rayNG/releases)(安卓设备首选)
  - [Clash-Verge](https://github.com/clash-verge-rev/clash-verge-rev/releases)
  - [v2rayN](https://github.com/2dust/v2rayN/releases)(Win电脑PC端)

- 下载并安装SSH连接工具:
  - [Finalshell:](https://www.hostbuf.com/t/988.html)


- 实用网站推荐：
    - [libretv-自建影视](https://053312d1.libretv-edb.pages.dev/)进入密码:123
    - [磁力熊](https://www.cilixiong.org/)也是影视！
    - [IP质量检测](https://ipjiance.com/)
    - [IP纯净度检测](https://scamalytics.com/​)
    - [节点测速](https://fiber.google.com/speedtest/)
    - [CF网址：](https://www.cloudflare.com/zh-cn/)CloudFlare
    - [ip泄露真实地址检测1](https://dw.jhb.ovh/)，非你所处真实地址则没泄露！
    - [ip泄露真实地址检测2](https://ipleak.net/)

---

## VPS仅IPV6/IPV4 脚本推荐

- [WARP 一键脚本](https://gitlab.com/fscarmen/warp)先套IPV4/IPV6：

```bash
wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh [option] [lisence/url/token]
```

---
- 再次感谢兄弟们的支持！不会让兄弟们失望的！
- 未来会在便捷实用的基础上加以完善此项目，敬请关注！•᷄ࡇ•᷅
---

## 贡献

欢迎提交 Pull Requests 或在 Issues 中报告错误、提出建议。

## 开源协议

MIT License  |  维护者：Zhong Yuan

## 免责声明

- 本脚本仅供学习和测试，请勿用于非法用途。
- 作者不对使用此脚本可能造成的任何后果负责。

## 致谢

- [Sing-Box](https://github.com/SagerNet/sing-box)
- 感谢[项目](https://github.com/Netflixxp/vlhy2)及其开发者，提供的技术支持与灵感参考。
- 所有为开源社区做出贡献的人
- [副本](https://github.com/shangguan3366/One-Click-Proxy-Installer)
- [![Powered by DartNode](https://dartnode.com/branding/DN-Open-Source-sm.png)](https://dartnode.com "Powered by DartNode - Free VPS for Open Source")


## Star History

[![Star History
Chart](https://api.star-history.com/svg?repos=shangguancaiyun/One-Click-Proxy-Installer&type=Date)](https://www.star-history.com/#shangguancaiyun/One-Click-Proxy-Installer&Date)



