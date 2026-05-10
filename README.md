# asus-merlin-cpa

Asus Merlin 路由器 softcenter 插件，封装 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 为标准 koolshare 软件中心插件。

## 功能

- 在 Merlin/koolshare 路由器上安装、运行和管理 CLIProxyAPI 服务
- 通过路由器 Web 管理界面控制服务启停、查看状态、执行更新
- 支持 GitHub Releases 自动检查更新与一键升级（含回滚）
- 仅支持 `aarch64` 架构（hnd/axhnd 64 位 Merlin 机型），结构预留 armv7/arm32 扩展

## 架构

系统由 6 个模块组成：

```
┌─────────────────────────────────────────────────┐
│                  Merlin Web UI                   │
│           Module_cpa.asp (外壳页面)              │
│   状态区 │ 控制区 │ 内容区 (CLIProxyAPI 管理面板) │
└──────────────────────┬──────────────────────────┘
                       │ HTTP
┌──────────────────────▼──────────────────────────┐
│              cpa_cgi.cgi (CGI 入口)              │
│              cpa_api.sh (JSON API)               │
└───┬──────────┬──────────┬──────────┬────────────┘
    │          │          │          │
┌───▼───┐ ┌───▼───┐ ┌───▼───┐ ┌───▼───┐
│config │ │runtime│ │update │ │platform│
│  .sh  │ │  .sh  │ │  .sh  │ │  .sh   │
└───┬───┘ └───┬───┘ └───┬───┘ └────────┘
    │         │         │
    ▼         ▼         ▼
  dbus     /var/run    GitHub
 (状态)    cpa.pid    Releases
          (进程管理)   (更新源)
```

### 模块说明

| 模块 | 文件 | 职责 |
|------|------|------|
| **构建层** | `scripts/repack.sh` | 组包、预检、生成 softcenter 安装包 |
| **安装层** | `install.sh` / `uninstall.sh` | 环境校验、文件部署、dbus 初始化、清理 |
| **运行层** | `scripts/cpa_runtime.sh` | 进程管理、端口检查、PID 文件、配置生成 |
| **控制层** | `scripts/cpa_config.sh` | start/stop/restart/status 生命周期入口 |
| **API 层** | `scripts/cpa_api.sh` | JSON 格式响应前端请求 |
| **更新层** | `scripts/cpa_update.sh` | 检查更新、下载、替换、回滚 |
| **平台层** | `scripts/cpa_platform.sh` | 架构识别、平台映射 |

## 目录结构

```
asus-merlin-cpa/
├── install.sh              # 安装脚本
├── uninstall.sh            # 卸载脚本
├── version                 # 插件版本号
├── .valid                  # 平台标记 (hnd)
├── scripts/
│   ├── cpa_config.sh       # 服务生命周期管理
│   ├── cpa_runtime.sh      # 进程/端口/配置运行时
│   ├── cpa_api.sh          # JSON API 接口
│   ├── cpa_update.sh       # 更新检查与执行
│   ├── cpa_platform.sh     # 平台检测
│   ├── repack.sh           # 打包脚本
│   ├── check_layout.sh     # 文件完整性检查
│   └── check_syntax.sh     # Shell 语法检查
├── webs/
│   ├── Module_cpa.asp      # Merlin 页面 (外壳)
│   └── cpa_cgi.cgi         # CGI 入口
├── res/
│   ├── icon-cpa.png        # 插件图标
│   └── cpa-menu.js         # 菜单交互脚本
├── assets/
│   └── aarch64/
│       └── CLIProxyAPI.tar.gz  # CLIProxyAPI 运行时
└── dist/                   # 打包产物目录
```

### 安装后目录 (`/koolshare/cpa/`)

```
/koolshare/cpa/
├── app/           # CLIProxyAPI 二进制和配置模板
├── package/       # 内置安装包备份
├── web/           # 预留前端资源目录
├── data/          # 运行时配置 (config.yaml)、认证数据
├── logs/          # 运行日志
└── backup/        # 更新前备份
```

## 安装

### 从打包产物安装

```bash
# 在路由器上执行
tar -xzf asus-merlin-cpa-0.1.0-*.tar.gz -C /tmp/
sh /tmp/cpa/install.sh
```

### 打包

```bash
sh scripts/repack.sh
# 产物输出到 dist/asus-merlin-cpa-{version}-{timestamp}.tar.gz
```

## 使用

### 命令行

```bash
# 服务管理
sh /koolshare/scripts/cpa_config.sh start
sh /koolshare/scripts/cpa_config.sh stop
sh /koolshare/scripts/cpa_config.sh restart
sh /koolshare/scripts/cpa_config.sh status

# 更新
sh /koolshare/scripts/cpa_update.sh check    # 检查新版本
sh /koolshare/scripts/cpa_update.sh update   # 执行更新
```

### Web 管理界面

安装后在 koolshare 软件中心找到 **CLIProxyAPI** 插件，点击进入管理页面。

页面提供：
- **状态区**：运行状态、端口、版本、更新信息
- **控制区**：启动/停止/重启/检查更新/执行更新
- **内容区**：CLIProxyAPI 原生管理面板 (通过 `/management.html` 加载)

### API

通过 `cpa_cgi.cgi` 提供 JSON 接口：

| 动作 | 返回 |
|------|------|
| `start` | `{"success":true,"result":"running:1234"}` |
| `stop` | `{"success":true,"result":"stopped"}` |
| `restart` | `{"success":true,"result":"running:1234"}` |
| `status` | `{"success":true,"running":true,"version":"6.10.9",...}` |
| `check-update` | `{"success":true,"result":"6.11.0"}` |
| `update` | `{"success":true,"result":"updated:6.11.0"}` |

## 配置

默认配置通过 dbus 管理，关键键值：

| 键 | 默认值 | 说明 |
|----|--------|------|
| `cpa_enable` | `0` | 服务启用状态 |
| `cpa_port` | `3210` | 监听端口 |
| `cpa_status` | `stopped` | 运行状态 |
| `cpa_management_key` | (随机 UUID) | 管理面板密钥 |
| `cpa_runtime_version` | `6.10.9` | 当前运行时版本 |
| `cpa_auto_update` | `0` | 自动更新开关 |

CLIProxyAPI 配置文件生成于 `/koolshare/cpa/data/config.yaml`，由 `config.example.yaml` 模板自动填充端口、密钥和认证目录。

## 更新机制

1. 检查 GitHub Releases 获取最新版本号
2. 对比当前版本，判断是否有可用更新
3. 下载对应平台资产 (`CLIProxyAPI_{version}_linux_aarch64.tar.gz`)
4. 备份当前版本到 `/koolshare/cpa/backup/current/`
5. 停止服务 -> 替换文件 -> 更新版本号 -> 启动服务
6. 启动失败则自动回滚到备份版本

下载器按优先级尝试：curl -> wget -> uclient-fetch -> busybox wget。

## 平台支持

| 架构 | 状态 | 资产后缀 |
|------|------|----------|
| `aarch64` | 支持 | `linux_aarch64` |
| `armv7` | 预留 | `linux_armv7` |
| `arm32` | 预留 | `linux_arm32` |

当前仅 `aarch64` 有内置资产，其他架构结构已预留但未实际构建。

## 卸载

```bash
sh /koolshare/scripts/uninstall_cpa.sh
```

自动清理：停止服务、删除脚本/页面/图标、移除 `/koolshare/cpa/`、清除 dbus 键。

## 开发

### 语法检查

```bash
sh scripts/check_syntax.sh
```

### 布局检查

```bash
sh scripts/check_layout.sh
```

### 配置持久化测试

```bash
sh tests_config_persistence.sh
```
