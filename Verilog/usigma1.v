/*!
* @file usigma1.v
* @brief Uppercase Sigma 1 Module
* @author LDFranck
* @date February 2023
* @version v1
*
* @details
*  Uppercase Sigma 1 module implementation in Verilog.
*  The module returns the result of 'SIGMA1' function applied 
*  to the input signal 'in'.
*/

module usigma1(out, in);

	input  [31:0] in;
	output [31:0] out;

	wire [31:0] net [2:0];	//!< 3x 32-bits words

	ror #(6)  u0(net[0], in);
	ror #(11) u1(net[1], in);
	ror #(25) u2(net[2], in);

	assign out = net[0] ^ net[1] ^ net[2];

endmodule
