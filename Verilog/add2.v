/*!
* @file add2.v
* @brief Addition 32-bits Module (2 inputs)
* @author LDFranck
* @date February 2023
* @version v1
*
* @details
*  32-bit digital adder module implementation in Verilog.
*  The module returns the sum of the 2 inputs (a, b)
*  truncated to 32-bits size.
*/

module add2(out, a, b);

	input  [31:0] a, b;
	output [31:0] out;

	assign out = a + b;

endmodule