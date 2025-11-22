/*!
* @file SHA256.v
* @brief SHA256 Top-Level Module
* @author LDFranck
* @date February 2023
* @version v1
*
* @details
*  SHA256 top-level module implementation in Verilog.
*  The module connects all sub-modules and external logic
*  for signal handling. The module has 36 IO pins, which are:
*
*  - 'data' => 32x bidirectional bus to input the original
*  message and read the final hash once ready;
*
*  - 'eoc' => 1x output 'end of calculation' signal;
*
*  - 'clk' => 1x input clock signal;
*
*  - 'rst' => 1x input master reset signal. It resets all working
*  variables and must stay HIGH for 1 'clk' posedge at the start
*  of each new message;
*
*  - 'soc' => 1x input 'start of calculation' signal. It starts the
*  hashing of a new message block and must stay HIGH for 1 'clk' posedge
*  to start the hashing of a new message or continue the hashing of a
*  multi-block message. IT MUST BE ACTIVATED AFTER THE RST FOR A NEW MSG;
*
*  - 'rd' => 1x input read signal. It changes the data direction of the
*  'data' bus and enables the hash output. This signal must stay HIGH during
*  all read sequence, otherwise the bus will be set to HighZ mode. Read
*  function can only be activated once EOC is set HIGH.
*
*  INITIALIZATION SEQUENCE:
*  	  block0:			 block1:	 read:
*  clk:  __--__--__--__--__--__--__--_| |__--__--__--_| |__--__--__--__
*  rst:  _--__________________________| |_____________| |______________
*  soc:  _____--______________________| |_--__________| |______________
*  rd:   _____________________________| |_____________| |_____---------
*  data: .........a0..b0..c0..d0..e0..| |.....a1..b1..| |......H0..H1..
*  eoc:  _____________________________| |--___________| |__------------
*/

`include "ror.v"
`include "shr.v"
`include "add2.v"
`include "add3.v"
`include "add4.v"
`include "add5.v"
`include "choice.v"
`include "majority.v"

`include "usigma0.v"
`include "usigma1.v"
`include "lsigma0.v"
`include "lsigma1.v"
`include "wvar.v"

`include "counter.v"
`include "constants.v"
`include "expansion.v"
`include "compression.v"

module SHA256(data, eoc, clk, rst, soc, rd);

	input  clk, rst, soc, rd;
	inout  [31:0] data;
	output eoc;

	// Internal control signals:
	wire rst_n, soc_n;
	wire ieoc, ird;
	
	assign rst_n = ~rst;
	assign soc_n = ~soc;
	assign ird = rd & ieoc;

	// Bidirectional bus:
	wire [31:0] idata, odata;
	assign idata = data;
	assign data  = (ird)  ? odata : 32'bz;

	// Counter sub-module:
	wire sel;
	wire [5:0] addr;
	counter u0(addr, ieoc, clk, soc_n, ird);
	assign sel = ieoc | addr[5] | addr[4];
	assign eoc = ieoc;

	// ROM sub-module:
	wire [31:0] k;
	constants u1(k, addr);

	// Expansion sub-module:
	wire [31:0] msg;
	expansion u2(msg, idata, clk, sel);

	// Compression sub-module:
	wire [255:0] hash;
	compression u3(hash, msg, k, clk, rst_n, soc, ieoc);

	// Output MUX:
	wire [2:0]  abc;
	reg  [31:0] mux_out;
	assign abc = {addr[2], addr[1], addr[0]};
	
	always @(abc, hash) begin
		case(abc)
			0 : mux_out = hash[255:224];
			1 : mux_out = hash[223:192];
			2 : mux_out = hash[191:160];
			3 : mux_out = hash[159:128];
			4 : mux_out = hash[127:96];
			5 : mux_out = hash[95:64];
			6 : mux_out = hash[63:32];
			7 : mux_out = hash[31:0];
		endcase
	end

	assign odata = mux_out;

endmodule
