/*!
* @file wvar.v
* @brief SHA-256 Compression Working Variable Register (A..H)
* @author LDFranck-style (recovered from compression.v port map)
* @date 2026
* @details
*  Each instance holds one SHA-256 working variable (a,b,c,d,e,f,g,h).
*  - Reset (rst high) or start-of-conversion (soc high):
*      reload the 32-bit initial hash constant (parameter IV)
*  - Normal operation (soc=0, rst=0, eoc=0):
*      register updates every cycle: q <= d (rotating / next-state value)
*  - End-of-conversion (eoc high):
*      register holds final working value; hash_out = IV + q
*      (SHA-256 standard final addition: H[i]' = H[i] + working_var[i])
*
*  Port order matches compression.v instantiation:
*      wvar uA(Ha, A, addA, IV_H0, clk, rst, soc, eoc);
*/

module wvar(hash_out, q, d, IV, clk, rst, soc, eoc);

	input  [31:0] d;
	input  [31:0] IV;       // SHA-256 initial hash constant (H0..H7)
	input         clk;
	input         rst;      // active-high synchronous reset (load IV)
	input         soc;      // start of conversion (1 clk pulse → reload IV)
	input         eoc;      // end of conversion → q holds, hash_out = IV + q

	output [31:0] hash_out; // final hash word (valid when eoc == 1)
	output [31:0] q;        // current working variable (fed into comb logic / next stage)

	reg [31:0] q;

	// === 32-bit synchronous register ===
	//   rst high  → load IV (global reset)
	//   soc high  → load IV (new message block start: reload initial hash)
	//   eoc low   → normal update: q <= d
	//   eoc high  → hold (compression done)
	// NOTE: use active-high rst (not rst_n) to avoid Yosys reset-pattern
	//       misoptimization that drops IV=1 constant bits.
	always @(posedge clk) begin
		if (rst)
			q <= IV;
		else if (soc)
			q <= IV;
		else if (!eoc)
			q <= d;
		// else eoc == 1: hold final value
	end

	// === SHA-256 final step: H[i] += working_var[i] ===
	//   hash_out = IV (initial H[i]) + q (final working var after 64 rounds)
	add2 u_final_add(hash_out, IV, q);

endmodule
