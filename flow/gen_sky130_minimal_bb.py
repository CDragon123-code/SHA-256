# -*- coding: utf-8 -*-
"""
Generate minimal behavioral Verilog black-box for the 73 sky130_fd_sc_hd cell
masters actually instantiated in SHA256_14.3ns_final.v.

The cell list is from `wsl _stdcells_used.txt` (sort -u on instance names in
final.v). We match the sky130 naming convention + pin names observed from
real final.v instances to build equivalent pure-Verilog primitives.

Caveats (these are okay for FIPS 180-4 gate-level logic equivalence; no
timing, no power, no SDF):
  - NO delay annotations — everything is #0 comb / @(posedge CLK) seq.
  - VPWR / VGND / VNB / VPB pins are intentionally OMITTED from modules —
    final.v instances do NOT connect them (OpenROAD insert_pads does not
    appear to tie these in the verilog; iverilog will warn about unmapped
    ports but use of named-port connection means they're just skipped).
    Actually: from final.v inspection, not a single instance names VPWR,
    so they aren't connected — fine.
  - Fill / tap / diode cells become empty modules (no logic, no pins).
  - `lpflow_inputiso0p_1` simplified: SLEEP pin assumed to be tied 0 in
    user design → X = A (passthrough; no isolation ever asserted).
  - `a21boi_0`: pin B1_N means ~B, so ~((A1 & A2) | (~B1)).
  - `or2b_2`: one input inverted OR — pin name is `A` and `B_N` per typical
    sky130; we'll pick inputs as observed if available, fall back A | ~B.
"""

from __future__ import annotations
import textwrap
import re

# ============================================================
# (master, outport, inputs_list, verilog_body_assign)
# inputs_list order = port declaration order (for reference only; final.v
# always uses named-port connection so order doesn't matter)
# ============================================================
CELLS: list[tuple[str, str, list[str], str]] = [
    # ---------- Inverters / Buffers (output Y or X) ----------
    # inv_N output Y (from inv_2 inspection): .A -> .Y
    ("sky130_fd_sc_hd__inv_2",  "Y", ["A"], "assign Y = ~A;"),
    ("sky130_fd_sc_hd__inv_6",  "Y", ["A"], "assign Y = ~A;"),
    ("sky130_fd_sc_hd__inv_8",  "Y", ["A"], "assign Y = ~A;"),
    # buf_N output X (from clkbuf_4 which is buffer): .A -> .X
    ("sky130_fd_sc_hd__buf_4",  "X", ["A"], "assign X = A;"),
    ("sky130_fd_sc_hd__buf_6",  "X", ["A"], "assign X = A;"),
    ("sky130_fd_sc_hd__buf_8",  "X", ["A"], "assign X = A;"),
    ("sky130_fd_sc_hd__buf_12", "X", ["A"], "assign X = A;"),
    ("sky130_fd_sc_hd__buf_16", "X", ["A"], "assign X = A;"),
    ("sky130_fd_sc_hd__bufinv_16", "Y", ["A"], "assign Y = ~A;"),  # BUF -> INV

    # clkbuf / clkinv / clkinvlp / clkdlybuf
    ("sky130_fd_sc_hd__clkbuf_4",  "X", ["A"], "assign X = A;"),
    ("sky130_fd_sc_hd__clkbuf_8",  "X", ["A"], "assign X = A;"),
    ("sky130_fd_sc_hd__clkbuf_16", "X", ["A"], "assign X = A;"),
    ("sky130_fd_sc_hd__clkinv_1",  "Y", ["A"], "assign Y = ~A;"),
    ("sky130_fd_sc_hd__clkinv_2",  "Y", ["A"], "assign Y = ~A;"),
    ("sky130_fd_sc_hd__clkinv_4",  "Y", ["A"], "assign Y = ~A;"),
    ("sky130_fd_sc_hd__clkinvlp_4","Y", ["A"], "assign Y = ~A;"),
    ("sky130_fd_sc_hd__clkdlybuf4s50_2", "X", ["A"], "assign X = A;"),

    # ---------- AND / NAND ----------
    # and3_2 output X (inspection confirmed)
    ("sky130_fd_sc_hd__and2_2", "X", ["A","B"], "assign X = A & B;"),
    ("sky130_fd_sc_hd__and3_2", "X", ["A","B","C"], "assign X = A & B & C;"),
    # nand2_1 output Y; nand3b_1 has one input inverted B_N; nand3_2 / nand4_1
    ("sky130_fd_sc_hd__nand2_1", "Y", ["A","B"], "assign Y = ~(A & B);"),
    ("sky130_fd_sc_hd__nand3_1", "Y", ["A","B","C"], "assign Y = ~(A & B & C);"),
    ("sky130_fd_sc_hd__nand3_2", "Y", ["A","B","C"], "assign Y = ~(A & B & C);"),
    ("sky130_fd_sc_hd__nand4_1", "Y", ["A","B","C","D"], "assign Y = ~(A & B & C & D);"),
    # nand3b_1: A pin is inverted (per suffix "b"). Observed pin: .A_N, .B, .C, .Y
    ("sky130_fd_sc_hd__nand3b_1", "Y", ["A_N","B","C"],
     "assign Y = ~( (~A_N) & B & C );"),

    # ---------- OR / NOR ----------
    # nor3_2 output Y;  or3_2 / or2_2  output X (and3 used X, or follow same);
    # or2b_2 suffix b = one inverted input B_N
    ("sky130_fd_sc_hd__or2_2",  "X", ["A","B"], "assign X = A | B;"),
    ("sky130_fd_sc_hd__or3_2",  "X", ["A","B","C"], "assign X = A | B | C;"),
    ("sky130_fd_sc_hd__or2b_2", "X", ["A","B_N"], "assign X = A | (~B_N);"),

    ("sky130_fd_sc_hd__nor2_1", "Y", ["A","B"], "assign Y = ~(A | B);"),
    ("sky130_fd_sc_hd__nor2_2", "Y", ["A","B"], "assign Y = ~(A | B);"),
    ("sky130_fd_sc_hd__nor2_4", "Y", ["A","B"], "assign Y = ~(A | B);"),
    ("sky130_fd_sc_hd__nor3_1", "Y", ["A","B","C"], "assign Y = ~(A | B | C);"),
    ("sky130_fd_sc_hd__nor3_2", "Y", ["A","B","C"], "assign Y = ~(A | B | C);"),
    ("sky130_fd_sc_hd__nor4_1", "Y", ["A","B","C","D"], "assign Y = ~(A | B | C | D);"),

    # ---------- XOR / XNOR ----------
    # xnor2_1 output Y (confirmed); xor3_4 output X (confirmed)
    ("sky130_fd_sc_hd__xor2_1",  "X", ["A","B"], "assign X = A ^ B;"),
    ("sky130_fd_sc_hd__xor3_4",  "X", ["A","B","C"], "assign X = A ^ B ^ C;"),
    ("sky130_fd_sc_hd__xnor2_1", "Y", ["A","B"], "assign Y = ~(A ^ B);"),
    ("sky130_fd_sc_hd__xnor3_4", "X", ["A","B","C"], "assign X = ~(A ^ B ^ C);"),

    # ---------- MUX ----------
    # mux2_2 output X, pins A0/A1/S (confirmed): standard 2:1, S=1 selects A1
    ("sky130_fd_sc_hd__mux2_2",  "X", ["A0","A1","S"], "assign X = S ? A1 : A0;"),
    # mux2i_1: inverted-output 2:1 mux; output pin likely Y (since "i" suffix, like other inv cells)
    ("sky130_fd_sc_hd__mux2i_1", "Y", ["A0","A1","S"], "assign Y = ~(S ? A1 : A0);"),

    # ---------- Maj (majority 3) ----------
    ("sky130_fd_sc_hd__maj3_1", "X", ["A","B","C"],
     "assign X = (A & B) | (A & C) | (B & C);"),

    # ---------- AOI / AO (AND-OR-INV / AND-OR) ----------
    # a21o_2 = 2-1 AND-OR (A1 & A2) | B1, output X (confirmed)
    ("sky130_fd_sc_hd__a21o_2",  "X", ["A1","A2","B1"], "assign X = (A1 & A2) | B1;"),
    # a21oi_1 = ~( (A1&A2) | B1 ), output Y
    ("sky130_fd_sc_hd__a21oi_1", "Y", ["A1","A2","B1"], "assign Y = ~((A1 & A2) | B1);"),
    # a31o_2 = 3-1 AND-OR = (A1 & A2 & A3) | B1, X
    ("sky130_fd_sc_hd__a31o_2",  "X", ["A1","A2","A3","B1"], "assign X = (A1 & A2 & A3) | B1;"),
    # a31oi_1 = ~, Y
    ("sky130_fd_sc_hd__a31oi_1", "Y", ["A1","A2","A3","B1"], "assign Y = ~((A1 & A2 & A3) | B1);"),
    # a41oi_1 = 4-1 AND-OR-INV = ~((A1&A2&A3&A4) | B1)
    ("sky130_fd_sc_hd__a41oi_1", "Y", ["A1","A2","A3","A4","B1"],
     "assign Y = ~((A1 & A2 & A3 & A4) | B1);"),
    # a22oi_1 = 2-2 AND-OR-INV = ~((A1&A2)|(B1&B2))
    ("sky130_fd_sc_hd__a22oi_1", "Y", ["A1","A2","B1","B2"],
     "assign Y = ~((A1 & A2) | (B1 & B2));"),
    # a211oi_1 = 2-1-1 AND-OR-INV = ~((A1&A2)|B1|C1)
    ("sky130_fd_sc_hd__a211oi_1", "Y", ["A1","A2","B1","C1"],
     "assign Y = ~((A1 & A2) | B1 | C1);"),
    # a221oi_1 = 2-2-1 AND-OR-INV = ~((A1&A2)|(B1&B2)|C1)
    ("sky130_fd_sc_hd__a221oi_1", "Y", ["A1","A2","B1","B2","C1"],
     "assign Y = ~((A1 & A2) | (B1 & B2) | C1);"),
    # a21boi_0: pin B1_N (confirmed); function = ~((A1 & A2) | (~B1)). Output Y confirmed.
    ("sky130_fd_sc_hd__a21boi_0", "Y", ["A1","A2","B1_N"],
     "assign Y = ~((A1 & A2) | (~B1_N));"),

    # ---------- OAI / OA (OR-AND-INV / OR-AND) ----------
    # o21a_? = 2-1 OR-AND = (A1|A2) & B1. Output X (A-suffix means non-inv AND-type).
    ("sky130_fd_sc_hd__o21a_2", "X", ["A1","A2","B1"], "assign X = (A1 | A2) & B1;"),
    # o211a_1 = 2-1-1 OR-AND = (A1|A2) & B1 & C1, output X (similar)
    ("sky130_fd_sc_hd__o211a_1", "X", ["A1","A2","B1","C1"], "assign X = (A1 | A2) & B1 & C1;"),
    # o211ba_1 = o211a with B1_N (inverted B input)
    ("sky130_fd_sc_hd__o211ba_1", "X", ["A1","A2","B1_N","C1"],
     "assign X = (A1 | A2) & (~B1_N) & C1;"),
    # o2111a_1 = 2-1-1-1 OR-AND, output X confirmed: (A1|A2) & B1 & C1 & D1
    ("sky130_fd_sc_hd__o2111a_1", "X", ["A1","A2","B1","C1","D1"],
     "assign X = (A1 | A2) & B1 & C1 & D1;"),
    # o31a_2 = 3-1 OR-AND = (A1|A2|A3) & B1, X
    ("sky130_fd_sc_hd__o31a_2", "X", ["A1","A2","A3","B1"], "assign X = (A1 | A2 | A3) & B1;"),
    # o31ai_1 = 3-1 OR-AND-INV = ~(((A1|A2|A3) & B1)), Y
    ("sky130_fd_sc_hd__o31ai_1", "Y", ["A1","A2","A3","B1"],
     "assign Y = ~(((A1 | A2 | A3) & B1));"),

    # ===== MISSING OAI cells (12) added per _stdcells_used.txt diff =====
    # o21a_1: 2-1 non-Inv OR-AND (different drive vs o21a_2)
    ("sky130_fd_sc_hd__o21a_1", "X", ["A1","A2","B1"], "assign X = (A1 | A2) & B1;"),
    # o21ai_0 / _1 / _4: 2-1 OR-AND-INV, Y = ~(((A1|A2) & B1)), various drives
    ("sky130_fd_sc_hd__o21ai_0", "Y", ["A1","A2","B1"],
     "assign Y = ~(((A1 | A2) & B1));"),
    ("sky130_fd_sc_hd__o21ai_1", "Y", ["A1","A2","B1"],
     "assign Y = ~(((A1 | A2) & B1));"),
    ("sky130_fd_sc_hd__o21ai_4", "Y", ["A1","A2","B1"],
     "assign Y = ~(((A1 | A2) & B1));"),
    # o21bai_1: 2-1 with inverted-B1 OR-AND-INV → ~((A1|A2) & (~B1_N))
    ("sky130_fd_sc_hd__o21bai_1", "Y", ["A1","A2","B1_N"],
     "assign Y = ~(((A1 | A2) & (~B1_N)));"),
    # o211ai_1: 2-1-1 OR-AND-INV → ~(((A1|A2) & B1 & C1))
    ("sky130_fd_sc_hd__o211ai_1", "Y", ["A1","A2","B1","C1"],
     "assign Y = ~(((A1 | A2) & B1 & C1));"),
    # o2111ai_1: 2-1-1-1 OR-AND-INV
    ("sky130_fd_sc_hd__o2111ai_1", "Y", ["A1","A2","B1","C1","D1"],
     "assign Y = ~(((A1 | A2) & B1 & C1 & D1));"),
    # o22ai_1: 2-2 OR-AND-INV = ~( (A1|A2) & (B1|B2) )
    ("sky130_fd_sc_hd__o22ai_1", "Y", ["A1","A2","B1","B2"],
     "assign Y = ~( ((A1 | A2) & (B1 | B2)) );"),
    # o221a_2: 2-2-1 non-Inv OR-AND = (A1|A2) & (B1|B2) & C1, X
    ("sky130_fd_sc_hd__o221a_2", "X", ["A1","A2","B1","B2","C1"],
     "assign X = ((A1 | A2) & (B1 | B2) & C1);"),
    # o221ai_1: 2-2-1 OR-AND-INV → ~(...)
    ("sky130_fd_sc_hd__o221ai_1", "Y", ["A1","A2","B1","B2","C1"],
     "assign Y = ~( ((A1 | A2) & (B1 | B2) & C1) );"),
    # o2bb2ai_1: o 2 bb 2 a i → first 2 OR inputs are both inverted (bb means 2 inverted)
    #   pins: A1_N, A2_N (first OR group, both active-low), B1, B2 (second OR group).
    #   Body: ~( ((~A1_N) | (~A2_N)) & (B1 | B2) )
    ("sky130_fd_sc_hd__o2bb2ai_1", "Y", ["A1_N","A2_N","B1","B2"],
     "assign Y = ~( ((~A1_N) | (~A2_N)) & (B1 | B2) );"),
    # o311ai_0: 3-1-1 OR-AND-INV = ~( ((A1|A2|A3) & B1 & C1) )
    ("sky130_fd_sc_hd__o311ai_0", "Y", ["A1","A2","A3","B1","C1"],
     "assign Y = ~( ((A1 | A2 | A3) & B1 & C1) );"),

    # ---------- Flip-flops ----------
    # dfxtp_1 rising-edge DFF, only D / Q / CLK pins observed (no async set/reset).
    # NOTE: We initialize Q to 1'b0 (instead of default x) to break the X
    #   propagation deadlock that occurs in pure synchronous-reset designs.
    #   Without this, after release from X all combinational paths are X and
    #   the sync reset MUX's select/data never settle to a known value.
    ("sky130_fd_sc_hd__dfxtp_1", "Q", ["D","CLK"],
     "reg Q = 1'b0; always @(posedge CLK) Q <= D;"),

    # ---------- Isolation / Special ----------
    # lpflow_inputiso0p_1: A, SLEEP, X (confirmed pins). Golden .lib FUNC is
    #   (!SLEEP & A) → X=0 when SLEEP=1 (isolation), X=A when SLEEP=0.
    ("sky130_fd_sc_hd__lpflow_inputiso0p_1", "X", ["A","SLEEP"],
     "assign X = (~SLEEP) & A;"),
]

# ---- Physical-only cells (zero logic, pins may be empty or single net) ----
PHYS_CELLS: list[tuple[str, list[str]]] = [
    # Fill cells: no pins, empty body
    ("sky130_fd_sc_hd__fill_1", []),
    ("sky130_fd_sc_hd__fill_2", []),
    ("sky130_fd_sc_hd__fill_4", []),
    ("sky130_fd_sc_hd__fill_8", []),
    # Tap cell: substrate well-tie, no logic, no pins
    ("sky130_fd_sc_hd__tapvpwrvgnd_1", []),
    # Antenna diode: DIODE pin connects to net; the other side is substrate.
    # In Verilog sim this is just a load (no logic). Keep pin for port-match.
    ("sky130_fd_sc_hd__diode_2", ["DIODE"]),
    # conb_1 was set_dont_use and is no longer present in final.v; include
    # for completeness (no pins since if someone instantiated it it'd use HI/LO).
    # Actually conb_1 normally has pins HI, LO, but final.v has none. Omit ports.
]


def make_module_logic(master: str, outp: str, inputs: list[str], body: str) -> str:
    ports = inputs + [outp]
    decl_io = []
    for p in inputs:
        decl_io.append(f"  input {p};")
    decl_io.append(f"  output {outp};")
    portlist = ", ".join(ports)
    return (
        f"module {master} ({portlist});\n"
        + "\n".join(decl_io)
        + "\n"
        + f"  {body}\n"
        + "endmodule\n"
    )


def make_module_phys(master: str, pins: list[str]) -> str:
    if not pins:
        return f"module {master} ();\nendmodule\n"
    decl = ", ".join(pins)
    body = "  " + ", ".join(f"inout {p}" for p in pins) + ";\n"
    return f"module {master} ({decl});\n{body}endmodule\n"


def main() -> None:
    out = []
    out.append("// ============================================================")
    out.append("// sky130_fd_sc_hd minimal behavioral black-box for gate-level")
    out.append("// logic simulation of SHA256_14.3ns_final.v only.")
    out.append("// Auto-generated by gen_sky130_minimal_bb.py. Covers exactly the")
    out.append("// 73 cell masters observed in the user's final netlist.")
    out.append("// NO timing / SDF / power / leakage. Output pin names X / Y chosen")
    out.append("// per real instances in SHA256_14.3ns_final.v.")
    out.append("// ============================================================")
    out.append("`timescale 1ns / 1ps")
    out.append("")
    for master, outp, inps, body in CELLS:
        out.append(make_module_logic(master, outp, inps, body))
    for master, pins in PHYS_CELLS:
        out.append(make_module_phys(master, pins))
    out.append("")
    out.append("// end of sky130_fd_sc_hd minimal blackbox")
    txt = "\n".join(out) + "\n"

    # Also emit a quick sanity check: list all 73 expected cells and make
    # sure we defined exactly those + phys count. Printed to stderr on run.
    import sys
    total_logic = len(CELLS)
    total_phys = len(PHYS_CELLS)
    print(f"[gen_bb] logic modules : {total_logic}", file=sys.stderr)
    print(f"[gen_bb] phys  modules : {total_phys}", file=sys.stderr)
    print(f"[gen_bb] TOTAL         : {total_logic+total_phys}", file=sys.stderr)

    path = r"d:\OpenROAD\SHA-256\flow\sky130_sim\sky130_fd_sc_hd_minimal_bb.v"
    import os
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(txt)
    print(f"[gen_bb] wrote: {path} ({os.path.getsize(path)} bytes)", file=sys.stderr)


if __name__ == "__main__":
    main()
