/*!
* @file add5.v
* @brief Addition 32-bits Module (5 inputs)
* @author LDFranck
* @date February 2023
* @version v1
*
* @details
*  32-bit digital adder module implementation in Verilog.
*  The module returns the sum of the 5 inputs (a, b, c, d, e)
*  truncated to 32-bits size.
*/

module add5(out, a, b, c, d, e);

	input  [31:0] a, b, c, d, e;
	output [31:0] out;

	assign out = a + b + c + d + e;

endmodule