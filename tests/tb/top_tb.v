`timescale 1ns / 1ps

module top_tb;

reg [27:2] A;
tri [31:28] AD;
reg [3:0] ad_drive;
reg ad_drive_en;
reg BERR_n;
reg CFGIN_n;
reg CLK;
reg DOE;
reg [3:0] DS_n;
reg E;
reg [2:0] FC;
reg FCS_n;
reg MTCR_n;
reg READ;
reg RST_n;
reg SENSEZ3;

wire TP1;
wire TP2;
wire CFGOUT_n;
wire DTACK_n;
wire SLAVE_n;
wire MTACK_n;
wire BUFDIR;
wire BUFOE_n;
wire CAS_n;
wire CKE;
wire [1:0] CS_n;
wire [1:0] BA;
wire [3:0] DQM_n;
wire [12:0] MA;
wire MEMCLK;
wire RAS_n;
wire WE_n;

wire [3:0] ad_sense = AD;

integer failures;
integer cycles;

function [6:0] cfg_bus_addr;
  input [6:0] reg_addr;
begin
  cfg_bus_addr = {reg_addr[0], reg_addr[6:1]};
end
endfunction

function [25:0] cfg_read_cycle_addr;
  input [6:0] reg_addr;
begin
  cfg_read_cycle_addr = {4'hF, 15'h0000, cfg_bus_addr(reg_addr)};
end
endfunction

function [25:0] cfg_write_cycle_addr;
  input [5:0] reg_word_addr;
begin
  cfg_write_cycle_addr = {4'hF, 15'h0000, 1'b0, reg_word_addr};
end
endfunction

assign AD = ad_drive_en ? ad_drive : 4'bzzzz;

GottaGoFaZt3r dut (
  .A(A),
  .AD(AD),
  .BERR_n(BERR_n),
  .CFGIN_n(CFGIN_n),
  .CLK(CLK),
  .DOE(DOE),
  .DS_n(DS_n),
  .E(E),
  .FC(FC),
  .FCS_n(FCS_n),
  .MTCR_n(MTCR_n),
  .READ(READ),
  .RST_n(RST_n),
  .SENSEZ3(SENSEZ3),
  .TP1(TP1),
  .TP2(TP2),
  .CFGOUT_n(CFGOUT_n),
  .DTACK_n(DTACK_n),
  .SLAVE_n(SLAVE_n),
  .MTACK_n(MTACK_n),
  .BUFDIR(BUFDIR),
  .BUFOE_n(BUFOE_n),
  .CAS_n(CAS_n),
  .CKE(CKE),
  .CS_n(CS_n),
  .BA(BA),
  .DQM_n(DQM_n),
  .MA(MA),
  .MEMCLK(MEMCLK),
  .RAS_n(RAS_n),
  .WE_n(WE_n)
);

always #5 CLK = ~CLK;
always #7 E = ~E;

task tick;
begin
  @(posedge CLK);
  #1;
  cycles = cycles + 1;
end
endtask

task check1;
  input actual;
  input expected;
  input [255:0] message;
begin
  if (actual !== expected) begin
    $display("FAIL: %0s (expected=%0b actual=%0b)", message, expected, actual);
    failures = failures + 1;
  end
end
endtask

task check4;
  input [3:0] actual;
  input [3:0] expected;
  input [255:0] message;
begin
  if (actual !== expected) begin
    $display("FAIL: %0s (expected=0x%0h actual=0x%0h)", message, expected, actual);
    failures = failures + 1;
  end
end
endtask

task checkz1;
  input actual;
  input [255:0] message;
begin
  if (actual !== 1'bz) begin
    $display("FAIL: %0s (expected=Z actual=%0b)", message, actual);
    failures = failures + 1;
  end
end
endtask

task checkz4;
  input [3:0] actual;
  input [255:0] message;
begin
  if (actual !== 4'bzzzz) begin
    $display("FAIL: %0s (expected=Z actual=0x%0h)", message, actual);
    failures = failures + 1;
  end
end
endtask

task wait_for_dtack;
  input integer max_cycles;
  integer i;
begin
  begin : wait_loop
    for (i = 0; i < max_cycles; i = i + 1) begin
      if (DTACK_n === 1'b0) begin
        disable wait_loop;
      end
      tick;
    end
  end
  if (DTACK_n !== 1'b0) begin
    $display("FAIL: timed out waiting for DTACK_n");
    failures = failures + 1;
  end
end
endtask

task wait_for_cfgout;
  input expected;
  input integer max_cycles;
  integer i;
begin
  begin : wait_loop
    for (i = 0; i < max_cycles; i = i + 1) begin
      if (CFGOUT_n === expected) begin
        disable wait_loop;
      end
      tick;
    end
  end
  if (CFGOUT_n !== expected) begin
    $display("FAIL: timed out waiting for CFGOUT_n=%0b", expected);
    failures = failures + 1;
  end
end
endtask

task finish_cycle;
begin
  FCS_n = 1'b1;
  DS_n = 4'hF;
  ad_drive_en = 1'b0;
  READ = 1'b1;
  tick;
end
endtask

task start_read_cycle;
  input [3:0] upper_addr;
  input [27:2] lower_addr;
  input [2:0] fc;
begin
  A = lower_addr;
  FC = fc;
  READ = 1'b1;
  DS_n = 4'hF;
  ad_drive = upper_addr;
  ad_drive_en = 1'b1;
  #2;
  FCS_n = 1'b0;
  #1;
  ad_drive_en = 1'b0;
end
endtask

task start_write_cycle;
  input [3:0] upper_addr;
  input [27:2] lower_addr;
  input [2:0] fc;
  input [3:0] write_data;
begin
  A = lower_addr;
  FC = fc;
  READ = 1'b0;
  DS_n = 4'b1110;
  ad_drive = upper_addr;
  ad_drive_en = 1'b1;
  #2;
  FCS_n = 1'b0;
  #1;
  ad_drive = write_data;
end
endtask

initial begin
  failures = 0;
  cycles = 0;
  A = 26'h0;
  ad_drive = 4'h0;
  ad_drive_en = 1'b0;
  BERR_n = 1'b1;
  CFGIN_n = 1'b0;
  CLK = 1'b0;
  DOE = 1'b1;
  DS_n = 4'hF;
  E = 1'b0;
  FC = 3'b010;
  FCS_n = 1'b1;
  MTCR_n = 1'b1;
  READ = 1'b1;
  RST_n = 1'b0;
  SENSEZ3 = 1'b1;

  #2;
  check1(MEMCLK, ~CLK, "MEMCLK is inverted CLK");

  RST_n = 1'b1;

  tick;
  check1(CFGOUT_n, 1'b1, "unconfigured Z3 card keeps CFGOUT_n high");
  checkz1(DTACK_n, "board leaves DTACK_n floating when not selected");
  checkz4(ad_sense, "board leaves AD[31:28] floating when idle");

  start_read_cycle(4'hF, cfg_read_cycle_addr(7'h00), 3'b010);
  check1(SLAVE_n, 1'b0, "autoconfig cycle claims the bus");
  wait_for_dtack(16);
  check4(ad_sense, 4'hA, "autoconfig register 0 returns Zorro III memory type");
  finish_cycle;
  checkz1(DTACK_n, "autoconfig read releases DTACK_n after cycle");
  checkz4(ad_sense, "autoconfig read releases AD[31:28] after cycle");

  start_read_cycle(4'hF, cfg_read_cycle_addr(7'h00), 3'b000);
  check1(SLAVE_n, 1'b1, "invalid function code does not select the board");
  tick;
  check1(DTACK_n === 1'b0, 1'b0, "invalid function code never generates dtack");
  finish_cycle;

  start_read_cycle(4'hE, cfg_read_cycle_addr(7'h00), 3'b010);
  check1(SLAVE_n, 1'b1, "wrong upper address nibble does not select autoconfig");
  tick;
  checkz1(DTACK_n, "wrong autoconfig address keeps DTACK_n floating");
  finish_cycle;

  SENSEZ3 = 1'b0;
  CFGIN_n = 1'b1;
  #1;
  check1(CFGOUT_n, 1'b1, "non-Z3 mode passes CFGIN_n through");
  CFGIN_n = 1'b0;
  #1;
  check1(CFGOUT_n, 1'b0, "non-Z3 mode tracks CFGIN_n");
  SENSEZ3 = 1'b1;

  start_write_cycle(4'hF, cfg_write_cycle_addr(6'h11), 3'b010, 4'h4);
  wait_for_dtack(16);
  check1(dut.AUTOCONFIG.configured, 1'b1, "autoconfig write sets configured flag");
  check4(dut.AUTOCONFIG.ram_base_addr, 4'h4, "autoconfig write latches RAM base nibble");
  finish_cycle;
  wait_for_cfgout(1'b0, 4);
  check1(CFGOUT_n, 1'b0, "configured card releases autoconfig chain");

  start_read_cycle(4'hF, cfg_read_cycle_addr(7'h00), 3'b010);
  check1(SLAVE_n, 1'b1, "configured card no longer responds in autoconfig space");
  tick;
  checkz1(DTACK_n, "configured card keeps DTACK_n floating in autoconfig space");
  finish_cycle;

  start_read_cycle(4'h4, {20'h00012, 6'h08}, 3'b010);
  check1(SLAVE_n, 1'b0, "configured base address selects RAM window");
  wait_for_dtack(24);
  check1(dut.ram_cycle, 1'b1, "top-level flags RAM cycle once base address matches");
  check1(BUFDIR, 1'b1, "read cycle drives buffer direction to bus input");
  check1(BUFOE_n, 1'b0, "read cycle enables data buffers");
  finish_cycle;

  start_read_cycle(4'h4, {20'h00012, 6'h08}, 3'b010);
  BERR_n = 1'b0;
  #1;
  check1(BUFOE_n, 1'b1, "bus error disables the data buffers");
  BERR_n = 1'b1;
  finish_cycle;

  DOE = 1'b0;
  start_read_cycle(4'h4, {20'h00012, 6'h08}, 3'b010);
  wait_for_dtack(24);
  check1(BUFOE_n, 1'b1, "DOE low keeps read data buffers disabled");
  finish_cycle;
  DOE = 1'b1;

  start_read_cycle(4'h5, {20'h00012, 6'h08}, 3'b010);
  check1(SLAVE_n, 1'b1, "wrong RAM base nibble does not select RAM window");
  tick;
  checkz1(DTACK_n, "wrong RAM base nibble keeps DTACK_n floating");
  finish_cycle;

  start_read_cycle(4'h4, {20'h00012, 6'h08}, 3'b000);
  check1(SLAVE_n, 1'b1, "invalid function code does not select RAM window");
  tick;
  checkz1(DTACK_n, "invalid function code keeps RAM DTACK_n floating");
  finish_cycle;

  start_write_cycle(4'h4, {20'h00012, 6'h08}, 3'b010, 4'h9);
  check1(BUFDIR, 1'b0, "write cycle drives buffer direction toward SDRAM");
  check1(BUFOE_n, 1'b1, "write cycle does not enable read data buffers");
  DS_n = 4'hF;
  repeat (6) tick;
  check1(DTACK_n === 1'b0, 1'b0, "write cycle does not acknowledge before data strobes assert");
  DS_n = 4'b1110;
  wait_for_dtack(24);
  finish_cycle;

  RST_n = 1'b0;
  #2;
  RST_n = 1'b1;
  tick;
  start_write_cycle(4'hF, cfg_write_cycle_addr(6'h13), 3'b010, 4'h0);
  wait_for_dtack(16);
  check1(dut.AUTOCONFIG.shutup, 1'b1, "shutup write sets shutup");
  finish_cycle;
  wait_for_cfgout(1'b0, 4);
  start_read_cycle(4'hF, cfg_read_cycle_addr(7'h00), 3'b010);
  check1(SLAVE_n, 1'b1, "shutup removes card from autoconfig chain");
  tick;
  checkz1(DTACK_n, "shutup leaves DTACK_n floating in autoconfig space");
  finish_cycle;

  if (failures == 0) begin
    $display("PASS: top_tb");
  end else begin
    $display("FAIL: top_tb (%0d failures)", failures);
    $fatal(1);
  end
  $finish;
end

endmodule
