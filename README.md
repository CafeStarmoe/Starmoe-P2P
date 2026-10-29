# Starmoe Game P2P Tools

A modern, cross-platform desktop graphical user interface for [EasyTier](https://easytier.cn/), built with the Flutter framework.

EasyTier is a simple, decentralized, and secure mesh VPN / SD-WAN solution written in Rust. This application provides a clean Material 3 desktop interface to configure, monitor, and manage your virtual private mesh networks with ease.

---

## Features

- **Modern Dashboard**
  - One-click connect and disconnect for virtual mesh networks.
  - Virtual IP display with one-click copy (supports both DHCP and static IP).
  - Real-time upload and download throughput meters, cumulative data counters, and connection uptime tracking.
  - Smart top banner alert when a newer EasyTier core release is available.

- **Peer & Network Topology**
  - Live status list of all peers connected in the virtual network (hostname, virtual IP, transport protocol, latency, etc.).
  - Clear visual distinction between **P2P Direct** and **Relay** connections.
  - Fast search and filter by node IP, hostname, or Peer ID.

- **Multi-Profile Management**
  - Store and switch across multiple network profiles seamlessly (e.g., Home LAN, Office Dev, Gaming).
  - Save plain EasyTier-compatible TOML profiles in `config/` beside the desktop executable (mobile builds use the app support directory).
  - Load `default.toml` only when no `profile_*.toml` profiles are available; configuration files are never generated automatically. Create a profile in the Config page or provide `default.toml` yourself.
  - Existing saved profiles are migrated to TOML on first launch.
  - Visual setup for network name (`network-name`), secret (`network-secret`), and DHCP / static IP.
  - Quick-add peer endpoints (`peers`) with official public relay servers provided by default.
  - Subnet proxy (`proxy-networks`) support to bridge local subnets into the virtual network.
  - One-click preview and export of standard `TOML` configuration files.

- **Core Auto-Update**
  - Direct integration with the official GitHub repository ([EasyTier/EasyTier](https://github.com/EasyTier/EasyTier)).
  - Automatic detection and comparison of the local core version against the latest remote release.
  - In-app preview of official release notes and changelog.
  - Automated chunked download, extraction, and safe in-place replacement of binaries and drivers in the `bin/` directory.

- **Real-Time Console Logs**
  - Real-time streaming output of core process stdout and stderr.
  - Keyword filtering, error highlighting, full log copy, and console clearing.

- **Network Diagnostic Tools**
  - Built-in ICMP Ping utility for latency probing and connectivity diagnostics against mesh peers and public endpoints.

- **Client Settings**
  - **Out-of-the-Box Built-in Core**: Automatically discovers and invokes `easytier-core` and drivers from the project's `bin/` folder.
  - Supports custom executable paths with instant validity testing.
  - Theme switching (Light / Dark / System).
  - Option to auto-connect on application startup.

---

## Build

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.10.0)

1. Clone the repository.

   ```bash
   git clone https://github.com/amaneyunomi/Easytier-GUI-Flutter.git
   cd Easytier-GUI-Flutter
   ```

2. Fetch Flutter dependencies.

   ```bash
   flutter pub get
   ```

3. Build MS Windows version with flutter.

   ```bash
   flutter build windows --release
   ```
