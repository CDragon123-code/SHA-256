# OpenROAD flow for SHA-256 -> sky130hd - 15ns (~67MHz) with split bus interface
# Plan B: data_in/data_out/data_oe (no inout) + full flatten

set PDK /home/openroad/OpenROAD/test/sky130hd

# ===== Read design (Plan B split-bus synth netlist) =====
read_lef $PDK/sky130hd.tlef
read_lef $PDK/sky130hd_std_cell.lef
read_liberty $PDK/sky130hd_tt.lib
read_verilog /home/openroad/SHA-256/flow/SHA256_synth.v
link_design SHA256
read_sdc /home/openroad/SHA-256/flow/SHA256_15ns.sdc

set_thread_count 8

# ===== Floorplan =====
initialize_floorplan -site unithd \
  -die_area {0 0 600 600} \
  -core_area {20 20 580 580}

source $PDK/sky130hd.tracks
remove_buffers

# ===== Tapcell =====
tapcell -distance 14 -tapcell_master sky130_fd_sc_hd__tapvpwrvgnd_1

# ===== Power =====
source $PDK/sky130hd.pdn.tcl
pdngen

# ===== Global placement =====
set_global_routing_layer_adjustment met1-met5 0.4
set_routing_layers -signal met1-met5 -clock met3-met5

global_placement -density 0.6 -pad_left 4 -pad_right 4 -skip_io
place_pins -hor_layers met3 -ver_layers met2
global_placement -routability_driven -density 0.6 -pad_left 4 -pad_right 4

# ===== Repair =====
source $PDK/sky130hd.rc
set_wire_rc -signal -layer met2
set_wire_rc -clock -layer met5

estimate_parasitics -placement
repair_design

repair_tie_fanout -separation 0 sky130_fd_sc_hd__conb_1/LO
repair_tie_fanout -separation 0 sky130_fd_sc_hd__conb_1/HI

set_placement_padding -global -left 2 -right 2
detailed_placement

# ===== CTS =====
repair_clock_inverters
clock_tree_synthesis -root_buf sky130_fd_sc_hd__clkbuf_4 -buf_list sky130_fd_sc_hd__clkbuf_4 \
  -sink_clustering_enable -sink_clustering_max_diameter 100
repair_clock_nets
detailed_placement
set_propagated_clock [all_clocks]

# ===== Hold fix before routing (exclude cells with pin access issues) =====
set_dont_use sky130_fd_sc_hd__dlygate4sd3_1
set_dont_use sky130_fd_sc_hd__clkdlybuf4s50_1
set_dont_use sky130_fd_sc_hd__buf_12
set_dont_use sky130_fd_sc_hd__buf_16
estimate_parasitics -placement
repair_timing -hold -allow_setup_violations
detailed_placement

# ===== Routing =====
pin_access
global_route -congestion_iterations 100
repair_antennas -iterations 5
check_antennas
detailed_route -output_drc /home/openroad/SHA-256/flow/route_drc_15ns.rpt

# ===== Post-route hold fix (wrapped — may fail on parasitics state) =====
if {[catch {
  estimate_parasitics -placement
  repair_timing -hold -allow_setup_violations
} err]} {
  puts "WARNING: Post-route hold fix skipped: $err"
}

# ===== Filler =====
filler_placement sky130_fd_sc_hd__fill_*
check_placement

# ===== Write netlist (for gate-level sim) =====
write_verilog /home/openroad/SHA-256/flow/SHA256_15ns_final.v
write_db /home/openroad/SHA-256/flow/SHA256_15ns.odb
write_def /home/openroad/SHA-256/flow/SHA256_15ns.def

# ===== Extraction & Reports =====
if {[catch {
  extract_parasitics -ext_model_file $PDK/sky130hd.rcx_rules
  write_spef /home/openroad/SHA-256/flow/SHA256_15ns.spef
  read_spef /home/openroad/SHA-256/flow/SHA256_15ns.spef
  report_checks -path_delay min_max -format full_clock_expanded -fields {input_pin slew capacitance} -digits 3 > /home/openroad/SHA-256/flow/reports_checks_15ns.rpt
  report_worst_slack -min -digits 3
  report_worst_slack -max -digits 3
  report_tns -digits 3
  report_clock_skew -digits 3
  report_power > /home/openroad/SHA-256/flow/reports_power_15ns.rpt
  report_design_area > /home/openroad/SHA-256/flow/reports_area_15ns.rpt
} err]} {
  puts "WARNING: Extraction/timing reports skipped: $err"
}
