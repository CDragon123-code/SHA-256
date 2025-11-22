/*!
* @file SHA256_testbench.v
* @brief SHA256 TestBench
* @author LDFranck
* @date February 2023
* @version v1
*
* @details
*  SHA256 testbench implementation in Verilog.
*  The test routine utilizes an external file 'tb_data.txt'
*  as input and verification data to the SHA256 hash function.
*  The file must be formatted as the provided example. 
*  The binary padded message block and the final hexadecimal
*  hash can be obtained from: https://sha256algorithm.com/
*/

`define NULL 0
`timescale 1ns / 1ps	//!< <time unit> / <time precision>

`include "SHA256.v"

module SHA256_testbench();

	// DUT:
	wire [31:0] wdata;
	wire weoc, wclk, wrst, wsoc, wrd;
	SHA256 dut(wdata, weoc, wclk, wrst, wsoc, wrd);

	// TestBench:
	integer file;
	integer msg_blocks, i;

	reg [31:0] rdata, hash;
	reg rclk, rrst, rsoc, rrd;

	assign wdata = rdata;
	assign wclk = rclk;
	assign wrst = rrst;
	assign wsoc = rsoc;
	assign wrd = rrd;

	initial begin
		$display("TestBench Running...");

		file = $fopen("tb_data.txt", "r");
		
		if(file == `NULL) begin
    		$display("OPEN FILE ERROR");
    		$finish;
  		end

		if($fscanf(file, "msg_blocks=%d\n", msg_blocks) == -1) begin
			$display("READ FILE ERROR");
			$finish;
		end

		rclk = 1'b0;
		rrst = 1'b0; 
		rsoc = 1'b0;
		rrd  = 1'b0;

		#25 rrst = 1'b1;
		#50 rrst = 1'b0;

		for(i = 0; i < msg_blocks; i = i + 1) begin
			#50 rsoc = 1'b1;
			#50 rsoc = 1'b0;
			
			#50;
			if($fscanf(file, "%b\n", rdata) == -1) begin
				$display("READ FILE ERROR");
				$finish;
			end
			repeat(15) #100 
				if($fscanf(file, "%b\n", rdata) == -1) begin
					$display("READ FILE ERROR");
					$finish;
				end
			#100 rdata = 32'bz;
			repeat(48) #100;
			#50;
		end

		#25 rrd = 1'b1;
		for(i = 0; i < 8; i = i + 1) begin
			if($fscanf(file, "%h\n", hash) == -1) begin
				$display("READ FILE ERROR");
				$finish;
			end
			if(hash != wdata) begin
				$display("HASH ERROR");
				$finish;
			end
			#100;
		end

		$display("MSG SUCCESSFULLY HASHED");

		$fclose(file);
		$finish;
	end

	always #50 rclk = ~rclk;

endmodule
