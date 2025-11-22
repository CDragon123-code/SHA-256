/*!
* @file add3.v
* @brief Addition 32-bits Module (3 inputs)
* @author LDFranck
* @date February 2023
* @version v1
*
* @details
*  32-bit digital adder module implementation in Verilog.
*  The module returns the sum of the 3 inputs (a, b, c)
*  truncated to 32-bits size.
*/

module add3(out, a, b, c);

	input  [31:0] a, b, c;
	output [31:0] out;

	assign out = a + b + c;

endmodule