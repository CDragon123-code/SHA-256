// SPDX-License-Identifier: Apache-2.0
//
// user_project_wrapper — Caravel MPW integration for SHA-256 accelerator
//
// Instantiates SHA256 core with split bus interface (data_in/data_out/data_oe)
// and adapts it to the Caravel Wishbone slave interface.
//
// Wishbone protocol mapping:
//   Write  (we=1): dat_i → data_in, assert soc for 1 cycle, ack immediately
//   Read   (we=0): assert rd, dat_o ← data_out (when data_oe=1), ack on eoc
//   Address: addr[0] = control/status register (0=write msg, 1=read hash/status)
//
// Register map:
//   addr 0x0 (W): message word input → data_in[31:0], pulse soc
//   addr 0x0 (R): status → {eoc, data_oe, 30'b0}
//   addr 0x4 (R): hash word output → data_out[31:0] (valid when data_oe=1)

`default_nettype none

module user_project_wrapper (
    // Caravel Wishbone slave interface
    input  wire        wb_clk_i,
    input  wire        wb_rst_i,
    input  wire        wbs_stb_i,
    input  wire        wbs_cyc_i,
    input  wire        wbs_we_i,
    input  wire [3:0]  wbs_sel_i,
    input  wire [31:0] wbs_dat_i,
    input  wire [31:0] wbs_adr_i,
    output wire        wbs_ack_o,
    output wire [31:0] wbs_dat_o,

    // Caravel management bus (pass-through, not used by SHA256)
    input  wire [127:0] la_data_in,
    output wire [127:0] la_data_out,
    input  wire         la_oenb,
    input  wire         la_iena,
    output wire [2:0]   irq,

    // Caravel GPIO (pass-through, not used by SHA256)
    inout  wire [37:0]  io,

    // Caravel clock control
    output wire         user_clock2,

    // Caravel area fill (analog pins, not used)
    output wire [2:0]   user_irq
);

    // ============================================================
    // SHA256 core instantiation (split bus interface — 方案 B)
    // ============================================================

    wire [31:0] sha_data_in;
    wire [31:0] sha_data_out;
    wire        sha_data_oe;
    wire        sha_eoc;
    wire        sha_soc;
    wire        sha_rd;

    // Use Caravel user_clock2 as SHA256 clock (or just pass wb_clk)
    wire sha_clk = wb_clk_i;
    wire sha_rst = wb_rst_i;

    SHA256 sha256_core (
        .clk      (sha_clk),
        .rst      (sha_rst),
        .soc      (sha_soc),
        .rd       (sha_rd),
        .eoc      (sha_eoc),
        .data_in  (sha_data_in),
        .data_out (sha_data_out),
        .data_oe  (sha_data_oe)
    );

    // ============================================================
    // Wishbone adapter
    // ============================================================

    // Simple register-map Wishbone adapter
    //   addr[2:0] selects register:
    //     0x0: message/control (W: data_in + soc pulse, R: status {eoc, oe})
    //     0x4: hash output (R: data_out)
    //
    // ack is returned 1 cycle after access for simplicity (classic mode)

    reg         wb_ack_reg;
    reg  [31:0] wb_dat_o_reg;
    reg         soc_pulse;
    reg         rd_pulse;

    // Combinational data_in routing
    assign sha_data_in = wbs_dat_i;

    // soc pulse on write to addr 0x0
    assign sha_soc = soc_pulse;
    // rd pulse on read from addr 0x4
    assign sha_rd  = rd_pulse;

    // Acknowledge
    assign wbs_ack_o = wb_ack_reg;
    assign wbs_dat_o = wb_dat_o_reg;

    // Wishbone state machine
    wire wb_access = wbs_cyc_i & wbs_stb_i;
    wire is_hash_read = wb_access & ~wbs_we_i & (wbs_adr_i[2] == 1'b1);
    wire is_status    = wb_access & ~wbs_we_i & (wbs_adr_i[2] == 1'b0);
    wire is_msg_write = wb_access &  wbs_we_i & (wbs_adr_i[2] == 1'b0);

    always @(posedge sha_clk or posedge sha_rst) begin
        if (sha_rst) begin
            wb_ack_reg  <= 1'b0;
            wb_dat_o_reg <= 32'b0;
            soc_pulse   <= 1'b0;
            rd_pulse    <= 1'b0;
        end else begin
            // Clear pulses by default
            soc_pulse <= 1'b0;
            rd_pulse  <= 1'b0;

            if (wb_access & ~wb_ack_reg) begin
                wb_ack_reg <= 1'b1;
                if (is_msg_write) begin
                    // Write message word → pulse soc
                    soc_pulse <= 1'b1;
                    wb_dat_o_reg <= 32'b0;
                end else if (is_hash_read) begin
                    // Read hash word → pulse rd, return data_out
                    rd_pulse <= 1'b1;
                    wb_dat_o_reg <= sha_data_out;
                end else if (is_status) begin
                    // Read status: {eoc, data_oe, 30'b0}
                    wb_dat_o_reg <= {sha_eoc, sha_data_oe, 30'b0};
                end else begin
                    wb_dat_o_reg <= 32'b0;
                end
            end else begin
                wb_ack_reg <= 1'b0;
            end
        end
    end

    // ============================================================
    // Unused Caravel outputs (tie-off)
    // ============================================================

    assign user_clock2 = 1'b0;
    assign user_irq    = 3'b0;
    assign irq         = 3'b0;
    assign la_data_out = 128'b0;

endmodule

`default_nettype wire
