/*
GottaGoFaZt3r
Copyright 2022 Matthew Harlum

GottaGoFaZt3r is licensed under a
Creative Commons Attribution-ShareAlike 4.0 International License.

You should have received a copy of the license along with this
work. If not, see <http://creativecommons.org/licenses/by-sa/4.0/>.
*/

module Autoconfig (
    input match,
    output reg [3:0] addr_match,
    input [6:0] ADDRL,
    input FCS_n,
    input CLK,
    input READ,
    input DS_n,
    input CFGIN_n,
    input [3:0] DIN,
    input RESET_n,
    input SENSEZ3,
    input [2:0] FC,
    output reg CFGOUT_n,
    output ram_cycle,
    output autoconfig_cycle,
    output reg configured,
    output reg [3:0] DOUT
);


`ifndef makedefines
`define SERIAL 32'd421
`define PRODID 8'h72
`endif

localparam [15:0] mfg_id  = 16'h07DB;
localparam [7:0]  prod_id = `PRODID;
localparam [31:0] serial  = `SERIAL;

reg done = 0;
reg shutup = 0;

wire validspace = FC[1] ^ FC[0]; // 1 when FC indicates user/supervisor data/program space

reg [1:0] vs;
always @(posedge CLK) begin
  vs[1:0] <= {vs[0],validspace};
end

assign autoconfig_cycle = match && !CFGIN_n && CFGOUT_n && vs[1];
// Register Config in/out at end of bus cycle
always @(posedge FCS_n or negedge RESET_n)
begin
  if (!RESET_n) begin
    CFGOUT_n <= 1'b1;
  end else begin
    CFGOUT_n <= !configured && !shutup;
  end
end

always @(posedge CLK or negedge RESET_n)
begin
  if (!RESET_n) begin
    DOUT[3:0]       <= 4'b0;
    configured      <= 1'b0;
    shutup          <= 1'b0;
    addr_match[3:0] <= 4'b1111;
  end else if (autoconfig_cycle && !FCS_n) begin
    if (READ) begin
      case ({ADDRL[5:0],ADDRL[6]})
        7'h00:   DOUT[3:0] <= 4'b1010;        // Type: Zorro III Memory
        7'h01:   DOUT[3:0] <= 4'b0100;        // 256 MB
        7'h02:   DOUT[3:0] <= ~prod_id[7:4];  // Product number
        7'h03:   DOUT[3:0] <= ~prod_id[3:0];  // Product number
        7'h04:   DOUT[3:0] <= ~4'b1011;       // Memory device, Size Extension, Zorro III
        7'h05:   DOUT[3:0] <= ~4'b0001;       // Automatically sized by OS
        7'h08:   DOUT[3:0] <= ~mfg_id[15:12]; // Manufacturer ID
        7'h09:   DOUT[3:0] <= ~mfg_id[11:8];  // Manufacturer ID
        7'h0A:   DOUT[3:0] <= ~mfg_id[7:4];   // Manufacturer ID
        7'h0B:   DOUT[3:0] <= ~mfg_id[3:0];   // Manufacturer ID
        7'h0C:   DOUT[3:0] <= ~serial[31:28]; // Serial number
        7'h0D:   DOUT[3:0] <= ~serial[27:24]; // Serial number
        7'h0E:   DOUT[3:0] <= ~serial[23:20]; // Serial number
        7'h0F:   DOUT[3:0] <= ~serial[19:16]; // Serial number
        7'h10:   DOUT[3:0] <= ~serial[15:12]; // Serial number
        7'h11:   DOUT[3:0] <= ~serial[11:8];  // Serial number
        7'h12:   DOUT[3:0] <= ~serial[7:4];   // Serial number
        7'h13:   DOUT[3:0] <= ~serial[3:0];   // Serial number
        7'h20:   DOUT[3:0] <= 4'b0;
        7'h21:   DOUT[3:0] <= 4'b0;
        default: DOUT[3:0] <= 4'hF;
      endcase
    end else begin
      if (ADDRL[5:0] == 6'h13 && !DS_n) begin
        // Shutup
        shutup <= 1;
      end else if (ADDRL[5:0] == 6'h11 && !DS_n) begin
        // Write base address
        addr_match <= DIN[3:0];
        configured <= 1;
      end
    end
  end
end

assign ram_cycle = (match && !CFGOUT_n && !shutup && vs[1]);
endmodule
