# Xiaomi Mi 8 (dipper) Kernel 4.9 Builder with Droidspaces Support

为小米8 (dipper) 构建 Linux 4.9 内核，包含完整的 Droidspaces non-GKI 支持。

## 项目结构

```
dipper-kernel-builder/
├── .github/workflows/
│   └── build-kernel.yml     # GitHub Actions 远程编译工作流
├── Dockerfile              # Docker 镜像定义 (Ubuntu 22.04 + 工具链)
├── docker-compose.yml      # Docker Compose 配置
├── run.ps1                  # Windows PowerShell 启动脚本 (Docker)
├── run.bat                  # Windows 批处理启动脚本 (Docker)
├── config/
│   ├── droidspaces.config  # Droidspaces non-GKI 内核配置片段
│   └── custom.config       # 自定义内核配置 (CRC禁用、文件系统等)
└── scripts/
    ├── build.sh             # Docker 主构建脚本
    ├── setup-wsl.sh         # WSL 本地一键编译脚本
    └── entrypoint.sh        # Docker 入口脚本
```

## 前提条件

- 小米8已解锁 Bootloader
- 备份了原厂 boot.img (用于打包)
- 选择以下任一编译方式

## 快速开始

### 方法 1: GitHub Actions 远程编译 (推荐 - 无需安装任何环境)

不需要在本地安装 Docker 或 WSL，直接在 GitHub 服务器上编译。

**步骤：**

1. 登录 [GitHub](https://github.com) (没有账号则注册一个)
2. 点击右上角 `+` -> `New repository`，创建一个新仓库 (Public/Private 均可)
3. 将本项目的所有文件上传到仓库中 (可以拖拽上传)
4. 进入仓库的 `Actions` 标签页
5. 在左侧找到 `Build Dipper Kernel 4.9 with Droidspaces`
6. 点击 `Run workflow` 按钮
7. 选择内核分支 (默认 `dipper-q-oss`) 和 defconfig (默认 `dipper_user_defconfig`)
8. 点击绿色的 `Run workflow` 按钮
9. 等待编译完成 (约 15-30 分钟)
10. 编译完成后，在构建结果页面下载 `dipper-kernel-image` 和 `dipper-kernel-config` 产物

> GitHub Actions 免费额度：公开仓库无限分钟，私有仓库每月 2000 分钟。

### 方法 2: WSL Ubuntu 本地编译 (推荐本地方式)

**一次性安装 WSL：**

以管理员身份打开 PowerShell，运行：
```powershell
wsl --install -d Ubuntu-22.04
```
安装完成后重启电脑，打开 Ubuntu 完成初始设置 (设置用户名和密码)。

**在 WSL 中编译内核：**

```bash
# 进入项目目录 (路径根据你的实际路径调整)
cd /mnt/c/Users/ddd/Documents/trea/dipper-kernel-builder

# 一键编译 (安装依赖 + 下载工具链 + 克隆源码 + 打补丁 + 编译)
bash scripts/setup-wsl.sh
```

编译完成后，内核文件在 WSL 的 `~/output/` 目录。
从 Windows 访问：在文件管理器地址栏输入 `\\wsl$\Ubuntu-22.04\home\<你的用户名>\output`

### 方法 3: Docker Desktop (需要已安装 Docker)

```powershell
# 自动构建内核
.\run.bat --build

# 或进入交互式 Shell
.\run.bat
```

### 方法 4: Docker Compose

```bash
docker-compose up -d
docker exec -it dipper-kernel-builder bash
~/scripts/build.sh
```

## 构建过程

构建脚本 `build.sh` 会自动执行以下步骤:

| 步骤 | 说明 |
|------|------|
| 1. 克隆源码 | 从 MiCode/Xiaomi_Kernel_OpenSource 克隆 dipper-q-oss 分支 |
| 2. 应用补丁 | 下载并应用 Droidspaces non-GKI 补丁 + 编译修复补丁 |
| 3. 复制配置 | 将 droidspaces.config 和 custom.config 复制到内核源码 |
| 4. 编译内核 | 使用 Proton Clang 12 + Linaro GCC 7.5 编译 |
| 5. 打包 boot.img | 使用 magiskboot 将内核打包到 boot.img (需要原厂 boot.img) |

## 工具链

| 工具 | 版本 | 用途 |
|------|------|------|
| Proton Clang | 12 | C 编译器 (CC=clang) |
| Linaro GCC | 7.5 | 交叉编译 (CROSS_COMPILE=aarch64-linux-gnu-) |
| magiskboot | latest | boot.img 打包/解包 |

## Droidspaces 配置

本构建启用了 Droidspaces 所需的全部 non-GKI 内核选项:

- **命名空间**: PID, UTS, IPC, Network
- **Cgroup**: Device, PIDS, Memory, Sched, Freezer, NetPrio
- **网络**: VETH, Bridge, Netfilter, NAT, Masquerade
- **文件系统**: OverlayFS, devtmpfs, tmpfs xattr/ACL
- **安全**: Seccomp, User namespace
- **可选**: UFW, Fail2ban 支持

## 获取原厂 boot.img

打包 boot.img 需要你设备的原厂 boot.img:

### 方法 1: 从 fastboot ROM 提取
1. 下载小米8的 Fastboot ROM (如 V12.5.1.0.QEACNMI)
2. 解压 .tgz -> .tar -> images/ 目录
3. 找到 `boot.img`

### 方法 2: 从手机中提取
```bash
# 手机需要 root + USB 连接
adb shell su -c "dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/boot.img"
adb pull /sdcard/boot.img
```

### 方法 3: 复制到输出目录
将 `boot.img` 放到 Docker volume 中的 output 目录:
```bash
# 找到 volume 路径
docker volume inspect dipper-kernel-builder_kernel-output

# 复制 boot.img 到该路径
cp boot.img /var/lib/docker/volumes/dipper-kernel-builder_kernel-output/_data/stock_boot.img
```

然后重新运行 `~/scripts/build.sh` 即可自动打包。

## 刷入内核

```bash
# 进入 fastboot 模式
adb reboot bootloader

# 刷入 boot.img
fastboot flash boot droidspaces-boot.img

# 重启
fastboot reboot
```

## 验证 Droidspaces

开机后打开 Droidspaces App:
1. 设置 (齿轮图标)
2. Requirements
3. Check Requirements

所有必需项应显示绿色勾号。

## 常见问题

### Q: Docker 构建失败，提示网络错误
A: 检查 Docker Desktop 的网络设置，确保 DNS 正常。可以尝试使用国内镜像源。

### Q: 内核编译失败
A: 查看错误信息，常见问题:
- `aarch64-linux-gnu-gcc: command not found` -> Linaro GCC 未正确安装
- `multiple definition of 'yylloc'` -> 需要应用 yylloc 补丁
- `-Werror` 相关错误 -> 需要应用 fix-Werror 补丁

### Q: 内核刷入后不开机 (bootloop)
A: 可能原因:
- 内核配置与设备不兼容
- 缺少必要的驱动模块
- 解决方案: 进入 fastboot 模式刷回原厂 boot.img
  ```bash
  fastboot flash boot stock_boot.img
  fastboot reboot
  ```

### Q: 想要修改内核分支
A: 修改 docker-compose.yml 或环境变量:
```yaml
environment:
  - KERNEL_BRANCH=dipper-o-oss   # Android 8.1
  - KERNEL_BRANCH=dipper-p-oss   # Android 9
  - KERNEL_BRANCH=dipper-q-oss   # Android 10 (默认)
```

### Q: 如何自定义内核配置
A: 编辑 `config/custom.config` 文件，添加你需要的 CONFIG 选项:
```
CONFIG_BTRFS_FS=y
CONFIG_F2FS_FS=y
CONFIG_OVERLAY_FS=y
```

## 参考链接

- [Droidspaces-OSS 内核配置指南](https://github.com/ravindu644/Droidspaces-OSS/blob/main/Documentation/Kernel-Configuration.md)
- [Android Kernel Tutorials](https://github.com/ravindu644/Android-Kernel-Tutorials)
- [Xiaomi 内核开源仓库](https://github.com/MiCode/Xiaomi_Kernel_OpenSource)
- [Proton Clang](https://github.com/ravindu644/proton-12)
- [Magisk](https://github.com/topjohnwu/Magisk)

## 风险提示

刷入自定义内核可能导致设备变砖、数据丢失或其他问题。请确保:
1. 已解锁 Bootloader
2. 已备份原厂 boot.img
3. 了解如何进入 fastboot 模式恢复
4. 接受所有风险
