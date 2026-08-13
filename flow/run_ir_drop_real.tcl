# 17-6 真实 IR drop 求解 (analyze_power_grid)
# 产出: SHA256_15ns_vdd_voltage.rpt, SHA256_15ns_vss_voltage.rpt
#       SHA256_15ns_vdd_pg_error.rpt, SHA256_15ns_vss_pg_error.rpt
#
# 注意: check_power_grid 因 DEF 无电源终端会报 PSM-0025 致命错误，
# 故跳过，直接用 -vsrc 提供 C4 bump 电压源注入点。

set PDK /usr/local/share/pdk/sky130A

# 读取设计
read_lef $PDK/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
read_lef $PDK/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
read_def SHA256_15ns.def
read_liberty $PDK/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_sdc SHA256_15ns.sdc

puts "============================================"
puts "SHA-256 真实 IR drop 求解 (17-6)"
puts "============================================"
puts ""

# 设置电源电压
set_pdnsim_net_voltage -net VDD -voltage 1.8
set_pdnsim_net_voltage -net VSS -voltage 0.0

# 分析 VDD 电源网格
# vdd_vsrc.txt: 4 个 C4 bump 在 VDD met4×met5 stripe 交点
puts "=== 分析 VDD 电源网格 ==="
analyze_power_grid -net VDD \
    -vsrc vdd_vsrc.txt \
    -voltage_file SHA256_15ns_vdd_voltage.rpt \
    -error_file SHA256_15ns_vdd_pg_error.rpt

# 分析 VSS 电源网格
# vss_vsrc.txt: 4 个 C4 bump 在 VSS met4×met5 stripe 交点
puts ""
puts "=== 分析 VSS 电源网格 ==="
analyze_power_grid -net VSS \
    -vsrc vss_vsrc.txt \
    -voltage_file SHA256_15ns_vss_voltage.rpt \
    -error_file SHA256_15ns_vss_pg_error.rpt

puts ""
puts "============================================"
puts "IR drop 求解完成"
puts "============================================"
puts "VDD 电压分布: SHA256_15ns_vdd_voltage.rpt"
puts "VSS 电压分布: SHA256_15ns_vss_voltage.rpt"
puts "VDD 错误: SHA256_15ns_vdd_pg_error.rpt"
puts "VSS 错误: SHA256_15ns_vss_pg_error.rpt"
