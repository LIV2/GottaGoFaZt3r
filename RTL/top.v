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
        output reg BUFDIR,
        output reg BUFOE_n,
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

`include "globalparams.vh"

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
wire autoconfig_cfgout;

wire [3:0] ram_base_addr;

reg [27:8] ADDR;
reg autoconfig_addr_match;
reg ram_addr_match;

wire match = autoconfig_addr_match || ram_addr_match;
wire configured;
wire validspace = FC[1] ^ FC[0]; // 1 when FC indicates user/supervisor data/program space
wire shutup;

// Latch address bits 27-8 on FCS_n asserted
// 
always @(negedge FCS_n or negedge RST_n)
begin
  if (!RST_n) begin
    ADDR                  <= 20'b0;
    ram_addr_match        <= 0;
    autoconfig_addr_match <= 0;
  end else begin
    BUFDIR <= READ;
    ADDR[27:8] <= A[27:8];

    if (AD[31:28] == ram_base_addr && configured) begin
      ram_addr_match <= 1;
    end else begin
      ram_addr_match <= 0;
    end

    if ({AD[31:28],A[27:24]} == 8'hFF && !configured && !shutup && !CFGIN_n) begin
      autoconfig_addr_match <= 1;
    end else begin
      autoconfig_addr_match <= 0;
    end
  end
end

reg [1:0] z3_state;
reg dtack;
reg ram_cycle;
reg autoconfig_cycle;
wire autoconfig_dtack;
wire ram_dtack;

always @(posedge CLK or negedge RST_n)
begin
  if (!RST_n) begin
    z3_state         <= Z3_IDLE;
    dtack            <= 1'b0;
    ram_cycle        <= 1'b0;
    autoconfig_cycle <= 1'b0;
  end else begin
    case (z3_state)
      Z3_IDLE:
        begin
          dtack <= 0;
          if (!FCS_n_sync[1] && match && validspace) begin
            z3_state         <= Z3_START;
            autoconfig_cycle <= autoconfig_addr_match;
            ram_cycle        <= ram_addr_match;
          end else begin
            autoconfig_cycle <= 0;
            ram_cycle        <= 0;
            z3_state         <= Z3_IDLE;
          end
        end
      Z3_START:
        begin
          if (FCS_n_sync[1]) begin
            z3_state <= Z3_IDLE;
          end else if (READ || (!DS0_n_sync[1] || !DS1_n_sync[1] || !DS2_n_sync[1] || !DS3_n_sync[1]) && DOE) begin
            z3_state <= Z3_DATA;
          end else begin
            z3_state <= Z3_START;
          end
        end
      Z3_DATA:
        begin
          if (FCS_n_sync[1]) begin
            z3_state <= Z3_IDLE;
          end else if (autoconfig_dtack && autoconfig_cycle || ram_dtack && ram_cycle) begin
            dtack <= 1;
            z3_state <= Z3_END;
          end
        end
      Z3_END:
        begin
          if (FCS_n_sync[1]) begin
            z3_state <= Z3_IDLE;
            ram_cycle <= 0;
            autoconfig_cycle <= 0;
            dtack <= 0;
          end else begin
            z3_state <= Z3_END;
          end
        end
    endcase
  end
end

Autoconfig AUTOCONFIG (
  .ram_base_addr (ram_base_addr),
  .ADDRL ({ADDR[8], A[7:2]}),
  .FCS_n (FCS_n_sync[1]),
  .CLK (CLK),
  .READ (READ),
  .DIN (AD[31:28]),
  .RESET_n (RST_n),
  .CFGOUT_n (autoconfig_cfgout),
  .autoconfig_cycle (autoconfig_cycle),
  .dtack (autoconfig_dtack),
  .configured (configured),
  .DOUT (autoconfig_dout),
  .z3_state (z3_state),
  .shutup (shutup)
);

SDRAM SDRAM (
  .ADDR ({ADDR[27:8], A[7:2]}),
  .DS_n ({DS3_n_sync[1], DS2_n_sync[1], DS1_n_sync[1], DS0_n_sync[1]}),
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
  .dtack (ram_dtack),
  .configured (configured),
  .z3_state (z3_state)
);

assign AD[31:28] = (!FCS_n && autoconfig_cycle && BERR_n && DOE && READ) ? autoconfig_dout[3:0] : 4'bZ;

always @(posedge CLK or posedge FCS_n or negedge BERR_n)
begin
  if (FCS_n) begin
    BUFOE_n <= 1;
  end else if (!BERR_n) begin
    BUFOE_n <= 1;
  end else begin
    if (!FCS_n_sync[1] && ram_cycle && DOE)
      BUFOE_n <= 0;
  end
end

assign CFGOUT_n = (SENSEZ3) ? autoconfig_cfgout : CFGIN_n;

assign SLAVE_n = !(!FCS_n && match && validspace);

assign DTACK_n = (!SLAVE_n) ? !dtack : 1'bZ;
assign MTACK_n = 1'bZ;

endmodule

