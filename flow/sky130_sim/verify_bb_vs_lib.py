# -*- coding: utf-8 -*-
"""
Auto verify sky130_fd_sc_hd minimal bb (CELLS list in gen_sky130_minimal_bb.py)
vs golden pin/function table extracted from sky130 .lib (_lib_cells.txt).

Brute-force exhaustive truth-table for every combinational cell with a single
output pin + ≤8 inputs. Prints:
  - pin-list mismatches
  - FUNC vs body mismatches (with 1st failing vector)
"""
from __future__ import annotations
import sys, os, re, itertools
sys.path.insert(0, r"d:\OpenROAD\SHA-256\flow")
from gen_sky130_minimal_bb import CELLS, PHYS_CELLS

LIB_PATH = r"d:\OpenROAD\SHA-256\flow\sky130_sim\_lib_cells.txt"
MY_CELLS = {m: (out, ins, body) for (m, out, ins, body) in CELLS}
PHYS = {m for m, *_ in PHYS_CELLS}

# ============================================================
# 1. Parse _lib_cells.txt → {master: {"inputs": [...], "outputs": [(name, func)], "seq": {}}}
# ============================================================
def parse_lib(path: str) -> dict:
    out: dict = {}
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()
    i = 0
    cur: str | None = None
    while i < len(lines):
        ln = lines[i]
        m = re.match(r"^=== (.+) ===$", ln)
        if m:
            cur = m.group(1)
            out[cur] = {"inputs": [], "outputs": [], "seq": {}, "not_found": False}
            i += 1
            continue
        if cur == "NOT_FOUND":
            # not actually a key; next cell will overwrite
            i += 1; continue
        if ln.strip() == "NOT_FOUND":
            out[cur]["not_found"] = True
            i += 1; continue
        mp = re.match(r"\s*SEQ:\s*(\{.*\})", ln)
        if mp:
            import ast
            try: out[cur]["seq"] = ast.literal_eval(mp.group(1))
            except: pass
            i += 1; continue
        mp = re.match(r"\s*PIN\s+(\w+):\s+(input|output|\?)(?:\s+FUNC=\"([^\"]*)\")?", ln)
        if mp and cur is not None:
            name, d, func = mp.group(1), mp.group(2), mp.group(3) or ""
            if name in ("VGND", "VPWR", "VNB", "VPB"):
                i += 1; continue  # skip rails
            if d == "input":
                out[cur]["inputs"].append(name)
            elif d == "output":
                out[cur]["outputs"].append((name, func))
            # "?" direction = skip power pads
        i += 1
    return out

# ============================================================
# 2. Expression converters (Verilog / .lib to Python)
# ============================================================
def sanitize_identifier_expr(expr: str, inp_order: list[str]) -> str:
    """Wrap input names X → _X_? Not needed here; we substitute via dict later.
    For safety ensure inputs as whole-word matches.
    """
    return expr  # leave as is; we'll replace token-by-token before eval

def verilog_body_to_python_expr(body: str, inputs: list[str], out: str) -> str | None:
    """Convert a simple `assign X = ...;` or `assign X = (S===1'b1)?...:...;`
    Verilog line into a Python expression over input names. Returns None if the
    body cannot be represented as pure combinational Python (e.g. sequential).
    """
    # Normalize whitespace
    body = body.strip()
    # Case 1: assign OUT = expr;
    m = re.match(r'assign\s+([A-Za-z_][\w]*)\s*=\s*(.+)\s*;\s*$', body)
    if m:
        expr = m.group(2).strip()
    else:
        return None  # sequential (always @...) → skip
    # Replace Verilog literal bits with Python ints
    expr = re.sub(r"1'b0", "0", expr)
    expr = re.sub(r"1'b1", "1", expr)
    expr = re.sub(r"1'bx", "0", expr)
    expr = re.sub(r"1'bz", "0", expr)
    # ===1'b0 / ===1'b1 equality (now === 0 / === 1)
    expr = re.sub(r'\(\s*(\w+)\s*===\s*1\s*\)', r'(\1)', expr)
    expr = re.sub(r'\(\s*(\w+)\s*===\s*0\s*\)', r'(1-\1)', expr)
    # Handle ~(parens) BEFORE ternary so '~(S ? A1 : A0)' becomes
    # '(1-(S ? A1 : A0))' first, preserving the inner ternary intact.
    for _ in range(8):
        new = apply_inv_parens(expr, '~')
        if new == expr: break
        expr = new
    # ~X for single identifiers
    expr = re.sub(r'~\s*([A-Za-z_]\w*)', r'(1 - \1)', expr)
    # Handle ternary COND ? THEN : ELSE → (THEN if (COND) else ELSE)
    # Process rightmost '?' first. Find cond start by scanning backwards
    # (skip balanced parens, stop at unmatched '(' or top-level operator).
    # Find else end by scanning forwards from ':' (stop at unmatched ')' or
    # top-level operator).
    while '?' in expr:
        q = expr.rfind('?')
        # Find ':' matching this '?' (forward scan at depth 0 from q+1)
        depth = 0
        c = q + 1
        while c < len(expr):
            if expr[c] == '(': depth += 1
            elif expr[c] == ')': depth -= 1
            elif expr[c] == ':' and depth == 0:
                break
            c += 1
        if c >= len(expr):
            return None  # unmatched '?'
        # Find cond start (backward scan from q-1)
        depth = 0
        start = q - 1
        while start >= 0:
            ch = expr[start]
            if ch == ')': depth += 1
            elif ch == '(':
                if depth == 0:
                    break  # unmatched '(' → cond starts at start+1
                depth -= 1
            elif depth == 0 and ch in '&|^+-?:':
                break
            start -= 1
        cond = expr[start+1:q].strip()
        # Find else end (forward scan from c+1)
        depth = 0
        end = c + 1
        while end < len(expr):
            ch = expr[end]
            if ch == '(': depth += 1
            elif ch == ')':
                if depth == 0:
                    break  # unmatched ')' → else ends at end
                depth -= 1
            elif depth == 0 and ch in '&|^+-?:':
                break
            end += 1
        then_part = expr[q+1:c].strip()
        else_part = expr[c+1:end].strip()
        expr = expr[:start+1] + f"({then_part} if ({cond}) else {else_part})" + expr[end:]
    return expr

def libfunc_to_python(func: str) -> str:
    """Convert .lib FUNC string `(!A1&!B1&C1) | ...` to Python bitwise.
    `!identifier` handled here; `!(parens-expr)` handled later by
    apply_inv_parens in eval_expr (inv_char='!')."""
    if not func:
        return None
    expr = re.sub(r'!\s*([A-Za-z_]\w*)', r'(1 - \1)', func)
    return expr

# ============================================================
# 3. Evaluate with token substitution: substitute each input name
#    with the concrete bit value via regex word boundary replace,
#    then eval the expression (all ops are bitwise on 0/1 ints).
# ============================================================
def apply_inv_parens(s: str, inv_char: str) -> str:
    """Replace all occurrences of `<inv_char>(EXPR)` where EXPR is a fully
    paren-matched substring (possibly nested) with `(1-(EXPR))`. inv_char is
    '~' for Verilog or '!' for .lib FUNC. Operates after identifier
    substitution so `<inv_char>identifier` patterns have already been handled."""
    out = []
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c == inv_char and i + 1 < n and s[i+1] == '(':
            depth = 1
            j = i + 2
            while j < n and depth > 0:
                if s[j] == '(': depth += 1
                elif s[j] == ')': depth -= 1
                j += 1
            inner = s[i+1:j]  # includes the outer ()
            out.append('(1-' + inner + ')')
            i = j
            continue
        out.append(c)
        i += 1
    return "".join(out)

def apply_not_parens(s: str) -> str:
    """Backward-compat wrapper for Verilog `~(...)`."""
    return apply_inv_parens(s, '~')

def eval_expr(expr: str, inputs_ordered: list[str], values: tuple) -> int:
    e = expr
    # Step 1: replace each whole-word input with int value
    for name, v in zip(inputs_ordered, values):
        e = re.sub(rf'\b{re.escape(name)}\b', str(v), e)
    # Step 2: handle ~(parens) for Verilog and !(parens) for .lib FUNC.
    # Apply repeatedly until stable (handles nested inversions).
    for _ in range(8):
        new = apply_inv_parens(e, '~')
        new = apply_inv_parens(new, '!')
        if new == e:
            break
        e = new
    # Step 3: remove stray `1'b0 / 1'b1 / === equality forms should be gone already
    #   (as safety net)
    e = re.sub(r"1'b[01xz]", "0", e)
    e = re.sub(r'\s*===\s*1\'b0', "==0", e)
    e = re.sub(r'\s*===\s*1\'b1', "==1", e)
    e = re.sub(r'\(\s*(\d)\s*==\s*(\d)\s*\)', lambda m: "1" if m.group(1)==m.group(2) else "0", e)
    try:
        r = eval(e, {"__builtins__": {}}, {})
    except Exception as ex:
        raise RuntimeError(f"eval fail: expr={e!r} orig={expr!r} err={ex}") from None
    # Normalize boolean to int
    if isinstance(r, bool):
        r = 1 if r else 0
    else:
        r = int(r) & 1
    return r

# ============================================================
# 4. Verify per cell
# ============================================================
def main():
    lib = parse_lib(LIB_PATH)
    tot = ok = mismatch = skipped = no_golden = pins_mismatch = 0
    detail_mismatch = []
    for master, (my_out, my_ins, my_body) in sorted(MY_CELLS.items()):
        tot += 1
        if master not in lib or lib[master].get("not_found"):
            no_golden += 1
            print(f"  [NO GOLDEN] {master} (skip)")
            continue
        g = lib[master]
        g_ins = sorted(g["inputs"])
        g_outs = g["outputs"]  # list[(name,func)]

        # Seq cell: skip combinational-only flow
        if g.get("seq"):
            print(f"  [SEQ CELL] {master} (not combinational, skip)")
            skipped += 1
            continue

        # Must have exactly one golden output with a func
        if not g_outs or not g_outs[0][1]:
            print(f"  [NO FUNC] {master} (skip; outputs info: {g_outs})")
            skipped += 1
            continue
        (g_out, g_func_str) = g_outs[0]

        # Check pin lists (same set)
        my_ins_set = set(my_ins); my_n = len(my_ins_set)
        g_ins_set = set(g_ins);   g_n = len(g_ins_set)
        if my_ins_set != g_ins_set or my_out != g_out:
            pins_mismatch += 1
            only_my = sorted(my_ins_set - g_ins_set)
            only_g  = sorted(g_ins_set - my_ins_set)
            print(f"  [PINS DIFF] {master}  my_out={my_out} vs golden_out={g_out}")
            if only_my: print(f"     inputs only in MY:  {only_my}")
            if only_g:  print(f"     inputs only in LIB: {only_g}")
            continue

        if my_n > 7:
            print(f"  [TOO MANY INPUTS] {master} (n={my_n}, skip)")
            skipped += 1
            continue

        # Build expressions
        my_expr = verilog_body_to_python_expr(my_body, my_ins, my_out)
        g_expr  = libfunc_to_python(g_func_str)
        if my_expr is None or g_expr is None:
            print(f"  [EXPR PARSE FAIL] {master}  my_expr={my_expr!r} g_expr={g_expr!r}")
            skipped += 1
            continue

        # Fixed input order for iteration
        ins_sorted = sorted(my_ins)
        fail_case = None
        for bits in itertools.product([0, 1], repeat=my_n):
            v_my = eval_expr(my_expr, ins_sorted, bits)
            v_g  = eval_expr(g_expr,  ins_sorted, bits)
            if v_my != v_g:
                fail_case = (bits, v_my, v_g)
                break
        if fail_case:
            mismatch += 1
            bits, vm, vg = fail_case
            detail_mismatch.append((master, ins_sorted, bits, vm, vg, my_expr, g_expr))
            print(f"  [MISMATCH] {master}")
            print(f"    inps:   {ins_sorted}")
            print(f"    failed: {bits}  my={vm}  golden={vg}")
            print(f"    my verilog body:   {my_body!r}")
            print(f"    my python expr:    {my_expr}")
            print(f"    lib func:          {g_func_str!r}")
            print(f"    lib python expr:   {g_expr}")
        else:
            ok += 1

    print()
    print("=" * 60)
    print(f"TOTAL cells           : {tot}")
    print(f"  TRUTH-TABLE MATCH   : {ok}")
    print(f"  TRUTH-TABLE MISMATCH: {mismatch}")
    print(f"  PIN-LIST MISMATCH   : {pins_mismatch}")
    print(f"  NO GOLDEN IN LIB    : {no_golden}")
    print(f"  SKIPPED (seq/no func/>7in): {skipped}")
    if detail_mismatch:
        print()
        print("!!! BUGGY CELLS NEED FIX (write correct blackbox body):")
        for m, ins, b, vm, vg, me, ge in detail_mismatch:
            print(f"  - {m}: fix body (example: inputs {dict(zip(ins,b))} → got {vm}, exp {vg})")
    return 0 if mismatch == 0 and pins_mismatch == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
