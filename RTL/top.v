/*
GottaGoFaZt3r
Copyright 2022 Matthew Harlum

GottaGoFaZt3r is licensed under a
Creative Commons Attribution-ShareAlike 4.0 International License.

You should have received a copy of the license along with this
work. If not, see <http://creativecommons.org/licenses/by-sa/4.0/>.
*/

module GottaGoFaZt3r(
        input [27:2]  A,
        inout [31:28] AD,
        input BERR_n,
        input CFGIN_n,
        input CLK,
        input DOE,
        input [3:0] DS_n,
        input E,
        input [2:0] FC,
        input FCS_n,
        input MTCR_n,
        input READ,
        input RST_n,
        input SENSEZ3,
        output TP1,
        output TP2,
        output CFGOUT_n,
        output DTACK_n,
        output SLAVE_n,
        output MTACK_n,
        // RAM
        output BUFDIR,
        output BUFOE_n,
        output CAS_n,
        output CKE,
        output [1:0] CS_n,
        output [1:0] BA,
        output [3:0] DQM_n,
        output [12:0] MA,
        output MEMCLK,
        output RAS_n,
        output WE_n
    );

assign MEMCLK = ~CLK; 

// Synchronizers
reg [1:0] DS0_n_sync;
reg [1:0] DS1_n_sync;
reg [1:0] DS2_n_sync;
reg [1:0] DS3_n_sync;
reg [1:0] FCS_n_sync;

always @(posedge CLK or negedge RST_n)
begin
  if (!RST_n) begin
    DS0_n_sync[1:0] <= 2'b11;
    DS1_n_sync[1:0] <= 2'b11;
    DS2_n_sync[1:0] <= 2'b11;
    DS3_n_sync[1:0] <= 2'b11;
    FCS_n_sync[1:0] <= 2'b11;
  end else begin
    DS0_n_sync[1:0] <= {DS0_n_sync[0], DS_n[0]};
    DS1_n_sync[1:0] <= {DS1_n_sync[0], DS_n[1]};
    DS2_n_sync[1:0] <= {DS2_n_sync[0], DS_n[2]};
    DS3_n_sync[1:0] <= {DS3_n_sync[0], DS_n[3]};
    FCS_n_sync[1:0] <= {FCS_n_sync[0], FCS_n};
  end
end

// Autoconf
wire [3:0] autoconfig_dout;
wire autoconfig_cycle;
wire autoconfig_cfgout;
wire configured;

// addr_match comes from the autoconfig unit
// At reset it is 4'hF to match autoconfig cycles
// Autoconfig will then change addr_match to the new base address
wire [3:0] addr_match;

// Latch address bits 27-8 on FCS_n asserted
// 
// Also latch whether there's a match (rather than latching Address 31-28) 
// Doing things this way saves a bunch of space in the CPLD

reg [27:8] ADDR;
reg match;

always @(negedge FCS_n or negedge RST_n)
begin
  if (!RST_n) begin
    ADDR  <= 20'b0;
    match <= 1'b0;
  end else begin
    ADDR[27:8] <= A[27:8];
    if (AD[31:28] == addr_match) begin
      // Match 8 address bits when unconfigured (8'hFF) but only 4 when configured (256MB Blocks)
      match <= (configured || A[27:24] == 4'hF);
    end else begin
      match <= 1'b0;
    end
  end
end

Autoconfig AUTOCONFIG (
  .match (match),
  .addr_match (addr_match),
  .ADDRL ({ADDR[8], A[7:2]}),
  .FCS_n (FCS_n_sync[1]),
  .CLK (CLK),
  .READ (READ),
  .DS_n (DS3_n_sync[1]),
  .CFGIN_n (CFGIN_n),
  .DIN (AD[31:28]),
  .FC (FC[2:0]),
  .RESET_n (RST_n),
  .CFGOUT_n (autoconfig_cfgout),
  .ram_cycle (ram_cycle),
  .autoconfig_cycle (autoconfig_cycle),
  .configured (configured),
  .DOUT (autoconfig_dout),
  .SENSEZ3 (SENSEZ3)
);

SDRAM SDRAM (
  .ADDR ({ADDR[27:8], A[7:2]}),
  .DS_n ({DS3_n_sync[1], DS2_n_sync[1], DS1_n_sync[1], DS0_n_sync[1]}),
  .DOE (DOE),
  .FCS_n (FCS_n_sync[1]),
  .ram_cycle (ram_cycle),
  .RESET_n (RST_n),
  .RW (READ),
  .CLK (CLK),
  .ECLK (E),
  .BA (BA),
  .MADDR (MA),
  .CAS_n (CAS_n),
  .RAS_n (RAS_n),
  .CS_n (CS_n),
  .WE_n (WE_n),
  .CKE (CKE),
  .DQM_n (DQM_n),
  .DTACK_EN (ram_dtack),
  .MTCR_n (MTCR_n),
  .configured (configured)
);

// Latch DTACK on strobe from SDRAM unit
// Clear on cycle end
FDCP FDCP_inst (
  .CLR (FCS_n),
  .PRE (1'b0),
  .D (1'b1),
  .C (ram_dtack),
  .Q (dtack_latch)
);

reg bursting;

always @(negedge MTCR_n or posedge FCS_n) begin
  if (FCS_n)
    bursting <= 1'b0;
  else
    bursting <= 1'b1;
end

assign AD[31:28] = (autoconfig_cycle && BERR_n && DOE && READ) ? autoconfig_dout[3:0] : 4'bZ;

assign BUFOE_n = !ram_cycle || !DOE || !BERR_n;
assign BUFDIR = READ;
assign CFGOUT_n = (SENSEZ3) ? autoconfig_cfgout : CFGIN_n;

assign SLAVE_n = !(!FCS_n && (autoconfig_cycle || ram_cycle));
// Not the final equation, just testing different ideas to get bursts working well
assign DTACK_n = (!SLAVE_n) ? !(dtack_latch && !bursting || ram_dtack || autoconfig_cycle) : 1'bZ;

assign MTACK_n = (!SLAVE_n && ram_cycle) ? 1'b0 : 1'bZ;

endmodule

