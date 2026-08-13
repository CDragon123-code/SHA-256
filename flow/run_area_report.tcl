# 17-4 面积/利用率格式化报告
# 产出: SHA256_15ns_area_utilization.rpt

set PDK /usr/local/share/pdk/sky130A

# 读 LEF
read_lef $PDK/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
read_lef $PDK/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef

# 读 DEF
read_def SHA256_15ns.def

puts "============================================"
puts "SHA-256 面积/利用率报告 (17-4)"
puts "============================================"
puts ""

# 设计面积
puts "=== report_design_area ==="
report_design_area

# 利用率
puts ""
puts "=== report_units ==="
report_units

# 尝试 report_utilization（如果不存在，用其他方式）
puts ""
puts "=== 单元统计 ==="
set db [ord::get_db]
set block [[$db getChip] getBlock]
set core_area [$block getCoreArea]
set die_area [$block getDieArea]

# 计算 core 面积（平方微米）
set core_dx [expr [ord::dbu_to_microns [$core_area getDX]]]
set core_dy [expr [ord::dbu_to_microns [$core_area getDY]]]
set core_area_um2 [expr $core_dx * $core_dy]

set die_dx [expr [ord::dbu_to_microns [$die_area getDX]]]
set die_dy [expr [ord::dbu_to_microns [$die_area getDY]]]
set die_area_um2 [expr $die_dx * $die_dy]

puts "Die 面积: ${die_dx}μm × ${die_dy}μm = ${die_area_um2} μm²"
puts "Core 面积: ${core_dx}μm × ${core_dy}μm = ${core_area_um2} μm²"

# 统计实例
set insts [$block getInsts]
set inst_count [llength $insts]
puts "实例总数: $inst_count"

# 计算标准单元总面积
set stdcell_area 0
set macro_area 0
foreach inst $insts {
    set master [$inst getMaster]
    set w [ord::dbu_to_microns [$master getWidth]]
    set h [ord::dbu_to_microns [$master getHeight]]
    set area [expr $w * $h]
    if {[$master isBlock]} {
        set macro_area [expr $macro_area + $area]
    } else {
        set stdcell_area [expr $stdcell_area + $area]
    }
}

puts "标准单元总面积: ${stdcell_area} μm²"
puts "宏单元总面积: ${macro_area} μm²"
puts ""

# 利用率
if {$core_area_um2 > 0} {
    set util [expr ($stdcell_area + $macro_area) / $core_area_um2 * 100]
    set stdcell_util [expr $stdcell_area / $core_area_um2 * 100]
    puts "总利用率 (stdcell+macro)/core: [format "%.2f" $util]%"
    puts "标准单元利用率 stdcell/core: [format "%.2f" $stdcell_util]%"
}

puts ""
puts "============================================"
puts "报告完成"
puts "============================================"
