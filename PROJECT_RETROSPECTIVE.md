# SHA-256 芯片设计项目复盘

> **项目**：SHA-256 加密加速器 RTL→GDSII→LVS 全流程  
> **PDK**：sky130A (sky130_fd_sc_hd)  
> **周期**：2026-08-12 ~ 2026-08-13  
> **状态**：TAPEOUT-READY ✅（10 项签核全部通过）  
> **复盘日期**：2026-08-13

---

## 1. 项目里程碑

| 阶段 | 关键成果 | 耗时 |
|------|----------|------|
| RTL 设计 | SHA256.v + 18 子模块，FIPS 180-4 仿真 PASS | — |
| 综合 | Yosys 全 flatten，拆分 inout 端口恢复 QoR | — |
| 布局布线 | OpenROAD 15ns (66.7MHz)，setup +0.184 / hold +0.024 | — |
| GDSII | Magic DEF→GDS + stdcell merge，21MB | — |
| LVS (黑盒) | v6pos 方案，Circuits match uniquely | — |
| LVS (晶体管级) | fix_pin_order.py 修复 pin 顺序，Circuits match uniquely | — |
| DRC / 天线 / 布线 DRC | 全部 0 violation（51 diodes） | — |
| 功耗 + IR drop | 20.3mW，IR drop ~43mV < 180mV budget | — |
| FIPS 后仿 | signoff 网表 ALL PASSED | — |

---

## 2. 核心方法论沉淀

### 2.1 假 PASS 识别——三层验证法

本项目经历了「假 PASS → 诚实揭示 → 真闭环」三个阶段。总结出三层验证法：

**第一层：报告尾部的 Final result**
- 只看 `Final result: Circuits match uniquely` 不够
- 必须同时检查 `Number of devices` 和 `Number of nets` 两侧是否相等
- 案例：TRAE 初版声称 Circuits match，但报告尾部白纸黑字写 `Netlists do not match`，19 个 `no matching net`

**第二层：定量指标交叉验证**
- `grep -c 'no matching net'` 必须为 0
- `NET mismatches: 0` / `DEVICE mismatches: 0`
- devices/nets 两侧数值必须完全相等（如 6549=6549, 6438=6438）
- 不能有「extra nets」「no matching」等残留

**第三层：技术合理性审查**
- 检查是否退回了 blackbox（晶体管级 LVS 应有 `Merged N parallel devices`）
- 检查报告时间戳是否是新生成的（`stat -c '%y'`）
- 检查是否通过「削足适履」拿到 PASS（如强行重命名、删除 cell 而非修复根因）
- 底层晶体管模型（pfet_01v8_hvt/nfet_01v8）作为 placeholder 是正常的，不是缺陷

### 2.2 独立复核流程

**原则：不信 AI 工具的口头结论，只信硬证据**

1. **报告文件验证**：直接读取报告文件内容，不依赖 AI 转述
2. **时间戳验证**：确认报告是最新生成的（对比上次复核时间）
3. **全盘体检**：扫描所有 signoff 产物，不只看被声称通过的那一项
4. **文档一致性扫描**：grep 全文档查找残留矛盾（如一处写 ✅ 另一处写 ⚠️）
5. **重新运行验证**：对关键指标（如 FIPS 后仿）用 signoff 网表重新跑一次

### 2.3 Pin 顺序教训

**根因**：Magic 提取的 pin 顺序与 library SPICE 不一致

```
sky130_fd_sc_hd__clkbuf_4:
  Magic 提取:  X A VGND VPWR VPB VNB
  Library SPICE: A VGND VNB VPB VPWR X
```

**错误做法**：`fix_layout_subckts.py` 只修剪多余 net，不重排 pin 顺序 → 19 个 net mismatch

**正确做法**：`fix_pin_order.py` 
1. 读取两侧 `.subckt` 定义，构建 pin 置换映射
2. 重排全部 6549 个 X-instance 的 net 顺序
3. 对比 schematic CDL，映射 net 命名（6391 个映射，33753 次替换）

**教训**：positional pin 模式下，pin 顺序必须严格对齐 library 定义。Magic 提取的顺序取决于版图中 pin 出现的顺序，不保证与 library 一致。

---

## 3. 技术决策记录

### 3.1 拆分 inout 端口（方案 B）

| 决策 | 选择 | 理由 |
|------|------|------|
| inout 处理 | 拆分为 data_in/data_out/data_oe | Yosys flatten 会删除 inout 路径，拆分后可安全全 flatten |
| 时钟频率 | 15ns (66.7MHz) | 98MHz 不可达（RTL 架构限制），15ns 是 setup/hold 双正 slack 的最低代价 |
| LVS 方案 | v6pos (黑盒) + fix_pin_order (晶体管级) | 黑盒 LVS 验证功能等价，晶体管级 LVS 验证物理一致 |
| 天线修复 | post-route repair_antennas | detailed_route 引入新违规，必须在布线后再修一轮 |

### 3.2 工具版本

| 工具 | 版本 | 用途 |
|------|------|------|
| OpenROAD | 26Q3-23-gb65c274cad | 布局布线 + 时序 + 功耗 |
| Yosys | — | 综合 |
| Magic | 8.3.681 | DRC + GDS + SPICE 提取 |
| Netgen | 1.5.323 | LVS 比对 |
| sky130A PDK | open_pdks | stdcell LEF/GDS/SPICE/CDL |

---

## 4. 签核清单模板（供未来项目复用）

```
□ 1. Magic DRC → 0 violation (DEF-based)
□ 2. 黑盒 LVS → Circuits match uniquely (v6pos)
□ 3. 晶体管级 LVS → Circuits match uniquely (fix_pin_order)
□ 4. 天线效应 → 0 违规 (pre-route + post-route repair_antennas)
□ 5. 布线 DRC → 0 violations (detailed_route -output_drc)
□ 6. FIPS 后仿 → ALL PASSED (signoff 网表)
□ 7. 时序 → setup/hold 双正 slack, TNS=0
□ 8. RTL 源码 → 完整 (顶层 + 子模块)
□ 9. Caravel Wrapper → 已创建 (待 OpenLane)
□ 10. 功耗 + IR drop → IR drop < 10% VDD
```

---

## 5. 关键文件索引

| 类别 | 文件 | 位置 |
|------|------|------|
| RTL | SHA256.v + 18 子模块 | Verilog/ |
| Flow | openroad_flow_15ns_signoff.tcl | flow/ |
| GDS | SHA256_15ns_full.gds (21MB) | flow/ |
| LVS 黑盒 | run_lvs_15ns.py + v6pos report | flow/ |
| LVS 晶体管 | fix_pin_order.py + transistor report | flow/ |
| DRC | SHA256_15ns_magic_drc_signoff.rpt | flow/ |
| 天线 | SHA256_15ns_antenna_signoff.rpt | flow/ |
| 功耗 | SHA256_15ns_power_ir_signoff.rpt | flow/ |
| FIPS | fips_15ns_signoff.vvp | flow/ |
| Caravel | user_project_wrapper.v | caravel/ |

---

## 6. 未完成事项

| 事项 | 原因 | 影响 |
|------|------|------|
| Caravel 集成 | Docker/OpenLane 环境限制（C: 仅 3.4GB 可用） | 非设计本体，MPW 提交配套 |
| make precheck-local | 依赖 Caravel 集成 | 同上 |
| 448-bit 测试向量 | RTL 架构限制（单块消息处理） | 功能覆盖率，非 signoff 必需 |

---

## 7. 经验教训汇总

1. **不信假 PASS**：AI 工具可能声称通过但实际未通过，必须独立验证报告文件
2. **pin 顺序是隐形陷阱**：Magic 提取与 library SPICE 的 pin 顺序不一致是常见问题
3. **detailed_route 引入新天线违规**：必须在布线后再跑一轮 repair_antennas
4. **拆分 inout 是最佳实践**：避免 Yosys flatten 删除 inout 路径，恢复 QoR
5. **v6pos LVS 消除命名差异**：两侧同一脚本生成 + positional pin + .INCLUDE 同一库
6. **晶体管级 LVS 需 SPICE 库（非 CDL）**：Magic 用 X-device，CDL 用 M-device，类型不匹配
7. **文档一致性扫描不可少**：grep 全文档查找残留矛盾，避免一处 ✅ 一处 ⚠️
8. **全盘体检胜过单点验证**：扫描所有 signoff 产物的时间戳和内容，不只看被声称通过的那一项
