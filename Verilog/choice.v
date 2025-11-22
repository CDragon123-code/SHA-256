/*!
* @file choice.v
* @brief Bitwise Choice Module
* @author LDFranck
* @date February 2023
* @version v1
*
* @details
*  Bitwise choice module implementation in Verilog.
*  The module returns the bitwise evaluation of the
*  logical expression 'IF (a == 1) THEN b ELSE c'.
*/

module choice(out, a, b, c);

	input  [31:0] a, b, c;
	output [31:0] out;

	assign out = (a & b) | (~a & c);

endmodule