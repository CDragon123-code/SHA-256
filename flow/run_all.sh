#!/bin/bash
#============================================================
# SHA-256 ASIC 一条龙复现脚本 (17-8)
# 从 RTL 综合到 Signoff 全流程
#============================================================
# 用法:
#   cd flow
#   bash run_all.sh           # 全流程
#   bash run_all.sh --skip-synth  # 跳过综合（已有 netlist）
#   bash run_all.sh --signoff-only # 只跑签核分析
#============================================================

set -e

# ---- 配置 ----
DESIGN=SHA256
CLOCK=15ns
PDK_PATH=${PDK_PATH:-/usr/local/share/pdk/sky130A}
OPENROAD=${OPENROAD:-openroad}
YOSYS=${YOSYS:-yosys}
MAGIC=${MAGIC:-magic}
NETGEN=${NETGEN:-netgen}
IVERILOG=${IVERILOG:-iverilog}

# ---- 颜色 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

check_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "${RED}[MISS] $1 not found${NC}"
        return 1
    fi
    echo -e "${GREEN}[OK]   $1 found${NC}"
    return 0
}

run_step() {
    local name="$1"
    local cmd="$2"
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}STEP: $name${NC}"
    echo -e "${BLUE}========================================${NC}"
    if eval "$cmd"; then
        echo -e "${GREEN}[$name] PASS${NC}"
        PASS=$((PASS+1))
    else
        echo -e "${RED}[$name] FAIL${NC}"
        FAIL=$((FAIL+1))
    fi
}

# ---- 参数解析 ----
SKIP_SYNTH=0
SIGNOFF_ONLY=0
for arg in "$@"; do
    case $arg in
        --skip-synth) SKIP_SYNTH=1 ;;
        --signoff-only) SIGNOFF_ONLY=1; SKIP_SYNTH=1 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

#============================================================
# 0. 环境检查
#============================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}SHA-256 ASIC Full Flow (run_all.sh)${NC}"
echo -e "${BLUE}Design: $DESIGN | Clock: $CLOCK | PDK: sky130A${NC}"
echo -e "${BLUE}========================================${NC}"

echo ""
echo "Checking tools..."
check_tool "$OPENROAD" || exit 1
check_tool "$YOSYS" || exit 1
check_tool "$MAGIC" || exit 1
check_tool "$IVERILOG" || exit 1

if [ ! -d "$PDK_PATH" ]; then
    echo -e "${RED}[ERROR] PDK not found at $PDK_PATH${NC}"
    echo "Set PDK_PATH environment variable or install open_pdks"
    exit 1
fi
echo -e "${GREEN}[OK]   PDK at $PDK_PATH${NC}"

#============================================================
# 1. RTL 仿真
#============================================================
if [ $SIGNOFF_ONLY -eq 0 ]; then
    run_step "RTL Simulation" \
        "cd ../Verilog && $IVERILOG -o /tmp/sha256_rtl_sim SHA256.v SHA256_testbench.v && vvp /tmp/sha256_rtl_sim && cd ../flow"
fi

#============================================================
# 2. Yosys 综合
#============================================================
if [ $SKIP_SYNTH -eq 0 ]; then
    run_step "Synthesis (Yosys)" \
        "$YOSYS synth.ys"
fi

#============================================================
# 3. OpenROAD PnR (15ns 签核版)
#============================================================
if [ $SIGNOFF_ONLY -eq 0 ]; then
    run_step "OpenROAD PnR (15ns signoff)" \
        "$OPENROAD -no_init openroad_flow_15ns_signoff.tcl"
fi

#============================================================
# 4. 面积报告
#============================================================
run_step "Area Report" \
    "$OPENROAD -no_init run_area_report.tcl"

#============================================================
# 5. DRC (Magic)
#============================================================
run_step "DRC (Magic)" \
    "$MAGIC -dnull -noconsole < run_magic_drc_signoff.tcl"

#============================================================
# 6. 天线效应检查
#============================================================
run_step "Antenna Check" \
    "$OPENROAD -no_init run_antenna_check.tcl"

#============================================================
# 7. LVS (晶体管级)
#============================================================
run_step "LVS (Transistor-level)" \
    "python3 run_lvs_v6_pos.py"

#============================================================
# 8. 功耗分析
#============================================================
run_step "Power Analysis" \
    "$OPENROAD -no_init run_power_ir_signoff.tcl"

#============================================================
# 9. IR drop 真实求解
#============================================================
run_step "IR Drop (analyze_power_grid)" \
    "$OPENROAD -no_init run_ir_drop_real.tcl"

#============================================================
# 10. 门级后仿 (FIPS 180-4)
#============================================================
if [ $SIGNOFF_ONLY -eq 0 ]; then
    run_step "Gate-level Post-PnR Simulation (FIPS 180-4)" \
        "$IVERILOG -I ../Verilog -o /tmp/sha256_gate_sim ../flow/fips_180_4_post_sim_tb.v && vvp /tmp/sha256_gate_sim"
fi

#============================================================
# Summary
#============================================================
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "PASS: ${GREEN}$PASS${NC} | FAIL: ${RED}$FAIL${NC}"
echo ""
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All steps passed! Design is signoff ready.${NC}"
else
    echo -e "${RED}$FAIL step(s) failed. Check logs above.${NC}"
fi

#============================================================
# 产出文件清单
#============================================================
echo ""
echo "Key output files:"
echo "  SHA256_15ns.def                          (布局布线)"
echo "  SHA256_full.gds                          (GDSII 版图)"
echo "  SHA256_15ns_power_ir_signoff.rpt        (功耗报告)"
echo "  SHA256_15ns_ir_drop_real_signoff.rpt    (IR drop 报告)"
echo "  SHA256_15ns_critical_path_analysis.md   (关键路径分析)"
echo "  SHA256_15ns_power_visualization.html     (功耗可视化)"
echo ""
echo "Done."
