# Magic signoff DRC script for SHA256_15ns_full.gds
# Usage: magic -noconsole -dnull -rcfile sky130A.magicrc -Tcl run_magic_drc.tcl

# Load GDS
gds read SHA256_15ns_full.gds

# Load the top cell
load SHA256_15ns_full

# Select top cell
select top cell

# Run DRC in batch (catchup processes all areas)
drc catchup

# Count and report violations
set drc_list [drc listall why]
set drc_count [llength $drc_list]

puts ""
puts "============================================"
puts "Magic DRC Signoff Report"
puts "============================================"
puts "Cell: SHA256_15ns_full"
puts "GDS:  SHA256_15ns_full.gds"
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

puts ""
puts "DRC check complete."

# Save DRC results to file (avoid clock command)
set f [open "SHA256_magic_drc_report.txt" w]
puts $f "Magic DRC Signoff Report"
puts $f "Cell: SHA256_15ns_full"
puts $f "GDS:  SHA256_15ns_full.gds"
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

puts "Report saved to SHA256_magic_drc_report.txt"

exit
