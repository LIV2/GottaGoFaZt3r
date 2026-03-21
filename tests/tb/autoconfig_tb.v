`timescale 1ns / 1ps

module autoconfig_tb;

`include "globalparams.vh"

reg autoconfig_cycle;
reg [6:0] ADDRL;
reg FCS_n;
reg CLK;
reg READ;
reg [3:0] DIN;
reg RESET_n;
reg [1:0] z3_state;

wire [3:0] ram_base_addr;
wire CFGOUT_n;
wire dtack;
wire configured;
wire shutup;
wire [3:0] DOUT;

integer failures;

function [6:0] read_bus_addr;
  input [6:0] reg_addr;
begin
  read_bus_addr = {reg_addr[0], reg_addr[6:1]};
end
endfunction

function [6:0] write_bus_addr;
  input [5:0] reg_word_addr;
begin
  write_bus_addr = {1'b0, reg_word_addr};
end
endfunction

Autoconfig dut (
  .autoconfig_cycle(autoconfig_cycle),
  .ADDRL(ADDRL),
  .FCS_n(FCS_n),
  .CLK(CLK),
  .READ(READ),
  .DIN(DIN),
  .RESET_n(RESET_n),
  .z3_state(z3_state),
  .ram_base_addr(ram_base_addr),
  .CFGOUT_n(CFGOUT_n),
  .dtack(dtack),
  .configured(configured),
  .shutup(shutup),
  .DOUT(DOUT)
);

always #5 CLK = ~CLK;

task tick;
begin
  @(posedge CLK);
  #1;
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

task do_read;
  input [6:0] addr;
  input [3:0] expected;
  input [255:0] message;
begin
  ADDRL = addr;
  READ = 1'b1;
  autoconfig_cycle = 1'b1;
  z3_state = Z3_DATA;
  tick;
  check1(dtack, 1'b1, {message, " asserted dtack"});
  check4(DOUT, expected, message);

  autoconfig_cycle = 1'b0;
  z3_state = Z3_IDLE;
  tick;
  check1(dtack, 1'b0, {message, " cleared dtack"});
end
endtask

task do_write;
  input [6:0] addr;
  input [3:0] data;
begin
  ADDRL = addr;
  DIN = data;
  READ = 1'b0;
  autoconfig_cycle = 1'b1;
  z3_state = Z3_DATA;
  tick;
  check1(dtack, 1'b1, "write asserted dtack");

  autoconfig_cycle = 1'b0;
  z3_state = Z3_IDLE;
  READ = 1'b1;
  tick;
  check1(dtack, 1'b0, "write cleared dtack");
end
endtask

task pulse_fcs;
begin
  FCS_n = 1'b0;
  #1;
  FCS_n = 1'b1;
  #1;
end
endtask

initial begin
  failures = 0;
  autoconfig_cycle = 1'b0;
  ADDRL = 7'h00;
  FCS_n = 1'b1;
  CLK = 1'b0;
  READ = 1'b1;
  DIN = 4'h0;
  RESET_n = 1'b0;
  z3_state = Z3_IDLE;

  #2;
  check1(CFGOUT_n, 1'b1, "reset keeps CFGOUT_n deasserted");
  check1(configured, 1'b0, "reset clears configured");
  check1(shutup, 1'b0, "reset clears shutup");
  check4(ram_base_addr, 4'h0, "reset clears base address");

  RESET_n = 1'b1;
  tick;

  do_read(read_bus_addr(7'h00), 4'hA, "type nibble");
  do_read(read_bus_addr(7'h01), 4'h4, "size nibble");
  do_read(read_bus_addr(7'h02), 4'hF, "product upper nibble");
  do_read(read_bus_addr(7'h03), 4'hC, "product lower nibble");
  do_read(read_bus_addr(7'h04), 4'h4, "flags nibble");
  do_read(read_bus_addr(7'h05), 4'hE, "autosize nibble");
  do_read(read_bus_addr(7'h08), 4'hE, "manufacturer nibble 0");
  do_read(read_bus_addr(7'h09), 4'hB, "manufacturer nibble 1");
  do_read(read_bus_addr(7'h0A), 4'hB, "manufacturer nibble 2");
  do_read(read_bus_addr(7'h0B), 4'h5, "manufacturer nibble 3");
  do_read(read_bus_addr(7'h0C), 4'hF, "serial nibble 0 defaults to zero");
  do_read(read_bus_addr(7'h0D), 4'hF, "serial nibble 1 defaults to zero");
  do_read(read_bus_addr(7'h0E), 4'hF, "serial nibble 2 defaults to zero");
  do_read(read_bus_addr(7'h0F), 4'hF, "serial nibble 3 defaults to zero");
  do_read(read_bus_addr(7'h10), 4'hF, "serial nibble 4 defaults to zero");
  do_read(read_bus_addr(7'h11), 4'hF, "serial nibble 5 defaults to zero");
  do_read(read_bus_addr(7'h12), 4'hF, "serial nibble 6 defaults to zero");
  do_read(read_bus_addr(7'h13), 4'hF, "serial nibble 7 defaults to zero");
  do_read(read_bus_addr(7'h20), 4'h0, "reserved upper base nibble");
  do_read(read_bus_addr(7'h21), 4'h0, "reserved lower base nibble");
  do_read(read_bus_addr(7'h7F), 4'hF, "unknown register defaults high");

  do_write(write_bus_addr(6'h11), 4'h9);
  check1(configured, 1'b1, "base address write sets configured");
  check4(ram_base_addr, 4'h9, "base address write stores nibble");
  pulse_fcs;
  check1(CFGOUT_n, 1'b0, "configured card drops CFGOUT_n after cycle");

  RESET_n = 1'b0;
  #2;
  RESET_n = 1'b1;
  tick;

  do_write(write_bus_addr(6'h13), 4'h0);
  check1(shutup, 1'b1, "shutup write latches shutup");
  pulse_fcs;
  check1(CFGOUT_n, 1'b0, "shutup drops CFGOUT_n after cycle");

  if (failures == 0) begin
    $display("PASS: autoconfig_tb");
  end else begin
    $display("FAIL: autoconfig_tb (%0d failures)", failures);
    $fatal(1);
  end
  $finish;
end

endmodule
