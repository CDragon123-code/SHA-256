/*!
* @file add4.v
* @brief Addition 32-bits Module (4 inputs)
* @author LDFranck
* @date February 2023
* @version v1
*
* @details
*  32-bit digital adder module implementation in Verilog.
*  The module returns the sum of the 4 inputs (a, b, c, d)
*  truncated to 32-bits size.
*/

module add4(out, a, b, c, d);

	input  [31:0] a, b, c, d;
	output [31:0] out;

	assign out = a + b + c + d;

endmodule