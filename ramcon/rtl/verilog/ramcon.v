`timescale 1ns / 1ps

`define BCR_ADDR	(23'b000_10_00_0_0_011_1_0_0_00_01_0_001)
//				 ||    | | ||| |   |    || | |||
//                  Address BCR -+'    | | ||| |   |    || | |||
//                  Synchronous -------' | ||| |   |    || | |||
//             Variable latency ---------' ||| |   |    || | |||
//   Latency Counter (4 cycles) -----------''' |   |    || | |||
//    ram_wait_i is active-high ---------------'   |    || | |||
// ram_wait_i asserted during delay ---------------'    || | |||
// Default Drive Strength (1/2) ------------------------'' | |||
// Burst wraps within burst length ------------------------' |||
//      Burst length is 4 words -----------------------------'''

module ramcon(
	input		reset_i,
	input		clk2x_i,

	output	[22:0]	ram_adr_o,
	inout	[15:0]	ram_dq_io,
	output		ram_ce_on,
	output		ram_adv_on,
	output		ram_oe_on,
	output		ram_we_on,
	output		ram_ub_on,
	output		ram_lb_on,
	output		ram_cre_o,
	output		ram_clk_o,
	input		ram_wait_i,

	output		wb_ack_o,
	output	[15:0]	wb_dat_o,
	input	[15:0]	wb_dat_i,
	input	[23:1]	wb_adr_i,
	input	[1:0]	wb_sel_i,
	input		wb_stb_i,
	input		wb_cyc_i,
	input		wb_we_i,

	output		reset_o
);
	wire		ram_en_q;

	wire		ram_adv_o, ram_ce_o, ram_oe_o, ram_we_o, ram_be_valid;
	wire		dato_dq, dq_dati;
	wire		nt0, nt1, nt2, nt3, nt4, nt5;

	reg		t0, t1, t2, t3, t4, t5;
	reg		cfg;
	wire		cfg_o, adr_bcrcfg, clk_en;

	// PSRAM power-on timing.  Do not let the dogs out until
	// the PSRAM chip has gone through its boot-up sequence.
	// Wait 150us minimum, and to be conservative, a little
	// extra.  I've arbitrarily selected 32ms, assuming 50MHz
	// input on clk2x_i.

	reg [14:0] resetCounter;

	always @(posedge clk2x_i) begin
		if(reset_i) begin
			resetCounter <= 0;
		end
		else begin
			if(resetCounter[14]) begin
				resetCounter <= resetCounter;
			end
			else begin
				resetCounter <= resetCounter + 1;
			end
		end
	end
	wire reset_sans_cfg = ~resetCounter[14];
	assign reset_o = reset_sans_cfg | cfg;

	// Bus bridge random logic.

	reg [15:0] wb_dat_or;
	assign ram_adr_o = adr_bcrcfg ? `BCR_ADDR : wb_adr_i;

	assign wb_dat_o = wb_dat_or;
	always @(negedge clk2x_i) begin
		if(dato_dq) wb_dat_or <= ram_dq_io;
	end

	assign ram_dq_io = dq_dati ? wb_dat_i : 16'hzzzz;

	assign ram_clk_o = ~clk2x_i & clk_en;

	// Bus bridge state Machine.

	kseq ks(
		.t5(t5),
		.t4(t4),
		.t3(t3),
		.t2(t2),
		.t1(t1),
		.wb_we_i(wb_we_i),
		.t0(t0),
		.wb_cyc_i(wb_cyc_i),
		.wb_stb_i(wb_stb_i),
		.reset_i(reset_sans_cfg),
		.wb_ack_o(wb_ack_o),
		.dato_dq(dato_dq),
		.dq_dati(dq_dati),
		.ram_oe_o(ram_oe_o),
		.ram_we_o(ram_we_o),
		.ram_ce_o(ram_ce_o),
		.ram_adv_o(ram_adv_o),
		.ram_be_valid(ram_be_valid),
		.nt5(nt5),
		.nt4(nt4),
		.nt3(nt3),
		.nt2(nt2),
		.nt1(nt1),
		.nt0(nt0),
		.adr_bcrcfg(adr_bcrcfg),
		.ram_cre_o(ram_cre_o),
		.cfg_o(cfg_o),
		.cfg(cfg),
		.clk_en(clk_en),
		.ram_wait_i(ram_wait_i)
	);

	assign ram_adv_on = reset_sans_cfg | ~ram_adv_o;
	assign ram_ce_on = reset_sans_cfg | ~ram_ce_o;
	assign ram_oe_on = reset_sans_cfg | ~ram_oe_o;
	assign ram_we_on = reset_sans_cfg | ~ram_we_o;
	assign ram_ub_on = reset_sans_cfg | ~(ram_be_valid & wb_sel_i[1]);
	assign ram_lb_on = reset_sans_cfg | ~(ram_be_valid & wb_sel_i[0]);

	always @(posedge clk2x_i) begin
		t0 <= nt0;
		t1 <= nt1;
		t2 <= nt2;
		t3 <= nt3;
		t4 <= nt4;
		t5 <= nt5;
		cfg <= cfg_o;
	end
endmodule

