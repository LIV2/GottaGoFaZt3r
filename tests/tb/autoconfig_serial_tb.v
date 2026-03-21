`timescale 1ns / 1ps

module autoconfig_serial_tb;

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

task read_and_check;
  input [6:0] reg_addr;
  input [3:0] expected;
  input [255:0] message;
begin
  ADDRL = read_bus_addr(reg_addr);
  READ = 1'b1;
  autoconfig_cycle = 1'b1;
  z3_state = Z3_DATA;
  tick;
  check4(DOUT, expected, message);
  autoconfig_cycle = 1'b0;
  z3_state = Z3_IDLE;
  tick;
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
  RESET_n = 1'b1;
  tick;

  read_and_check(7'h0C, 4'hE, "serial nibble 0");
  read_and_check(7'h0D, 4'hD, "serial nibble 1");
  read_and_check(7'h0E, 4'hC, "serial nibble 2");
  read_and_check(7'h0F, 4'hB, "serial nibble 3");
  read_and_check(7'h10, 4'hA, "serial nibble 4");
  read_and_check(7'h11, 4'h9, "serial nibble 5");
  read_and_check(7'h12, 4'h8, "serial nibble 6");
  read_and_check(7'h13, 4'h7, "serial nibble 7");

  if (failures == 0) begin
    $display("PASS: autoconfig_serial_tb");
  end else begin
    $display("FAIL: autoconfig_serial_tb (%0d failures)", failures);
    $fatal(1);
  end
  $finish;
end

endmodule
