# asus-merlin-cpa 设计方案

## 1. 背景与目标

本项目目标是在 koolshare / Asus Merlin 环境中封装 CLIProxyAPI，交付一个标准 softcenter 插件 `asus-merlin-cpa`。

当前阶段目标：

- 以 `.worktrees/cpa-impl` 作为唯一打包基线
- 沿用现有 `res/icon-cpa.png` 重新生成 softcenter 安装包
- 保持当前安装、卸载、启动、停止、状态查看逻辑不变
- 通过本地结构校验、shell 语法校验和安装包静态验收确认产物一致性
- 为后续真机安装验证保留明确的交付边界

当前阶段非目标：

- 不替换正式插件图标
- 不回收或重构根仓库与 worktree 的目录关系
- 不修改 CLIProxyAPI 前端或插件功能逻辑
- 不在本轮声明真机安装验证通过
- 不落地 armv7 / arm32 实际构建产物
- 不实现复杂守护、集群、高可用能力

## 2. 范围约束

### 2.1 平台范围

当前阶段仅支持 Linux `aarch64` 的 hnd / axhnd 64 位 Merlin / koolshare 机型。

实现上必须保留未来扩展能力：

- 安装器按平台映射选择资产
- 运行目录可按平台存放二进制
- 更新器可按平台选择 release 资产
- 后续支持 `armv7/arm32` 时不需要重构主流程

### 2.2 UI 集成范围

采用“Merlin 页面做壳，CLIProxyAPI 原生管理路由内嵌”的模式：

- Merlin 页面负责菜单、状态、版本、更新入口
- CLIProxyAPI 原生管理界面通过 `/management` 路由加载
- 控制面板静态资产由 CLIProxyAPI 运行时按配置自行下载和托管，而不是随插件包内置
- 如有必要，仅做最小量路径适配（管理入口、API 路由、远程访问约束）

### 2.3 图标与重打包范围

当前轮次明确沿用现有 `res/icon-cpa.png`，不进入正式图标替换。

约束：

- 现有图标只作为本轮重打包输入资源
- 打包过程中不得修改图标文件内容或命名
- 后续若单独启动图标设计任务，再更新视觉方案与导出规范

## 3. 方案比较

### 方案 A：Merlin 壳页面 + 本地 CLIProxyAPI 服务 + 轻量反向接入（推荐）

特点：

- 插件安装后将 CLIProxyAPI 解包到 `/koolshare/cpa/`
- 启动脚本拉起本地 CLIProxyAPI 服务
- Merlin 页面提供状态、控制与更新入口
- 主内容区加载 CLIProxyAPI 原生前端

优点：

- 最符合本项目目标
- 生命周期清晰
- 多架构扩展最自然
- 上游前端升级适配成本相对最低

缺点：

- 需要处理端口、静态资源路径和代理接入

### 方案 B：前端静态资源发布到 `webs/`，API 走本地服务

优点：

- 静态资源访问链路更直

缺点：

- 与上游版本更容易失配
- 每次升级都要额外适配资源结构
- 不满足“原样托管”优先级

### 方案 C：Merlin 只做入口，独立打开 CLIProxyAPI 页面

优点：

- 开发最简单

缺点：

- 集成度最低
- 不符合既定 UI 目标

### 结论

采用方案 A。

## 4. 总体架构

系统拆分为 6 个清晰模块：

1. `package` 构建层
2. `installer` 安装层
3. `runtime` 运行层
4. `ui-shell` 外壳层
5. `bridge` 接入层
6. `updater` 更新层

### 4.1 package 构建层

职责：

- 以 `.worktrees/cpa-impl` 当前目录作为唯一输入源
- 组织 softcenter 插件目录
- 内置当前平台资产
- 生成新的可安装插件包，且不覆盖旧 `dist/` 产物
- 对生成包执行静态结构验收，避免混入旧布局残留（如 `bin64/`）
- 预留未来分平台打包能力

### 4.2 installer 安装层

职责：

- 校验 softcenter / koolshare 环境
- 校验机型、内核、架构
- 复制页面、脚本、资源
- 解包 CLIProxyAPI 运行时
- 初始化 dbus 默认值
- 注册模块元信息

### 4.3 runtime 运行层

职责：

- 管理 start / stop / restart / status
- 管理 pid、日志、端口
- 检查进程和监听状态
- 向上层暴露统一状态

### 4.4 ui-shell 外壳层

职责：

- 在 Merlin 风格页面中展示插件状态
- 展示版本与更新入口
- 承载 CLIProxyAPI 原生前端内容区

### 4.5 bridge 接入层

职责：

- 将前端动作转为 shell 动作
- 返回 JSON 状态
- 屏蔽 CGI 与后端脚本差异

### 4.6 updater 更新层

职责：

- 检查 GitHub Releases
- 识别平台对应资产
- 下载、校验、替换程序
- 更新失败时执行回滚

## 5. 目录设计

建议仓库结构：

```text
asus-merlin-cpa/
├── install.sh
├── uninstall.sh
├── version
├── .valid
├── scripts/
│   ├── cpa_config.sh
│   ├── cpa_api.sh
│   ├── cpa_runtime.sh
│   ├── cpa_update.sh
│   ├── cpa_platform.sh
│   ├── repack.sh
│   ├── check_layout.sh
│   └── check_syntax.sh
├── webs/
│   ├── Module_cpa.asp
│   └── cpa_cgi.cgi
├── res/
│   ├── icon-cpa.png
│   └── cpa-menu.js
├── assets/
│   └── aarch64/
│       └── CLIProxyAPI.tar.gz
└── dist/
    └── asus-merlin-cpa-0.1.0-repack1.tar.gz
```

安装后目标目录：

```text
/koolshare/cpa/
├── app/
├── web/
├── data/
├── logs/
└── backup/
```

说明：

- `app/`：CLIProxyAPI 可执行、`config.example.yaml`、生成后的 `config.yaml`
- `web/`：预留目录；当前阶段不直接落前端静态资源
- `data/`：运行时配置、缓存、元数据
- `logs/`：启动、运行、更新日志
- `backup/`：更新前备份

## 6. 生命周期设计

### 6.1 安装

入口：`install.sh`

步骤：

1. 检测 softcenter / koolshare 运行环境
2. 检测机型、内核、架构
3. 当前仅允许 `aarch64`
4. 复制脚本、页面、图标、资源
5. 解包内置 `CLIProxyAPI.tar.gz` 到 `/koolshare/cpa/`
6. 设置执行权限
7. 创建 init 链接或统一生命周期入口
8. 初始化 dbus 默认值
9. 注册模块元信息
10. 默认安装完成后不自动启动

### 6.2 启动

入口：`scripts/cpa_config.sh start`

步骤：

1. 检查程序是否存在且可执行
2. 检查配置目录是否完整
3. 检查端口是否可用
4. 启动 CLIProxyAPI 本地服务
5. 写入 pid、端口、版本、启动时间
6. 更新 dbus 运行状态

### 6.3 停止

入口：`scripts/cpa_config.sh stop`

步骤：

1. 按 pid 停止 CLIProxyAPI
2. 兜底扫描同名进程
3. 清理 pid 文件
4. 更新 dbus 状态

### 6.4 重启

入口：`scripts/cpa_config.sh restart`

步骤：

1. stop
2. 校验运行目录
3. start

### 6.5 卸载

入口：`uninstall.sh`

步骤：

1. 停止 CLIProxyAPI
2. 删除脚本、页面、图标、init 链接
3. 删除 `/koolshare/cpa/`
4. 清理 dbus 键
5. 清理更新定时任务

## 7. 页面设计

`Module_cpa.asp` 只负责外壳，不重写业务前端。

页面分为三部分：

### 7.1 状态区

展示：

- 插件安装状态
- CLIProxyAPI 运行状态
- 当前监听端口
- 当前版本
- 最新版本
- 最近检查时间
- 更新可用状态

### 7.2 控制区

提供按钮：

- 启动
- 停止
- 重启
- 检查更新
- 执行更新

### 7.3 内容区

- 加载 CLIProxyAPI 原生管理界面
- 当前阶段固定通过 `/management` 路由加载
- 启动时生成 `config.yaml`，确保管理面板启用、允许远程访问并具备管理密钥

## 8. 前后端桥接设计

### 8.1 CGI / API 入口

- `webs/cpa_cgi.cgi`
- `scripts/cpa_api.sh`

职责：

- 接收页面动作
- 读取或写入 dbus 状态
- 调用 `cpa_config.sh`、`cpa_update.sh`
- 返回 JSON 结果

### 8.2 运行时封装

`cpa_runtime.sh` 负责：

- 端口检查
- pid 检查
- 进程是否存活
- 日志路径管理
- 服务地址拼装

### 8.3 平台封装

`cpa_platform.sh` 负责：

- 当前平台识别
- 平台到资产名映射
- 平台支持判断

## 9. 数据与状态模型

建议 dbus 键：

- `cpa_enable`
- `cpa_plugin_version`
- `cpa_runtime_version`
- `cpa_management_key`
- `cpa_port`
- `cpa_status`
- `cpa_latest_version`
- `cpa_update_available`
- `cpa_update_url`
- `cpa_last_check_time`
- `cpa_auto_update`
- `softcenter_module_cpa_install`
- `softcenter_module_cpa_version`
- `softcenter_module_cpa_title`
- `softcenter_module_cpa_description`

状态原则：

- 不只依赖 dbus
- 状态判断必须综合 pid 文件、`kill -0`、端口监听结果
- 防止“显示运行中但进程已退出”的假状态

## 10. 更新策略

### 10.1 版本提醒

默认开启：

- 每天检查一次最新 release
- 对比当前版本和远端版本
- 若有新版本，则写入 dbus 并在页面提示

### 10.2 自动更新

默认关闭，由用户手动开启。

更新步骤：

1. 解析最新 release 信息
2. 根据平台映射选择资产
3. 下载到临时目录
4. 校验完整性
5. 停止当前服务
6. 备份旧版本到 `backup/`
7. 替换新版本
8. 启动服务
9. 成功则更新版本号
10. 失败则回滚旧版本并恢复服务

### 10.3 平台映射策略

内部使用映射表：

```text
aarch64 -> linux_aarch64
armv7   -> linux_armv7
arm32   -> linux_arm32
```

当前阶段仅启用 `aarch64 -> linux_aarch64`。

## 11. 异常处理

### 11.1 安装失败

- 非支持平台：直接退出，不写安装完成标记
- 资产缺失：中止安装
- 解包失败：清理临时目录
- 覆盖失败：保留旧状态，不标记安装成功

### 11.2 启动失败

- 端口占用：提示错误并不标记为运行中
- 二进制不可执行：写日志并返回失败
- 静态资源缺失：后端允许单独失败上报，但页面需明确提示“管理界面不可用”

### 11.3 更新失败

- 下载失败：保留当前版本
- 校验失败：拒绝替换
- 替换后启动失败：自动回滚
- 回滚失败：保留错误状态和日志入口，不自动重试

### 11.4 卸载失败

- 若进程无法立即停止，先标记停用，再兜底清理残留 pid / 链接
- 对不存在文件使用幂等删除，避免重复卸载报错

## 12. 测试范围

本轮只覆盖重打包关键闭环：

### 12.1 本地静态校验

- `scripts/check_layout.sh` 通过，确认打包输入文件齐全
- `scripts/check_syntax.sh` 通过，确认安装器、卸载器和 shell 脚本语法有效
- `assets/aarch64/CLIProxyAPI.tar.gz` 可正常列出内容，且包含 `cli-proxy-api`

### 12.2 安装包验收

- 新包可正常解出 `install.sh`、`uninstall.sh`、`version`、`.valid`
- 新包可正常解出 `scripts/`、`webs/`、`res/icon-cpa.png`、`assets/aarch64/CLIProxyAPI.tar.gz`
- 新包不覆盖旧 `dist/` 产物，而是并存输出新文件
- 新包内不包含与当前安装逻辑无关的旧残留目录，例如 `bin64/`

### 12.3 结论边界

- 本轮只声明“完成重打包并通过静态验包”
- 真机安装、页面打开、运行生命周期、更新回滚属于后续设备验证范围
- 任何未在 Merlin 设备上验证的能力，本轮均不宣称通过

## 13. 图标范围说明

本轮不设计新图标，也不替换现有图标。

约束：

- 继续使用当前 `res/icon-cpa.png`
- 打包脚本只能复制该文件，不改内容、不改文件名
- 若后续单独启动图标任务，再补充视觉规范、源文件尺寸和导出规则

## 14. 实施顺序建议

建议本轮顺序：

1. 以 `.worktrees/cpa-impl` 为基线确认输入文件集合
2. 运行结构检查与 shell 语法检查
3. 新增最小重打包入口，统一输出到 `dist/`
4. 生成不覆盖旧包的新安装包
5. 对新包执行 `tar -tzf` 静态验收，确认不存在旧残留目录
6. 输出真机验证边界与后续建议

## 15. 决策结论

本轮采用以下最终决策：

- 以 `.worktrees/cpa-impl` 作为唯一重打包基线
- 当前仅支持 `aarch64`，但结构上预留多架构扩展
- 保持现有安装器、运行时和页面接入逻辑不变
- 沿用当前 `res/icon-cpa.png`，暂停正式图标替换
- 新包与旧 `dist/` 产物并存输出，不覆盖历史包
- 本轮验收口径限定为“重打包完成并通过静态验包”
