`timescale 1ns / 1ps

module sdram_tb;

`include "globalparams.vh"

reg [27:2] ADDR;
reg [3:0] DS_n;
reg ram_cycle;
reg RESET_n;
reg RW;
reg CLK;
reg ECLK;
reg configured;
reg [1:0] z3_state;

wire [1:0] BA;
wire [12:0] MADDR;
wire CAS_n;
wire RAS_n;
wire [1:0] CS_n;
wire WE_n;
wire CKE;
wire [3:0] DQM_n;
wire dtack;

integer failures;
integer cycles;

localparam [2:0] CMD_NOP = 3'b111;
localparam [2:0] CMD_ACTIVE = 3'b011;
localparam [2:0] CMD_READ = 3'b101;
localparam [2:0] CMD_WRITE = 3'b100;
localparam [2:0] CMD_PRECHARGE = 3'b010;
localparam [2:0] CMD_AUTO_REFRESH = 3'b001;
localparam [2:0] CMD_LOAD_MODE = 3'b000;
localparam [12:0] EXPECTED_MODE = {3'b000, 1'b1, 2'b00, 3'd2, 1'b0, 3'b000};

SDRAM dut (
  .ADDR(ADDR),
  .DS_n(DS_n),
  .ram_cycle(ram_cycle),
  .RESET_n(RESET_n),
  .RW(RW),
  .CLK(CLK),
  .ECLK(ECLK),
  .configured(configured),
  .z3_state(z3_state),
  .BA(BA),
  .MADDR(MADDR),
  .CAS_n(CAS_n),
  .RAS_n(RAS_n),
  .CS_n(CS_n),
  .WE_n(WE_n),
  .CKE(CKE),
  .DQM_n(DQM_n),
  .dtack(dtack)
);

always #5 CLK = ~CLK;
always #7 ECLK = ~ECLK;

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

task check2;
  input [1:0] actual;
  input [1:0] expected;
  input [255:0] message;
begin
  if (actual !== expected) begin
    $display("FAIL: %0s (expected=0x%0h actual=0x%0h)", message, expected, actual);
    failures = failures + 1;
  end
end
endtask

task check3;
  input [2:0] actual;
  input [2:0] expected;
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

task check13;
  input [12:0] actual;
  input [12:0] expected;
  input [255:0] message;
begin
  if (actual !== expected) begin
    $display("FAIL: %0s (expected=0x%0h actual=0x%0h)", message, expected, actual);
    failures = failures + 1;
  end
end
endtask

task wait_for_idle;
begin
  while (dut.ram_state != dut.idle && cycles < 64) begin
    tick;
  end
  if (dut.ram_state != dut.idle) begin
    $display("FAIL: controller did not reach idle after initialization");
    failures = failures + 1;
  end
end
endtask

task wait_for_refresh_command;
  input integer max_cycles;
  integer i;
begin
  begin : wait_loop
    for (i = 0; i < max_cycles; i = i + 1) begin
      tick;
      if ({RAS_n, CAS_n, WE_n} === CMD_AUTO_REFRESH && CS_n === 2'b00) begin
        disable wait_loop;
      end
    end
  end
  if (!({RAS_n, CAS_n, WE_n} === CMD_AUTO_REFRESH && CS_n === 2'b00)) begin
    $display("FAIL: no automatic refresh observed within %0d cycles", max_cycles);
    failures = failures + 1;
  end
end
endtask

task wait_for_state;
  input [3:0] expected_state;
  input integer max_cycles;
  input [255:0] message;
  integer i;
begin
  begin : wait_loop
    for (i = 0; i < max_cycles; i = i + 1) begin
      if (dut.ram_state === expected_state) begin
        disable wait_loop;
      end
      tick;
    end
  end
  if (dut.ram_state !== expected_state) begin
    $display("FAIL: %0s", message);
    failures = failures + 1;
  end
end
endtask

task wait_for_dtack_high;
  input integer max_cycles;
  input [255:0] message;
  integer i;
begin
  begin : wait_loop
    for (i = 0; i < max_cycles; i = i + 1) begin
      if (dtack === 1'b1) begin
        disable wait_loop;
      end
      tick;
    end
  end
  if (dtack !== 1'b1) begin
    $display("FAIL: %0s", message);
    failures = failures + 1;
  end
end
endtask

initial begin
  failures = 0;
  cycles = 0;
  ADDR = 26'h0;
  DS_n = 4'hF;
  ram_cycle = 1'b0;
  RESET_n = 1'b0;
  RW = 1'b1;
  CLK = 1'b0;
  ECLK = 1'b0;
  configured = 1'b1;
  z3_state = Z3_IDLE;

  #2;
  check1(dtack, 1'b0, "reset clears dtack");
  check2(CS_n, 2'b11, "reset deselects chips");
  check4(DQM_n, 4'hF, "reset masks data");

  RESET_n = 1'b1;

  tick;
  check3({RAS_n, CAS_n, WE_n}, CMD_NOP, "power-on issues nop");
  check2(CS_n, 2'b00, "power-on selects both SDRAM devices");

  tick;
  check3({RAS_n, CAS_n, WE_n}, CMD_PRECHARGE, "initialization precharges all banks");
  check1(MADDR[10], 1'b1, "initialization precharge uses all-banks bit");

  tick;
  check3({RAS_n, CAS_n, WE_n}, CMD_NOP, "precharge wait issues nop");

  tick;
  check3({RAS_n, CAS_n, WE_n}, CMD_AUTO_REFRESH, "first init refresh is auto-refresh");
  check2(CS_n, 2'b00, "refresh selects all chips");

  repeat (4) tick;
  tick;
  check3({RAS_n, CAS_n, WE_n}, CMD_AUTO_REFRESH, "second init refresh is auto-refresh");

  repeat (4) tick;
  tick;
  check3({RAS_n, CAS_n, WE_n}, CMD_LOAD_MODE, "initialization loads mode register");
  check13(MADDR, EXPECTED_MODE, "mode register contents match CAS=2 single-shot mode");

  wait_for_idle;
  check1(dut.init_done, 1'b1, "initialization sets init_done");

  wait_for_refresh_command(32);
  repeat (4) tick;
  check1(dut.ram_state == dut.idle, 1'b1, "controller returns to idle after automatic refresh");

  ADDR = {1'b1, 1'b0, 2'b10, 13'h12A5, 9'h155};
  ram_cycle = 1'b1;
  RW = 1'b1;
  z3_state = Z3_START;

  tick;
  tick;
  check3({RAS_n, CAS_n, WE_n}, CMD_ACTIVE, "read cycle activates selected row");
  check13(MADDR, ADDR[23:11], "active command drives row address");
  check2(BA, ADDR[25:24], "active command drives bank address");
  check2(CS_n, {ADDR[26], ~ADDR[26]}, "active command chooses chip pair from A26");

  z3_state = Z3_DATA;
  tick;
  tick;
  check3({RAS_n, CAS_n, WE_n}, CMD_READ, "read cycle emits read command");
  check13(MADDR, {3'b001, ADDR[27], ADDR[10:2]}, "read command maps mirrored column address");
  check4(DQM_n, 4'h0, "read cycle always enables all byte lanes");

  tick;
  check1(dtack, 1'b1, "read data hold asserts dtack");
  check1(CKE, 1'b0, "read data hold suppresses SDRAM clock while bus cycle is active");

  z3_state = Z3_END;
  tick;
  check1(dtack, 1'b1, "read data hold keeps dtack asserted until bus cycle ends");
  check1(CKE, 1'b0, "read data hold keeps clock suppressed until idle");

  z3_state = Z3_IDLE;
  tick;
  check1(CKE, 1'b1, "read release restores SDRAM clock");
  tick;
  check1(dtack, 1'b0, "read release clears dtack");
  check1(dut.ram_state == dut.idle, 1'b1, "read release returns controller to idle");

  ADDR = {1'b0, 1'b1, 2'b01, 13'h1C3A, 9'h0E2};
  DS_n = 4'b1010;
  ram_cycle = 1'b1;
  RW = 1'b0;
  z3_state = Z3_START;

  wait_for_state(dut.active_wait, 16, "write path never reached active_wait");
  z3_state = Z3_DATA;
  wait_for_dtack_high(8, "write path never asserted dtack");
  check1(dtack, 1'b1, "write path asserts dtack before write commit");

  wait_for_state(dut.data_write, 8, "write path never reached data_write");
  tick;
  check3({RAS_n, CAS_n, WE_n}, CMD_WRITE, "write cycle emits write command");
  check13(MADDR, {3'b001, ADDR[27], ADDR[10:2]}, "write command maps mirrored column address");
  check4(DQM_n, DS_n, "write cycle respects byte-lane strobes");

  z3_state = Z3_IDLE;
  tick;
  check1(dtack, 1'b0, "write path clears dtack in precharge wait");
  tick;
  check1(dut.ram_state == dut.idle, 1'b1, "write path returns controller to idle");

  wait_for_refresh_command(32);
  repeat (4) tick;
  check1(dut.ram_state == dut.idle, 1'b1, "automatic refresh still occurs after traffic");

  if (failures == 0) begin
    $display("PASS: sdram_tb");
  end else begin
    $display("FAIL: sdram_tb (%0d failures)", failures);
    $fatal(1);
  end
  $finish;
end

endmodule
