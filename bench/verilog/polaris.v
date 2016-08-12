`timescale 1ns / 1ps

module test_polaris();
  reg [23:0] story_o;
  reg reset_o, clk_o;

  wire  [63:0]  adr_i;
  wire  [1:0]   size_i;
  wire          we_i;
  wire          vpa_i;
  reg           ack_o;
  reg   [15:0]  dat_o;

  wire          undefined_i;

  polaris p(
    .clk_i(clk_o),
    .reset_i(reset_o),
    .dat_i(dat_o),
    .adr_o(adr_i),
    .size_o(size_i),
    .we_o(we_i),
    .undefined_o(undefined_i),
    .vpa_o(vpa_i),
    .ack_i(ack_o)
  );

  always begin
    #20 clk_o <= ~clk_o;
  end

  task start;
  input [23:0] n;
  begin
    story_o <= n;
  end
  endtask

  task tick;
  begin
    @(posedge clk_o);
    @(negedge clk_o);
  end
  endtask

  task assert_adr_o;
  input [63:0] expected;
  begin
    if(expected !== adr_i) begin
      $display("@E %06X adr_o Expected %016X; got %016X", story_o, expected, adr_i);
      $stop;
    end
  end
  endtask

  task assert_we_o;
  input expected;
  begin
    if(expected !== we_i) begin
      $display("@E %06X we_o Expected %d; got %d", story_o, expected, we_i);
      $stop;
    end
  end
  endtask

  task assert_size_o;
  input [1:0] expected;
  begin
    if(expected !== size_i) begin
      $display("@E %06X size_o Expected %d; got %d", story_o, expected, size_i);
      $stop;
    end
  end
  endtask

  task assert_vpa_o;
  input expected;
  begin
    if(expected !== vpa_i) begin
      $display("@E %06X vpa_o Expected %d; got %d", story_o, expected, vpa_i);
      $stop;
    end
  end
  endtask

  task assert_undefined_o;
  input expected;
  begin
    if(expected !== undefined_i) begin
      $display("@E %06X undefined_o Expected %d; got %d", story_o, expected, undefined_i);
      $stop;
    end
  end
  endtask


  initial begin
    clk_o <= 0;
    reset_o <= 0;
    story_o <= -1;
    
    // The CPU should execute NOPs like a champ.

    start(24'h000000);
    reset_o <= 1;
    tick(); // At this point, RESET sets IR to ADDI X0, X0, 0
    assert_adr_o(64'hFFFF_FFFF_FFFF_FF00);
    assert_we_o(0);
    assert_size_o(2);
    assert_vpa_o(1);
    assert_undefined_o(0);

    start(24'h000010);
    reset_o <= 0;
    ack_o <= 1;
    dat_o <= 16'h0013;
    tick();
    tick();
    assert_adr_o(64'hFFFF_FFFF_FFFF_FF02);
    assert_we_o(0);
    assert_size_o(2);
    assert_vpa_o(1);
    assert_undefined_o(0);

    start(24'h000020);
    reset_o <= 0;
    ack_o <= 1;
    dat_o <= 16'h0000;
    tick(); // At this point, we just loaded our own ADDI X0, X0, 0 into IR.
    tick(); // At this point, we just loaded our own ADDI X0, X0, 0 into IR.
    assert_adr_o(64'hFFFF_FFFF_FFFF_FF04);
    assert_we_o(0);
    assert_size_o(2);
    assert_vpa_o(1);
    assert_undefined_o(0);

    start(24'h000030);
    reset_o <= 0;
    ack_o <= 1;
    dat_o <= 16'h0013;
    tick();
    tick();
    assert_adr_o(64'hFFFF_FFFF_FFFF_FF06);
    assert_we_o(0);
    assert_size_o(2);
    assert_vpa_o(1);
    assert_undefined_o(0);

    start(24'h000040);
    reset_o <= 0;
    ack_o <= 1;
    dat_o <= 16'h0000;
    tick();
    tick();
    assert_adr_o(64'hFFFF_FFFF_FFFF_FF08);
    assert_we_o(0);
    assert_size_o(2);
    assert_vpa_o(1);
    assert_undefined_o(0);

    // Fetching data from memory should be a piece of cake too.
    // We'll start by fetching a byte from memory, since this
    // (and half-words) are arguably the simplest thing you can do.
    //
    // LB = 32'h0000_0000_0000_00000_000_00010_0000011 (32'h00000103)
    // LH = 32'h0000_0000_0000_00000_001_00010_0000011 (32'h00001103)

$display("========================================");
    start(24'h000100);
    dat_o <= 16'hFFFF;
    tick();
    tick();
    dat_o <= 16'hFFFF;
    tick();
    tick();
    assert_undefined_o(0);

#20;

    $display("@I Done.");
    $stop;
  end
endmodule
