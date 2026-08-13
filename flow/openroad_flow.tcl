# OpenROAD flow for LDFranck/SHA-256 -> sky130hd
# Based on OpenROAD official aes_sky130hd flow framework

set PDK /home/openroad/OpenROAD/test/sky130hd

# ===== Read design =====
read_lef $PDK/sky130hd.tlef
read_lef $PDK/sky130hd_std_cell.lef
read_liberty $PDK/sky130hd_tt.lib
read_verilog /home/openroad/SHA-256/flow/SHA256_synth.v
link_design SHA256
read_sdc /home/openroad/SHA-256/flow/SHA256.sdc

set_thread_count 8

# ===== Floorplan =====
initialize_floorplan -site unithd \
  -die_area {0 0 600 600} \
  -core_area {20 20 580 580}

# Load routing tracks (REQUIRED for place_pins)
source $PDK/sky130hd.tracks

# remove buffers inserted by synthesis
remove_buffers

# ===== Tapcell insertion =====
tapcell -distance 14 -tapcell_master sky130_fd_sc_hd__tapvpwrvgnd_1

# ===== Power distribution =====
source $PDK/sky130hd.pdn.tcl
pdngen

# ===== Global placement =====
set_global_routing_layer_adjustment met1-met5 0.4
set_routing_layers -signal met1-met5 -clock met3-met5

# Global placement skip IOs
global_placement -density 0.6 -pad_left 4 -pad_right 4 -skip_io

# IO Placement
place_pins -hor_layers met3 -ver_layers met2

# Global placement with placed IOs
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

# ===== Routing =====
pin_access
global_route -congestion_iterations 100
repair_antennas -iterations 5
check_antennas
detailed_route -output_drc /home/openroad/SHA-256/flow/route_drc.rpt
repair_antennas
detailed_route

# ===== Filler =====
filler_placement sky130_fd_sc_hd__fill_*
check_placement

# ===== Extraction & Reports =====
extract_parasitics -ext_model_file $PDK/sky130hd.rcx_rules
write_spef /home/openroad/SHA-256/flow/SHA256.spef
read_spef /home/openroad/SHA-256/flow/SHA256.spef

report_checks -path_delay min_max -format full_clock_expanded -fields {input_pin slew capacitance} -digits 3 > /home/openroad/SHA-256/flow/reports_checks.rpt
report_worst_slack -min -digits 3
report_worst_slack -max -digits 3
report_tns -digits 3
report_clock_skew -digits 3
report_power > /home/openroad/SHA-256/flow/reports_power.rpt
report_design_area > /home/openroad/SHA-256/flow/reports_area.rpt

# ===== Outputs =====
write_db /home/openroad/SHA-256/flow/SHA256.odb
write_def /home/openroad/SHA-256/flow/SHA256.def
write_verilog /home/openroad/SHA-256/flow/SHA256_final.v
