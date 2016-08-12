`timescale 1ns / 1ps

module polaris(
  input           clk_i,
  input           reset_i,

  output  [63:0]  adr_o,
  output  [1:0]   size_o,
  output          we_o,
  output          vpa_o,
  input           ack_i,
  input   [15:0]  dat_i,

  output          undefined_o
);
  reg   [63:2]  pc;   	// Next instruction address (program counter)
  wire	[63:2]	next_pc;// Next PC
  reg   [63:2]  ip;   	// Current instruction address (inst. ptr)
  reg   [31:0]  ir;   	// Current instruction.
  wire  [31:0]  next_ir;
  reg   [15:0]  irl, irh; // Next instruction.
  wire  [15:0]  next_irl, next_irh;
  reg   [2:0]   t;     	// Current, Next T-state.
  wire  [2:0]   nt;

  wire is_load = ir[6:0] == 7'b0000011;
  wire is_store = (ir[6:0] == 7'b0100011) & (ir[14] == 0);
  wire is_branch = (ir[6:0] == 7'b1100011) & (ir[14:13] != 2'b01);
  wire is_jalr = ir[6:0] == 7'b1100111;
  wire is_custom1 = ir[6:0] == 7'b0101011;  // Used to record a trap.
  wire is_jal = ir[6:0] == 7'b1101111;
  // Note that is_op_imm and is_op also covers is_op_32 and is_op_imm32 forms too.
  wire is_op_imm = is_addi | is_slli | is_slti | is_sltui | is_xori | is_srli | is_srai | is_ori | is_andi;
    wire is_addi = (ir[6:4] == 3'b001) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b000);
    wire is_slti = (ir[6:4] == 3'b001) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b010);
    wire is_sltui = (ir[6:4] == 3'b001) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b011);
    wire is_xori = (ir[6:4] == 3'b001) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b100);
    wire is_ori = (ir[6:4] == 3'b001) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b110);
    wire is_andi = (ir[6:4] == 3'b001) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b111);
    wire is_slli = (ir[6:4] == 3'b001) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b001) & (ir[31:26] == 6'b000_000);
    wire is_srli = (ir[6:4] == 3'b001) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b101) & (ir[31:26] == 6'b000_000);
    wire is_srai = (ir[6:4] == 3'b001) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b101) & (ir[31:26] == 6'b010_000);
  wire is_op = is_add | is_sub | is_sll | is_slt | is_sltu | is_xor | is_srl | is_sra | is_or | is_and;
    wire is_add = (ir[6:4] == 3'b011) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b000) & (ir[31:25] == 7'b000_0000);
    wire is_sub = (ir[6:4] == 3'b011) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b000) & (ir[31:25] == 7'b010_0000);
    wire is_slt = (ir[6:4] == 3'b011) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b010) & (ir[31:25] == 7'b000_0000);
    wire is_sltu = (ir[6:4] == 3'b011) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b011) & (ir[31:25] == 7'b000_0000);
    wire is_xor = (ir[6:4] == 3'b011) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b100) & (ir[31:25] == 7'b000_0000);
    wire is_or = (ir[6:4] == 3'b011) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b110) & (ir[31:25] == 7'b000_0000);
    wire is_and = (ir[6:4] == 3'b011) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b111) & (ir[31:25] == 7'b000_0000);
    wire is_sll = (ir[6:4] == 3'b011) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b001) & (ir[31:25] == 7'b000_0000);
    wire is_srl = (ir[6:4] == 3'b011) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b101) & (ir[31:25] == 7'b000_0000);
    wire is_sra = (ir[6:4] == 3'b011) & (ir[2:0] == 3'b011) & (ir[14:12] == 3'b101) & (ir[31:25] == 7'b010_0000);
  wire is_auipc = ir[6:0] == 7'b0010111;
  wire is_lui = ir[6:0] == 7'b0110111;
  wire is_mem_misc = is_fence | is_fence_i;
    wire is_fence = (ir[31:28] == 4'b0000) & (ir[19:0] == 20'b00000_000_00000_0001111);
    wire is_fence_i = ir[31:0] == 32'b0000_0000_0000_00000_001_00000_0001111;
  wire is_system = is_ecall | is_ebreak | is_csrrw | is_csrrs | is_csrrc | is_csrrwi | is_csrrsi | is_csrrci | is_mret | is_wfi;
    wire is_ecall = ir[31:0] == 32'b0000_0000_0000_00000_000_00000_1110011;
    wire is_ebreak = ir[31:0] == 32'b0000_0000_0001_00000_000_00000_1110011;
    wire is_csrrw = (ir[6:0] == 7'b1110011) & (ir[14:12] == 3'b001);  // & is_valid_csr;
    wire is_csrrs = (ir[6:0] == 7'b1110011) & (ir[14:12] == 3'b010);  // & is_valid_csr;
    wire is_csrrc = (ir[6:0] == 7'b1110011) & (ir[14:12] == 3'b011);  // & is_valid_csr;
    wire is_csrrwi = (ir[6:0] == 7'b1110011) & (ir[14:12] == 3'b101); // & is_valid_csr;
    wire is_csrrsi = (ir[6:0] == 7'b1110011) & (ir[14:12] == 3'b110); // & is_valid_csr;
    wire is_csrrci = (ir[6:0] == 7'b1110011) & (ir[14:12] == 3'b111); // & is_valid_csr;
    wire is_mret = ir[31:0] == 32'b0011_0000_0010_00000_000_00000_1110011;
    wire is_wfi = ir[31:0] == 32'b0001_0000_0101_00000_000_00000_1110011;

  always @(posedge clk_i) begin
    if(reset_i) begin
      pc <= 62'h3FFF_FFFF_FFFF_FFC0;
      ip <= 62'h3FFF_FFFF_FFFF_FFFF;
      ir <= 32'h0000_0013;  // ADDI X0, X0, 0
      t <= 3'd0;
    end
    else begin
      t <= nt;
      pc <= next_pc;
      irl <= next_irl;
      irh <= next_irh;
    end
  end

  // Loads, stores, op-imm, op-imm-32, op, op-32, auipc, and lui
  // instructions can all afford to prefetch the next instruction
  // while they execute.
  //
  // Of these, only loads and stores need to defer loading the
  // instruction register because these can take longe than four
  // cycles to execute.

  wire is_prefetchable = is_op_imm | is_op | is_auipc | is_lui;

  wire prefetch_t0 = is_prefetchable & (t == 3'd0);
  wire prefetch_t1 = is_prefetchable & (t == 3'd1);
  wire prefetch_t2 = is_prefetchable & (t == 3'd2);
  wire prefetch_t3 = is_prefetchable & (t == 3'd3);

  wire adr_pc = prefetch_t0 | prefetch_t1;
  wire adr_pc2 = prefetch_t2 | prefetch_t3;
  wire pc_pc4 = prefetch_t3 & ack_i;
  wire irl_dat = prefetch_t1 & ack_i;
  wire irh_dat = prefetch_t3 & ack_i;
  wire ir_dat_irl = prefetch_t3 & ack_i;
  wire ir_irh_irl = 0;	// for now...
  wire size_2 = is_prefetchable;

  assign next_pc = pc_pc4 ? (pc + 1) : pc;
  assign next_irl = irl_dat ? dat_i : irl;
  assign next_irh = irh_dat ? dat_i : irh;
  assign next_ir = ir_dat_irl ? {dat_i, irl} : ir_irh_irl ? {irh, irl} : ir;

  assign nt =
            (prefetch_t0) ? 3'd1 :
            (prefetch_t1) ? (ack_i ? 3'd2 : 3'd1) :
            (prefetch_t2) ? 3'd3 :
            (prefetch_t3) ? (ack_i ? 3'd0 : 3'd3) :
            0;

  assign adr_o = adr_pc ? {pc, 2'b00} : adr_pc2 ? {pc, 2'b10} : 0;
  assign we_o = 0;
  assign vpa_o = is_prefetchable;
  assign size_o = size_2 ? 2'd2 : 0;
  assign undefined_o = ~|{is_load, is_store, is_branch, is_jalr, is_jal, is_op_imm, is_op, is_auipc, is_lui, is_mem_misc, is_system};
always @(*) begin
  $display("is_load = %d", is_load);
  $display("is_store = %d", is_store);
  $display("is_branch = %d", is_branch);
  $display("is_jalr = %d", is_jalr);
  $display("is_jal = %d", is_jal);
  $display("is_op_imm = %d", is_op_imm);
  $display("is_op = %d", is_op);
  $display("is_auipc = %d", is_auipc);
  $display("is_lui = %d", is_lui);
  $display("is_mem_misc = %d", is_mem_misc);
  $display("is_system = %d", is_system);
end
endmodule
