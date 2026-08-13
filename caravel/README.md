# Caravel MPW 集成 — SHA-256 加密加速器

## 概述

本目录包含将 SHA-256 加速器集成到 Efabless Caravel 框架所需的文件。

**当前状态**：RTL wrapper + 配置文件已创建，待 OpenLane 环境就绪后执行物理实现。

## 文件清单

| 文件 | 说明 |
|------|------|
| `user_project_wrapper.v` | Caravel 用户项目 wrapper — Wishbone 适配器 + SHA256 实例化 |
| `user_project_wrapper.sdc` | 时序约束（15ns / 66.7MHz） |
| `config.json` | OpenLane 配置（设计名、时钟、面积、PDK 路径） |
| `pin_order.cfg` | 引脚排列配置（需根据 Caravel pad frame 版本调整） |

## 集成步骤

### 1. 前置条件

```bash
# 需要 Docker + OpenLane
docker pull efabless/openlane:latest

# Fork + clone caravel_user_project
git clone https://github.com/efabless/caravel_user_project.git sha256_caravel
cd sha256_caravel

# 配置 Caravel
export CARAVEL_ROOT=$(pwd)/caravel
export PDK_ROOT=/usr/local/share/pdk
export OPENLANE_ROOT=<openlane_path>
```

### 2. 复制设计文件

```bash
# 复制 wrapper RTL
cp /home/openroad/SHA-256/caravel/user_project_wrapper.v openlane/user_project_wrapper/
cp /home/openroad/SHA-256/caravel/user_project_wrapper.sdc openlane/user_project_wrapper/
cp /home/openroad/SHA-256/caravel/config.json openlane/user_project_wrapper/
cp /home/openroad/SHA-256/caravel/pin_order.cfg openlane/user_project_wrapper/

# 复制 SHA256 核心RTL（SHA256.v 通过 `include 包含所有子模块）
cp /home/openroad/SHA-256/Verilog/*.v openlane/user_project_wrapper/
```

### 3. 运行 OpenLane flow

```bash
cd openlane
make user_proj_example
```

### 4. 验证

```bash
# Precheck
make precheck-local

# 如果全绿，可以提交到 MPW
```

## 接口映射

### SHA256 核心接口（方案 B split inout）

| 端口 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | input | 1 | 时钟 |
| `rst` | input | 1 | 复位（active-high） |
| `soc` | input | 1 | 开始计算（pulse） |
| `rd` | input | 1 | 读使能 |
| `eoc` | output | 1 | 计算完成 |
| `data_in` | input | 32 | 消息输入 |
| `data_out` | output | 32 | 哈希输出 |
| `data_oe` | output | 1 | 输出使能（1=哈希有效） |

### Wishbone 寄存器映射

| 地址 | 读 | 写 | 说明 |
|------|----|----|------|
| 0x0 | {eoc, data_oe, 30'b0} | data_in + soc pulse | 消息/状态寄存器 |
| 0x4 | data_out[31:0] | — | 哈希输出寄存器 |

### 使用流程

1. 写 `0x0`：发送消息字（32-bit），每写一次 `soc` 脉冲一个时钟
2. 轮询读 `0x0`：检查 `eoc` 位是否为 1
3. `eoc=1` 后，读 `0x4`：获取哈希字（每次读 `rd` 脉冲，返回下一个字）
4. 重复读 `0x4` 共 8 次，获取完整 256-bit 哈希

## 注意事项

1. **拆分 inout 接口**：SHA256 核心使用 `data_in`/`data_out`/`data_oe` 三根独立线，而非双向 `inout data`。这是方案 B 的核心改动，使 Yosys 可安全全 `flatten` 综合。
2. **时钟 15ns（66.7MHz）**：对齐方案 B 的时序收敛结果（setup +0.185ns / hold +0.058ns）。
3. **Caravel 面积约束**：user_project_area 为 2920×3520 µm²，SHA256 核心约 154K µm²，利用率 ~4.5%，远低于上限。
4. **power pins**：wrapper 需要连接 Caravel 的 `vccd1`/`vssd1` 电源网络。当前 wrapper 未包含 `USE_POWER_PINS` 定义，如需 power-aware 综合，在 config.json 中启用 `SYNTH_USE_PG_PINS_DEFINES`。
