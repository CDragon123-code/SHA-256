/*!
* @file usigma0.v
* @brief Uppercase Sigma 0 Module (Σ0 for SHA-256 Compression)
* @author LDFranck-style (recovered from SHA256 spec)
* @date 2026
* @details
*  SHA-256 FIPS 180-4 §4.1.2:
*    Σ0(x) = ROTR^2(x) XOR ROTR^13(x) XOR ROTR^22(x)
*/

module usigma0(out, in);

	input  [31:0] in;
	output [31:0] out;

	wire [31:0] net [2:0];

	ror #(2)  u0(net[0], in);
	ror #(13) u1(net[1], in);
	ror #(22) u2(net[2], in);

	assign out = net[0] ^ net[1] ^ net[2];

endmodule
