# Magic signoff DRC script — reads DEF (not GDS) to avoid layer mapping issues
# Usage: magic -noconsole -dnull -rcfile sky130A.magicrc -Tcl run_magic_drc_def.tcl

# Read DEF (Magic maps layers correctly from DEF)
def read SHA256_15ns.def

# Load the top cell
load SHA256

# Select top cell
select top cell

# Run DRC in batch
drc catchup

# Count and report violations
set drc_list [drc listall why]
set drc_count [llength $drc_list]

puts ""
puts "============================================"
puts "Magic DRC Signoff Report (DEF-based)"
puts "============================================"
puts "Cell: SHA256"
puts "DEF:  SHA256_15ns.def"
puts "DRC violations: $drc_count"
puts "============================================"

if {$drc_count > 0} {
    puts ""
    puts "Violation details:"
    set i 0
    foreach {rule} $drc_list {
        puts "  [expr {$i+1}]. $rule"
        incr i
        if {$i >= 50} {
            puts "  ... (showing first 50, total $drc_count)"
            break
        }
    }
} else {
    puts ""
    puts "PASS: 0 DRC violations"
}

# Save report
set f [open "SHA256_magic_drc_def_report.txt" w]
puts $f "Magic DRC Signoff Report (DEF-based)"
puts $f "Cell: SHA256"
puts $f "DEF:  SHA256_15ns.def"
puts $f "DRC violations: $drc_count"
puts $f ""
if {$drc_count > 0} {
    set i 0
    foreach {rule} $drc_list {
        puts $f "  [expr {$i+1}]. $rule"
        incr i
    }
} else {
    puts $f "PASS: 0 DRC violations"
}
close $f

puts "Report saved to SHA256_magic_drc_def_report.txt"

# Also extract SPICE for 16-2 (transistor-level LVS)
puts ""
puts "============================================"
puts "Extracting SPICE for transistor-level LVS"
puts "============================================"
extract all
ext2spice hierarchy on
ext2spice subcircuits on
ext2spice format ngspice
ext2spice cthresh 0 rthresh 0
ext2spice -o SHA256_15ns_transistor.spice
puts "SPICE extracted to SHA256_15ns_transistor.spice"

exit
