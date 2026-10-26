# EasyTier Flutter GUI

一款基于 **Flutter 3** 框架构建的现代化跨平台 **EasyTier** 图形化桌面客户端。

[EasyTier](https://easytier.cn/) 是一个简单、安全、去中心化的开源内网穿透与异地组网（SD-WAN / Mesh VPN）解决方案。本项目为 EasyTier 提供了现代化 Material 3 风格的图形界面，简化异地组网的配置与日常监控。

---

## ✨ 核心特性

- 🚀 **现代化仪表盘 (Dashboard)**
  - 一键连接 / 断开虚拟组网
  - 虚拟 IP 地址显示与一键复制（支持 DHCP 与静态 IP）
  - 实时上下行网速仪表、累计流量统计、组网运行时长
  - 发现核心新版本时顶部横幅智能提醒
- 🌐 **对等网络拓扑 (Peer & Topology)**
  - 实时显示局域网内所有 Peer 节点信息（主机名、虚拟 IP、传输协议、延迟等）
  - 支持区分展示 **P2P 直连** 与 **中继转发 (Relay)** 节点
  - 支持按节点 IP、名称、ID 快速模糊搜索
- 🛠️ **多配置文件管理 (Network Profiles)**
  - 支持保存多套组网配置（如家庭内网、公司研发网、游戏联机等）并随时一键切换
  - 支持可视化配置网络名 (`network-name`)、密钥 (`network-secret`)、DHCP / 静态 IP
  - 快捷添加对等节点 (`peers`)，内置官方公共共享中继节点
  - 支持子网代理 (`proxy-networks`)，将本地局域网无缝打通到异地组网
  - 支持一键预览与导出 `TOML` 格式标准配置文件
- 🔄 **内核自动更新 (Auto Update)**
  - 对接官方 GitHub Releases 仓库 ([EasyTier/EasyTier](https://github.com/EasyTier/EasyTier))
  - 自动检测并对比当前内核版本与官方最新版本
  - 支持查看详细更新说明（Release Notes）
  - 一键全自动分块流式下载、解压、安全替换 `.\bin` 目录中的运行库与驱动文件
- 📜 **实时运行控制台日志 (Console Logs)**
  - 实时捕获核心进程标准输出与错误日志（stdout / stderr）
  - 支持关键字实时搜索过滤、一键复制全部日志、清空控制台
- 🔍 **组网诊断工具 (Network Tools)**
  - 内置 ICMP Ping 连通性测试与延迟探测，支持快捷探测网内节点与公共节点
- ⚙️ **客户端设置 (Settings)**
  - **开箱即用内置核心**：自动优先识别并调用根目录 `.\bin` 下的 `easytier-core.exe` 与 `wintun.dll` 等依赖
  - 支持一键「检查更新」并弹窗升级
  - 支持自定义外部可执行程序路径并一键检测可用性
  - 支持浅色 / 深色 / 跟随系统主题切换
  - 支持启动客户端后自动连接组网

---

## 📂 项目结构

```text
easytier-gui/
├── bin/                               # 【内置核心与运行库】
│   ├── easytier-core.exe              # EasyTier 核心进程
│   ├── easytier-cli.exe               # 状态探测与拓扑查询工具
│   ├── wintun.dll                     # TUN 虚拟网卡驱动依赖
│   ├── Packet.dll                     # 网络抓包/驱动依赖
│   └── WinDivert64.sys                # 网络重定向驱动
├── lib/
│   ├── main.dart                      # 程序入口与主题配置
│   ├── models/                        # 数据模型
│   │   ├── app_settings.dart          # 客户端设置模型
│   │   ├── core_version_info.dart     # 核心版本与 Release 信息模型
│   │   ├── network_config.dart        # 组网配置模型 (参数与 TOML 解析)
│   │   └── peer_info.dart             # Peer 节点与运行状态模型
│   ├── providers/                     # 状态管理
│   │   └── easytier_provider.dart     # 核心状态、数据流与生命周期管理
│   ├── services/                      # 基础服务
│   │   ├── easytier_path_resolver.dart# 智能内置路径与依赖解析器
│   │   ├── easytier_process_service.dart # easytier-core 进程管理与日志监听
│   │   ├── easytier_updater_service.dart # GitHub 自动更新下载与解压替换服务
│   │   ├── ping_service.dart          # 网络延迟探测服务
│   │   └── storage_service.dart       # 本地配置与偏好持久化
│   ├── views/                         # UI 视图
│   │   ├── config_view.dart           # 网络配置管理与编辑
│   │   ├── dashboard_view.dart        # 仪表盘监控与快捷启停
│   │   ├── logs_view.dart             # 实时控制台日志
│   │   ├── main_layout.dart           # 桌面侧边栏与主布局
│   │   ├── peers_view.dart            # 节点拓扑与状态过滤
│   │   ├── settings_view.dart         # 客户端设置与核心路径
│   │   └── tools_view.dart            # Ping 与网络诊断
│   └── widgets/                       # 通用 UI 组件
│       ├── peer_card.dart             # 节点状态卡片
│       ├── stat_card.dart             # 流量与速率卡片
│       ├── status_badge.dart          # 组网状态胶囊组件
│       └── update_dialog.dart         # 内核自动更新弹窗
├── pubspec.yaml                       # 依赖与项目配置
└── README.md
```

---

## 🚀 快速开始

在项目根目录运行以下命令获取依赖并启动：

```powershell
# 拉取依赖
flutter pub get

# 启动 Windows 桌面端
flutter run -d windows
```

### 构建发布包

```powershell
flutter build windows --release
```

CMake 构建系统会自动将 `.\bin` 目录下的所有文件打包至最终运行目录，形成免安装直接可用的独立分发包。
