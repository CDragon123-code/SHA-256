/*!
* @file compression.v
* @brief SHA256 Message Compression Module
* @author LDFranck
* @date February 2023
* @version v1
*
* @details
*  SHA256 message compression module implementation in Verilog.
*  The module outputs the compression function working variables
*  in a 256-bits bus 'hash'. The message slices generated through
*  the message expansion module must be fed into 'msg'. Compression
*  constants K must be stored in an auxiliary module and be available
*  at 'k' input as needed. External control logic is necessary.
*/

module compression(hash, msg, k, clk, rst_n, soc, eoc);

	input  clk, rst_n, soc, eoc;
	input  [31:0]  msg, k;
	output [255:0] hash;

	wire [31:0] A, B, C, D, E, F, G, H;
	wire [31:0] Ha, Hb, Hc, Hd, He, Hf, Hg, Hh;
	
	wire [31:0] addMsg, addE, addA;
	wire [31:0] us0, us1, maj, ch;

	wvar 	 uA(Ha, A, addA, 32'h6a09e667, clk, rst_n, soc, eoc);
	wvar 	 uB(Hb, B,    A, 32'hbb67ae85, clk, rst_n, soc, eoc);
	wvar 	 uC(Hc, C,    B, 32'h3c6ef372, clk, rst_n, soc, eoc);
	wvar 	 uD(Hd, D,    C, 32'ha54ff53a, clk, rst_n, soc, eoc);
	wvar 	 uE(He, E, addE, 32'h510e527f, clk, rst_n, soc, eoc);
	wvar 	 uF(Hf, F,    E, 32'h9b05688c, clk, rst_n, soc, eoc);
	wvar 	 uG(Hg, G,    F, 32'h1f83d9ab, clk, rst_n, soc, eoc);
	wvar 	 uH(Hh, H,    G, 32'h5be0cd19, clk, rst_n, soc, eoc);

	usigma1  u0(us1, E);
	choice	 u1(ch, E, F, G);
	add5	 u2(addMsg, msg, k, us1, ch, H);

	add2	 u3(addE, addMsg, D);

	usigma0	 u4(us0, A);
	majority u5(maj, A, B, C);
	add3	 u6(addA, us0, maj, addMsg);	

	assign hash = {Ha, Hb, Hc, Hd, He, Hf, Hg, Hh};

endmodule
