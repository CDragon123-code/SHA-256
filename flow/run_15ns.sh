#!/bin/bash
set +e
cd /home/openroad/SHA-256/flow

echo "=============================================================="
echo " Plan B + 15ns clock: OpenROAD + Gate-level FIPS"
echo "=============================================================="

# --- Sync files ---
cp /mnt/d/OpenROAD/SHA-256/flow/SHA256_15ns.sdc .
cp /mnt/d/OpenROAD/SHA-256/flow/openroad_flow_15ns.tcl .

# --- Step 1: OpenROAD ---
echo "--- Step 1: OpenROAD 15ns ---"
/home/openroad/OpenROAD/build/bin/openroad -no_splash -exit openroad_flow_15ns.tcl > _openroad_15ns.log 2>&1
echo "OpenROAD exit: $?"
echo ""
echo "=== Timing ==="
grep -E "worst slack|tns|Design area" _openroad_15ns.log
echo ""

# --- Step 2: Check cell coverage ---
echo "--- Step 2: Cell coverage ---"
grep -oE 'sky130_fd_sc_hd__[a-z0-9_]+' SHA256_15ns_final.v | sort -u > /tmp/nl15.txt
grep -oE '^module sky130_fd_sc_hd__[a-z0-9_]+' sky130_sim/sky130_fd_sc_hd_minimal_bb.v | sed 's/^module //' | sort -u > /tmp/bb15.txt
MISSING=$(comm -23 /tmp/nl15.txt /tmp/bb15.txt)
if [ -z "$MISSING" ]; then
    echo "All cells covered"
else
    echo "MISSING: $MISSING"
fi

# --- Step 3: Gate-level FIPS ---
echo ""
echo "--- Step 3: Gate-level FIPS sim ---"
iverilog -Wall -g2012 -D POSTLAYOUT \
  -o fips_15ns.vvp \
  fips_180_4_post_sim_tb.v \
  SHA256_15ns_final.v \
  sky130_sim/sky130_fd_sc_hd_minimal_bb.v \
  > _compile_15ns.log 2>&1
if [ $? -ne 0 ]; then
    echo "COMPILE FAILED"
    tail -30 _compile_15ns.log
    exit 2
fi
timeout 300 vvp fips_15ns.vvp > _run_15ns.log 2>&1
echo ""
grep -E "PASS|FAIL|ALL FIPS" _run_15ns.log
echo ""
echo "--- Last 20 lines ---"
tail -20 _run_15ns.log

echo ""
echo "=============================================================="
echo " 15ns PLAN B SUMMARY"
echo "=============================================================="
echo "Setup slack: $(grep 'worst slack max' _openroad_15ns.log || echo 'UNKNOWN')"
echo "Hold slack:  $(grep 'worst slack min' _openroad_15ns.log || echo 'UNKNOWN')"
echo "TNS:         $(grep 'tns max' _openroad_15ns.log || echo 'UNKNOWN')"
echo "Area:        $(grep 'Design area' _openroad_15ns.log || echo 'UNKNOWN')"
echo "Gate FIPS:   $(grep -o 'ALL FIPS.*' _run_15ns.log || echo 'UNKNOWN')"
