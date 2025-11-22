/*!
* @file expansion.v
* @brief SHA256 Message Expansion Module
* @author LDFranck
* @date February 2023
* @version v1
*
* @details
*  SHA256 message expansion module implementation in Verilog.
*  The module outputs the correct message slice from 'W0' to 'W63'
*  necessary for the message digest part. External logic is needed
*  to control selection 'sel' between orignal message 'in' (sel = 0)
*  or internal expansion (sel = 1).
*/

module expansion(out, in, clk, sel);

	input  clk, sel;
	input  [31:0] in;
	output [31:0] out;

	reg  [31:0] mem [0:15];
	wire [31:0] a00, a01, a09, a14;
	wire [31:0] mux_out, add_out, lsigma0_out, lsigma1_out;

	always @(posedge clk) begin
		mem[0]  <=  mem[1]; 
		mem[1]  <=  mem[2]; 
		mem[2]  <=  mem[3];
		mem[3]  <=  mem[4];
		mem[4]  <=  mem[5];
		mem[5]  <=  mem[6];
		mem[6]  <=  mem[7];
		mem[7]  <=  mem[8];
		mem[8]  <=  mem[9];
		mem[9]  <=  mem[10];
		mem[10] <=  mem[11];
		mem[11] <=  mem[12];
		mem[12] <=  mem[13];
		mem[13] <=  mem[14];
		mem[14] <=  mem[15];
		mem[15] <=  mux_out;
	end

	assign a00 = mem[0];
	assign a01 = mem[1];
	assign a09 = mem[9];
	assign a14 = mem[14];

	lsigma0 u0(lsigma0_out, a01);
	lsigma1 u1(lsigma1_out, a14);
	add4	u2(add_out, a00, lsigma0_out, a09, lsigma1_out);

	assign mux_out = (sel) ? add_out : in;
	assign out = mux_out;

endmodule
