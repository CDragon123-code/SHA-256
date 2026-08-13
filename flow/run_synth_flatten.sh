#!/bin/bash
set -e
cd /home/openroad/SHA-256/flow

echo "=============================================================="
echo " Yosys Synthesis with selective flatten (keep_hierarchy on expansion)"
echo "=============================================================="

# Sync RTL from Windows
cp /mnt/d/OpenROAD/SHA-256/Verilog/expansion.v /home/openroad/SHA-256/Verilog/expansion.v
cp /mnt/d/OpenROAD/SHA-256/Verilog/SHA256.v /home/openroad/SHA-256/Verilog/SHA256.v
cp /mnt/d/OpenROAD/SHA-256/Verilog/wvar.v /home/openroad/SHA-256/Verilog/wvar.v
cp /mnt/d/OpenROAD/SHA-256/Verilog/compression.v /home/openroad/SHA-256/Verilog/compression.v
cp /mnt/d/OpenROAD/SHA-256/flow/synth.ys /home/openroad/SHA-256/flow/synth.ys

echo "--- Step 1: Run Yosys ---"
yosys -s synth.ys 2>&1 | tee _yosys_selflatten.log

echo ""
echo "--- Step 2: Check if expansion module is preserved ---"
grep -c '^module expansion' SHA256_synth.v && echo "expansion module PRESERVED" || echo "expansion module NOT found"
echo ""
echo "--- Step 3: Check all modules in netlist ---"
grep '^module ' SHA256_synth.v
echo ""
echo "--- Step 4: Check inout data path preserved ---"
grep -n 'data\[' SHA256_synth.v | head -10
echo ""
echo "--- Step 5: Synth stats ---"
tail -30 _yosys_selflatten.log
echo ""
echo "Done. Netlist at SHA256_synth.v"
