/*!
* @file usigma1.v
* @brief Uppercase Sigma 1 Module (Σ1 for SHA-256 Compression)
* @author LDFranck-style (recovered from SHA256 spec)
* @date 2026
* @details
*  SHA-256 FIPS 180-4 §4.1.2:
*    Σ1(x) = ROTR^6(x) XOR ROTR^11(x) XOR ROTR^25(x)
*/

module usigma1(out, in);

	input  [31:0] in;
	output [31:0] out;

	wire [31:0] net [2:0];

	ror #(6)  u0(net[0], in);
	ror #(11) u1(net[1], in);
	ror #(25) u2(net[2], in);

	assign out = net[0] ^ net[1] ^ net[2];

endmodule
