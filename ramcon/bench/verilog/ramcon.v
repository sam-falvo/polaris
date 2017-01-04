`timescale 1ns / 1ps

module test_ramcon();
	reg [15:0] story;
	reg clk2x_i, reset_i;
	wire reset_o;
	wire ram_ce_on;
	wire ram_lb_on, ram_ub_on;
	wire ram_oe_on, ram_we_on;
	wire ram_adv_on;
	wire [15:0] ram_dq_io;
	wire [22:0] ram_adr_o;
	
	wire [15:0] wb_dat_o;
	reg [15:0] wb_dat_i;
	wire wb_ack_o;
	reg wb_we_i;
	reg [1:0] wb_sel_i;
	reg [22:0] wb_adr_i;
	reg wb_cyc_i, wb_stb_i;

	reg [15:0] ram_dq_o;
	assign ram_dq_io = (~ram_oe_on) ? ram_dq_o : 16'hzzzz;

	ramcon rc(
		.reset_o(reset_o),

		.ram_ce_on(ram_ce_on),
		.ram_lb_on(ram_lb_on),
		.ram_ub_on(ram_ub_on),
		.ram_we_on(ram_we_on),
		.ram_oe_on(ram_oe_on),
		.ram_adv_on(ram_adv_on),
		.ram_dq_io(ram_dq_io),
		.ram_adr_o(ram_adr_o),

		.wb_dat_o(wb_dat_o),
		.wb_ack_o(wb_ack_o),
		.wb_dat_i(wb_dat_i),
		.wb_adr_i(wb_adr_i),
		.wb_sel_i(wb_sel_i),
		.wb_cyc_i(wb_cyc_i),
		.wb_stb_i(wb_stb_i),
		.wb_we_i(wb_we_i),

		.clk2x_i(clk2x_i),
		.reset_i(reset_i)
	);

	always begin
		#10 clk2x_i <= ~clk2x_i;	// 50MHz clock on Nexys-2
	end
	
	task scenario;
	input [15:0] s;
	begin
		story <= s;
		#2;
	end
	endtask

	task assert_wb_ack_o;
	input expected;
	begin
		if(wb_ack_o !== expected) begin
			$display("@E %d %04X WB_ACK_O Expected %d.  Got %d.", $time, story, expected, wb_ack_o);
			$stop;
		end
	end
	endtask

	task assert_wb_dat_o;
	input [15:0] expected;
	begin
		if(wb_dat_o !== expected) begin
			$display("@E %d %04X WB_DAT_O Expected %04X.  Got %04X.", $time, story, expected, wb_dat_o);
			$stop;
		end
	end
	endtask

	task assert_ram_dq_io;
	input [15:0] expected;
	begin
		if(ram_dq_io !== expected) begin
			$display("@E %d %04X RAM_DQ_IO Expected %04X.  Got %04X.", $time, story, expected, ram_dq_io);
			$stop;
		end
	end
	endtask

	task assert_ram_adr_o;
	input [22:0] expected;
	begin
		if(ram_adr_o !== expected) begin
			$display("@E %d %04X RAM_ADR_O Expected %d.  Got %d.", $time, story, expected, ram_adr_o);
			$stop;
		end
	end
	endtask

	task assert_ram_adv_on;
	input expected;
	begin
		if(ram_adv_on !== expected) begin
			$display("@E %d %04X RAM_ADV_On Expected %d.  Got %d.", $time, story, expected, ram_adv_on);
			$stop;
		end
	end
	endtask

	task assert_ram_oe_on;
	input expected;
	begin
		if(ram_oe_on !== expected) begin
			$display("@E %d %04X RAM_OE_On Expected %d.  Got %d.", $time, story, expected, ram_oe_on);
			$stop;
		end
	end
	endtask

	task assert_ram_we_on;
	input expected;
	begin
		if(ram_we_on !== expected) begin
			$display("@E %d %04X RAM_WE_On Expected %d.  Got %d.", $time, story, expected, ram_we_on);
			$stop;
		end
	end
	endtask

	task assert_ram_ub_on;
	input expected;
	begin
		if(ram_ub_on !== expected) begin
			$display("@E %d %04X RAM_UB_On Expected %d.  Got %d.", $time, story, expected, ram_ub_on);
			$stop;
		end
	end
	endtask

	task assert_ram_lb_on;
	input expected;
	begin
		if(ram_lb_on !== expected) begin
			$display("@E %d %04X RAM_LB_On Expected %d.  Got %d.", $time, story, expected, ram_lb_on);
			$stop;
		end
	end
	endtask

	task assert_reset_o;
	input expected;
	begin
		if(reset_o !== expected) begin
			$display("@E %d %04X RESET_O Expected %d.  Got %d.", $time, story, expected, reset_o);
			$stop;
		end
	end
	endtask

	task assert_ram_ce_on;
	input expected;
	begin
		if(ram_ce_on !== expected) begin
			$display("@E %d %04X RAM_CE_On Expected %d.  Got %d.", $time, story, expected, ram_ce_on);
			$stop;
		end
	end
	endtask

	initial begin
		$dumpfile("wtf.vcd");
		$dumpvars;

		clk2x_i <= 0;
		reset_i <= 1;
		wb_cyc_i <= 0;
		wb_stb_i <= 0;

		#30 reset_i <= 0;

		// Micron PSRAM chips require 150us to boot.  No, I'm not kidding.
		// Instead of (a)synchronously resetting their state when
		// powering on, these chips invoke a state machine program
		// which literally takes 150us to execute.  This is probably
		// due to some poor-quality RC-timed, relaxation oscillator
		// on the chip designed to be just good enough to complete the
		// chip's power-on initialization requirements.

		scenario(16'h0000);

		assert_reset_o(1);
		assert_ram_ce_on(1);
		assert_wb_ack_o(0);
		#150000		// Wait 150us
		assert_reset_o(1);
		assert_ram_ce_on(1);
		assert_wb_ack_o(0);
		#180000		// Wait until 330us have elapsed just to be safe.
		assert_reset_o(0);
		assert_ram_ce_on(1);
		assert_wb_ack_o(0);

		// Read transaction sequencing.
		//
		// Reads take place in six clock cycles.
		// 0.  Present address to PSRAM, issue read command.
		// 1.  Wait.  (20ns elapsed)
		// 2.  Wait.  (40ns elapsed)
		// 3.  Wait.  (60ns elapsed)
		// 4.  Enable RAM output and prepare to capture DQ output.  (80ns elapsed)
		// 5.  Drive WB data bus with captured value of DQ, and terminate both WB and PSRAM transactions.

		wait(~clk2x_i); wait(clk2x_i);
		scenario(16'h0100);

		wb_stb_i <= 1'b1;
		wb_cyc_i <= 1'b1;
		wb_adr_i <= 22'h012345;	// Any arbitrary address will work.
		wb_sel_i <= 2'b11;
		wb_we_i <= 0;

		#2;

		assert_wb_ack_o(0);

		assert_ram_adr_o(22'h012345);
		assert_ram_adv_on(0);
		assert_ram_ce_on(0);
		assert_ram_oe_on(1);
		assert_ram_we_on(1);
		assert_ram_ub_on(0);
		assert_ram_lb_on(0);

		wait(~clk2x_i); wait(clk2x_i);
		scenario(16'h0101);

		assert_wb_ack_o(0);

		assert_ram_adv_on(1);
		assert_ram_ce_on(0);
		assert_ram_oe_on(1);
		assert_ram_we_on(1);
		assert_ram_ub_on(1);
		assert_ram_lb_on(1);

		wait(~clk2x_i); wait(clk2x_i);
		scenario(16'h0102);

		assert_wb_ack_o(0);

		assert_ram_adv_on(1);
		assert_ram_ce_on(0);
		assert_ram_oe_on(1);
		assert_ram_we_on(1);
		assert_ram_ub_on(1);
		assert_ram_lb_on(1);

		wait(~clk2x_i); wait(clk2x_i);
		scenario(16'h0103);

		assert_wb_ack_o(0);

		assert_ram_adv_on(1);
		assert_ram_ce_on(0);
		assert_ram_oe_on(1);
		assert_ram_we_on(1);
		assert_ram_ub_on(1);
		assert_ram_lb_on(1);

		wait(~clk2x_i); wait(clk2x_i);
		scenario(16'h0104);

		assert_wb_ack_o(0);

		assert_ram_adv_on(1);
		assert_ram_ce_on(0);
		assert_ram_oe_on(0);
		assert_ram_we_on(1);
		assert_ram_ub_on(1);
		assert_ram_lb_on(1);

		ram_dq_o <= 16'hD00D;

		wait(~clk2x_i); wait(clk2x_i);
		scenario(16'h0105);

		assert_wb_ack_o(1);
		assert_wb_dat_o(16'hD00D);

		assert_ram_adv_on(1);
		assert_ram_ce_on(1);
		assert_ram_oe_on(1);
		assert_ram_we_on(1);
		assert_ram_ub_on(1);
		assert_ram_lb_on(1);

		// Write transaction sequencing.
		//
		// Writes take place in six clock cycles as well.
		// 0.  Present address to PSRAM, issue write command.
		// 1.  Wait.  (20ns elapsed)
		// 2.  Wait.  (40ns elapsed)
		// 3.  Present data onto DQ inputs.  (60ns elapsed)
		// 4.  Present data onto DQ inputs.  (80ns elapsed)
		// 5.  Terminate both WB and PSRAM transactions.

		wait(~clk2x_i); wait(clk2x_i);
		scenario(16'h0200);

		wb_stb_i <= 1'b1;
		wb_cyc_i <= 1'b1;
		wb_adr_i <= 22'h012345;
		wb_dat_i <= 16'h0BAD;
		wb_sel_i <= 2'b11;
		wb_we_i <= 1;

		#2;

		assert_wb_ack_o(0);

		assert_ram_adr_o(22'h012345);
		assert_ram_adv_on(0);
		assert_ram_ce_on(0);
		assert_ram_oe_on(1);
		assert_ram_we_on(0);
		assert_ram_ub_on(1);
		assert_ram_lb_on(1);

		wait(~clk2x_i); wait(clk2x_i);
		scenario(16'h0201);

		assert_wb_ack_o(0);

		assert_ram_adv_on(1);
		assert_ram_ce_on(0);
		assert_ram_oe_on(1);
		assert_ram_we_on(1);
		assert_ram_ub_on(1);
		assert_ram_lb_on(1);

		wait(~clk2x_i); wait(clk2x_i);
		scenario(16'h0202);

		assert_wb_ack_o(0);

		assert_ram_adv_on(1);
		assert_ram_ce_on(0);
		assert_ram_oe_on(1);
		assert_ram_we_on(1);
		assert_ram_ub_on(1);
		assert_ram_lb_on(1);

		wait(~clk2x_i); wait(clk2x_i);
		scenario(16'h0203);

		assert_wb_ack_o(0);

		assert_ram_adv_on(1);
		assert_ram_ce_on(0);
		assert_ram_oe_on(1);
		assert_ram_we_on(1);
		assert_ram_ub_on(0);
		assert_ram_lb_on(0);

		assert_ram_dq_io(16'h0BAD);

		wait(~clk2x_i); wait(clk2x_i);
		scenario(16'h0204);

		assert_wb_ack_o(0);

		assert_ram_adv_on(1);
		assert_ram_ce_on(0);
		assert_ram_oe_on(1);
		assert_ram_we_on(1);
		assert_ram_ub_on(0);
		assert_ram_lb_on(0);

		assert_ram_dq_io(16'h0BAD);

		wait(~clk2x_i); wait(clk2x_i);
		scenario(16'h0205);

		assert_wb_ack_o(1);

		assert_ram_adv_on(1);
		assert_ram_ce_on(1);
		assert_ram_oe_on(1);
		assert_ram_we_on(1);
		assert_ram_ub_on(1);
		assert_ram_lb_on(1);

		$display("@I Done.");
		$stop;
	end
endmodule

