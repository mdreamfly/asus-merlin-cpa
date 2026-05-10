# asus-merlin-cpa Repack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于 `.worktrees/cpa-impl` 当前实现，沿用现有 `res/icon-cpa.png`，生成一个新的可交付 softcenter 安装包供联机验证。

**Architecture:** 以 `.worktrees/cpa-impl` 作为唯一输入源，新增一个最小重打包脚本统一执行预检、组包和静态验包。现有安装器、运行时、页面和图标内容保持不变，只新增打包入口与验收输出，且不覆盖旧 `dist/` 包。

**Tech Stack:** shell / tar / gzip / grep / git worktree / softcenter plugin layout

---

## File Structure Map

### Files to create
- `.worktrees/cpa-impl/scripts/repack.sh` — 最小重打包入口，负责预检、复制、打包、静态验包

### Files to modify
- `.worktrees/cpa-impl/scripts/check_layout.sh:1-24` — 如有必要，补充对新打包脚本自身存在性的检查
- `.worktrees/cpa-impl/.gitignore:1-9` — 如有必要，补充新的 dist 命名或临时目录忽略规则

### Files used for validation
- `.worktrees/cpa-impl/scripts/check_syntax.sh`
- `.worktrees/cpa-impl/install.sh`
- `.worktrees/cpa-impl/uninstall.sh`
- `.worktrees/cpa-impl/res/icon-cpa.png`
- `.worktrees/cpa-impl/assets/aarch64/CLIProxyAPI.tar.gz`

---

### Task 1: 固化重打包入口 ✅ 已完成

**Files:**
- Create: `.worktrees/cpa-impl/scripts/repack.sh`
- Test: `.worktrees/cpa-impl/scripts/check_layout.sh`
- Test: `.worktrees/cpa-impl/scripts/check_syntax.sh`

- [x] **Step 1: 先写失败性检查，验证重打包脚本尚不存在**
- [x] **Step 2: 运行检查并确认失败**
- [x] **Step 3: 写最小重打包脚本**
- [x] **Step 4: 赋予执行权限**
- [x] **Step 5: 再次运行存在性检查并确认通过**

> 实际实现比原计划多了 `res/cpa-menu.js` 的校验和复制。

---

### Task 2: 让预检覆盖新入口 ✅ 已完成

**Files:**
- Modify: `.worktrees/cpa-impl/scripts/check_layout.sh:6-21`
- Test: `.worktrees/cpa-impl/scripts/check_layout.sh`

- [x] **Step 1: 先写失败性断言，要求 layout 检查覆盖 repack 脚本**
- [x] **Step 2: 运行断言并确认失败**
- [x] **Step 3: 修改 layout 检查脚本**
- [x] **Step 4: 运行 layout 断言并确认通过**
- [x] **Step 5: 运行 layout 校验脚本并确认通过**

---

### Task 3: 生成新包并做静态验收 ✅ 已完成

**Files:**
- Test: `.worktrees/cpa-impl/scripts/repack.sh`
- Test: `.worktrees/cpa-impl/dist/asus-merlin-cpa-0.1.0-repack1.tar.gz`

- [x] **Step 1: 先写失败性检查，确认目标新包当前不存在**
- [x] **Step 2: 运行检查并确认失败**
- [x] **Step 3: 执行重打包脚本**
- [x] **Step 4: 运行产物存在性检查并确认通过**
- [x] **Step 5: 对新包执行静态验收**

> 产物 `asus-merlin-cpa-0.1.0-repack1.tar.gz` 已生成，包含完整文件列表且无 `bin64/` 旧残留。
> 额外包含 `cpa/res/cpa-menu.js`（菜单交互脚本）。

---

## Self-Review

- **Spec coverage:** 已覆盖唯一基线、沿用现有图标、不覆盖旧包、静态校验、联机验证前产物准备。
- **Placeholder scan:** 无 TBD/TODO/“稍后实现”类占位词。
- **Type consistency:** 统一使用 `scripts/repack.sh` 作为新入口，统一使用 `asus-merlin-cpa-0.1.0-repack1.tar.gz` 作为目标产物名。
