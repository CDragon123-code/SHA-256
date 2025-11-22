/*!
* @file majority.v
* @brief Majority Function Module
* @author LDFranck
* @date February 2023
* @version v1
*
* @details
*  Majority function module implementation in Verilog.
*  The module evaluates the input signals 'a', 'b' and 'c'
*  and returns the most frequent bit for each position.
*/

module majority(out, a, b, c);

	input  [31:0] a, b, c;
	output [31:0] out;

	assign out = (a & b) | (a & c) | (b & c);

endmodule