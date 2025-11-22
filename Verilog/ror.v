/*!
* @file ror.v
* @brief ROR 32-bits Module
* @author LDFranck
* @date February 2023
* @version v1
*
* @details
*  32-bit Rotate Right Logical (ROR) module implementation in Verilog.
*  The module rotates 'in' signal by 'N' positions to the right, with 'N'
*  a parameter that must be override during instantiation.
*/

module ror(out, in);

	parameter N = 1;
	
	input  [31:0] in;
	output [31:0] out;

	assign out = {in[N-1:0], in[31:N]};

endmodule