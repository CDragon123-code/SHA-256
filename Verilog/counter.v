/*!
* @file counter.v
* @brief Counter Module
* @author LDFranck
* @date February 2023
* @version v1
*
* @details
*  Counter module implementation in Verilog.
*  The module is reponsible for controlling internal
*  processes and memory access (constants ROM). It
*  works as a 7-bit synchronous up-counter. 
*/

module counter(addr, eoc, clk, soc_n, rd);

	input  clk, soc_n, rd;
	output eoc;
	output [5:0] addr;

	reg  Q0, Q1, Q2, Q3, Q4, Q5, Q6;
	wire dQ0, dQ1, dQ2, dQ3, dQ4, dQ5, dQ6;
	wire wQ0, wQ1, wQ2, wQ3, wQ4, wQ5, wQ6, eoc_n;

	always @(posedge clk) begin
		Q0 <= dQ0;
		Q1 <= dQ1;
		Q2 <= dQ2;
		Q3 <= dQ3;
		Q4 <= dQ4;
		Q5 <= dQ5;
		Q6 <= dQ6;
	end

	assign eoc_n = ~Q6;
	
	assign wQ0 = eoc_n | rd; 
	assign dQ0 = (wQ0 ^ Q0) & soc_n;

	assign wQ1 = wQ0 & Q0;
	assign dQ1 = (wQ1 ^ Q1) & soc_n;

	assign wQ2 = wQ1 & Q1;
	assign dQ2 = (wQ2 ^ Q2) & soc_n;

	assign wQ3 = wQ2 & Q2 & eoc_n;
	assign dQ3 = (wQ3 ^ Q3) & soc_n;

	assign wQ4 = wQ3 & Q3;
	assign dQ4 = (wQ4 ^ Q4) & soc_n;
	
	assign wQ5 = wQ4 & Q4;
	assign dQ5 = (wQ5 ^ Q5) & soc_n;

	assign wQ6 = wQ5 & Q5;
	assign dQ6 = (wQ6 ^ Q6) & soc_n;

	assign eoc  = Q6;
	assign addr = {Q5, Q4, Q3, Q2, Q1, Q0};

endmodule