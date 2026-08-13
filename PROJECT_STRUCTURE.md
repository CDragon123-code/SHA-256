# SHA-256 ASIC 项目结构说明

> 本文档说明项目的文件组织，区分入口文件、关键产出、中间产物和可清理文件。

## 1. 目录总览

```
SHA-256/
├── Verilog/              # RTL 源码（设计的起点）
├── flow/                 # PnR / LVS / Signoff 全流程（核心）
│   └── sky130_sim/       # 门级仿真模型
├── caravel/              # Caravel MPW 集成封装
├── C/                    # C 参考实现（验证用）
├── exploratory/          # 探索性实验数据（原项目遗留）
├── scripts/              # 环境安装脚本
├── *.png                 # 版图截图
├── *.py                  # 顶层工具脚本
├── SHA-256-CHIP-DESIGN.md  # 主设计文档（17 章）
├── PROJECT_RETROSPECTIVE.md# 项目复盘
├── PROJECT_STRUCTURE.md    # 本文档
├── README.md               # GitHub README
├── LICENSE                 # MIT 许可证
└── sky130_colors.lyp       # KLayout 配色方案
```

## 2. 入口文件（从这里开始读）

| 文件 | 说明 | 目标读者 |
|------|------|---------|
| `README.md` | 项目概览、规格表、签核表、复现步骤 | 首次访客 |
| `SHA-256-CHIP-DESIGN.md` | 完整设计文档（17 章，含流程/问题/教训） | 深入了解者 |
| `PROJECT_RETROSPECTIVE.md` | 项目复盘（里程碑、方法论、技术决策） | 学习方法论者 |
| `PROJECT_STRUCTURE.md` | 本文档，文件索引 | 查找特定文件者 |
| `Verilog/SHA256.v` | SHA-256 顶层 RTL 模块 | RTL 工程师 |
| `flow/openroad_flow_15ns_signoff.tcl` | 签核版 OpenROAD 流程脚本 | PnR 工程师 |

## 3. RTL 源码（Verilog/）

| 文件 | 功能 |
|------|------|
| `SHA256.v` | 顶层模块，实例化所有子模块 |
| `SHA256_testbench.v` | RTL 测试平台 |
| `tb_data.txt` | 测试数据（2-block 二进制消息） |
| `compression.v` | SHA-256 压缩函数（关键路径所在） |
| `expansion.v` | 消息调度（W[i] 生成） |
| `add2~5.v` | 32-bit 加法器（不同位宽） |
| `choice.v` | Ch(x,y,z) 函数 |
| `majority.v` | Maj(x,y,z) 函数 |
| `lsigma0.v` / `lsigma1.v` | Σ0/Σ1 逻辑（小写 σ） |
| `usigma0.v` / `usigma1.v` | Σ0/Σ1 逻辑（大写 Σ） |
| `ror.v` / `shr.v` | 循环右移 / 逻辑右移 |
| `counter.v` | 64 轮计数器 |
| `constants.v` | K[i] 常量表 |
| `wvar.v` | W 变量管理 |

## 4. 核心流程脚本（flow/）

### 4.1 主流程
| 脚本 | 功能 |
|------|------|
| `synth.ys` | Yosys 综合（去 flatten，保留 inout 路径） |
| `openroad_flow_15ns_signoff.tcl` | **签核版** OpenROAD PnR 流程（15ns / 66.7MHz） |
| `openroad_flow_15ns.tcl` | 15ns 流程（非签核版） |
| `openroad_flow_14.3ns.tcl` | 14.3ns 流程（早期版本） |
| `openroad_flow_98mhz.tcl` | 98MHz 尝试（未收敛） |

### 4.2 签核分析
| 脚本 | 功能 | 产出 |
|------|------|------|
| `run_area_report.tcl` | 面积/利用率报告 | 控制台输出 |
| `run_power_ir_signoff.tcl` | 功耗分析 | `SHA256_15ns_power_ir_signoff.rpt` |
| `run_ir_drop_real.tcl` | 真实 IR drop 求解 | `SHA256_15ns_ir_drop_real_signoff.rpt` |
| `run_magic_drc_signoff.tcl` | Magic DRC 签核 | DRC 报告 |
| `run_magic_antenna_check.tcl` | 天线效应检查 | 天线报告 |
| `run_lvs_v6_pos.py` | 晶体管级 LVS（v6-pos 方案） | LVS 报告 |

### 4.3 LVS 辅助脚本
| 脚本 | 功能 |
|------|------|
| `strip_parasitics.py` | 去除寄生电容 + 物理单元 |
| `fix_layout_subckts.py` | 修复 Magic 提取的 subckt |
| `fix_pin_order.py` | 修复 pin 顺序（Magic vs Library SPICE） |
| `rename_clkload_nets.py` | 重命名 CTS 负载 net |
| `make_schematic_spice.py` | 从 Verilog 生成 schematic CDL |
| `gen_sky130_minimal_bb.py` | 生成标准单元 blackbox 模型 |

## 5. 签核报告（硬证据）

| 报告文件 | 对应任务 | 关键指标 |
|---------|---------|---------|
| `SHA256_15ns_power_ir_signoff.rpt` | 16-5 | 功耗 20.3mW, IR drop 估算 ~43mV |
| `SHA256_15ns_ir_drop_real_signoff.rpt` | 17-6 | **真实 IR drop**（VDD 3.19mV / VSS 4.32mV, worst rail 2.4% of budget） |
| `SHA256_15ns_critical_path_analysis.md` | 17-5 | 路径延迟 15.852ns, 40 级逻辑, setup +0.184ns |
| `SHA256_15ns_power_visualization.html` | 17-7 | 功耗饼图 + IR drop 条形图 |
| `SHA256_15ns_vdd_voltage.rpt` | 17-6 | VDD 逐节点电压（502KB） |
| `SHA256_15ns_vss_voltage.rpt` | 17-6 | VSS 逐节点电压（502KB） |
| `vdd_vsrc.txt` / `vss_vsrc.txt` | 17-6 | C4 bump 位置文件 |

## 6. 最终交付物（tape-out ready）

| 文件 | 格式 | 大小 | 说明 |
|------|------|------|------|
| `flow/SHA256_full.gds` | GDSII | 27.9 MB | 完整版图（含 stdcell + 二极管） |
| `flow/SHA256_15ns.def` | DEF | — | 15ns 签核版布局布线 |
| `flow/SHA256_15ns.sdc` | SDC | 446 B | 时序约束 |
| `caravel/user_project_wrapper.v` | Verilog | — | Caravel 集成封装 |

## 7. Caravel 集成（caravel/）

| 文件 | 说明 |
|------|------|
| `user_project_wrapper.v` | Caravel 用户项目封装 RTL |
| `user_project_wrapper.sdc` | 封装时序约束 |
| `config.json` | Caravel 配置 |
| `pin_order.cfg` | 引脚顺序配置 |
| `sta_wrapper.sh` | STA 包装脚本 |

## 8. 门级仿真（flow/sky130_sim/）

| 文件 | 说明 |
|------|------|
| `sky130_fd_sc_hd_minimal_bb.v` | 标准单元行为模型（含 a2bb2oi_1 修正） |
| `verify_bb_vs_lib.py` | BB 模型 vs Liberty 验证 |
| `_stdcells_used.txt` | 设计使用的标准单元列表 |
| `_lib_cells.txt` | 库中所有单元列表 |

## 9. 可清理文件（tmp / debug / 可重新生成）

以下文件为调试过程的临时产物，可安全删除：

### 9.1 临时脚本（flow/tmp_*.sh, tmp_*.py）
共 30+ 个 `tmp_` 前缀文件，包括：
- `tmp_run_rtl*.sh` / `tmp_run_gate*.sh` / `tmp_run_postsim.sh` — 仿真调试
- `tmp_probe_*.sh` / `tmp_probe_*.py` — 单元探测
- `tmp_dump_lib*.sh` — 库文件转储
- `tmp_ab_test.sh` / `tmp_b_pins.sh` — A/B 测试

### 9.2 调试脚本（flow/check_*.sh, debug_*, diag*, peek_*, test_*）
- `check_*.sh` (15 个) — 各类 DEF/LEF/CDL 检查
- `debug_*.tcl` / `debug_*.py` — 调试脚本
- `diag*.sh` / `diag.tcl` — 诊断脚本
- `peek_*.sh` — 报告查看脚本
- `test_*.tcl` / `test_*.py` — 测试脚本

### 9.3 可重新下载的大文件
| 文件 | 大小 | 说明 |
|------|------|------|
| `flow/magic-8.3.681.tgz` | 3.9 MB | Magic 源码包 |
| `flow/netgen-1.5.323.tgz` | 0.5 MB | Netgen 源码包 |
| `flow/sky130A.tar.xz` | 84.7 MB | sky130A PDK 包 |

### 9.4 旧版本产物
- `flow/SHA256_14.3ns_*` — 14.3ns 版本的 GDS/CDL/LVS 报告（已被 15ns 取代）
- `flow/openroad_flow_98mhz*.tcl` — 98MHz 尝试脚本（未收敛）
- `flow/run_12_3b_*.sh` — 早期 LVS 流程脚本（已被 v6-pos 取代）
- `exploratory/` — 原项目探索性实验数据

### 9.5 其他
- `flow/__pycache__/` — Python 缓存
- `flow/_12_4_caravel_mpw_notes.md` — 早期笔记
- `flow/wsl_step*.sh` — WSL 同步脚本（一次性使用）

## 10. 文件分类速查

| 分类 | 文件数 | 说明 |
|------|--------|------|
| 入口文档 | 5 | README, 设计文档, 复盘, 结构, LICENSE |
| RTL 源码 | 19 | Verilog/ 目录（18 RTL 模块 + 1 testbench） |
| 核心流程脚本 | ~15 | openroad_flow, synth, run_lvs, run_ir_drop 等 |
| 签核报告 | 7 | 功耗, IR drop, 关键路径, 可视化, 电压分布 |
| LVS 辅助 | 6 | strip, fix, rename, make, gen 脚本 |
| 最终交付 | 4 | GDS, DEF, SDC, Caravel wrapper |
| 可清理 | ~60+ | tmp_, check_, debug_, diag_, peek_, test_ |
| 可重新下载 | 3 | magic/netgen/sky130A 压缩包 |
