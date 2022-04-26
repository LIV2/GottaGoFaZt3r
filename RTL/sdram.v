 `timescale 1ns / 1ps

module SDRAM(
    input [27:2] ADDR,
    input [3:0] DS_n,
    input DOE,
    input FCS_n,
    input ram_cycle,
    input RESET_n,
    input RW,
    input CLK,
    input ECLK,
    input configured,
    input MTCR_n,
    output [1:0] BA,
    output [12:0] MADDR,
    output CAS_n,
    output RAS_n,
    output [1:0] CS_n,
    output WE_n,
    output reg CKE,
    output reg [3:0] DQM_n,
    output DTACK_EN
    );

localparam tRP = 1;
localparam tRCD = 1;
localparam tRFC = 4;
localparam CAS_LATENCY = 3'd2;

`define initcmd(ARG) \
{ras_i_n, cas_i_n, we_i_n} <= ARG;

`define cmd(ARG) \
{ras_r_n, cas_r_n, we_r_n} <= ARG;

// RAS CAS WE
localparam cmd_nop             = 3'b111,
           cmd_active          = 3'b011,
           cmd_read            = 3'b101,
           cmd_write           = 3'b100,
           cmd_burst_terminate = 3'b110,
           cmd_precharge       = 3'b010,
           cmd_auto_refresh    = 3'b001,
           cmd_load_mode_reg   = 3'b000;

localparam mode_register = {
  3'b0,        // M10-12 - Reserved
  1'b1,        // M9     - No burst mode, Single access
  2'b0,        // M8-7   - Standard operation
  CAS_LATENCY, // M6-4   - CAS Latency 
  1'b0,        // M3     - Burst type
  3'b0         // M2-0   - Burst length
};

reg [1:0] cs_i_n;
reg ras_i_n;
reg cas_i_n;
reg we_i_n;
reg [1:0] cs_r_n;
reg ras_r_n;
reg cas_r_n;
reg we_r_n;

reg [12:0] maddr_i;
reg [12:0] maddr_r;
reg [1:0] ba_r;

reg init_done;
reg [6:0] init_state;

reg [3:0] refresh_timer;
reg [1:0] refresh_request;
reg refreshing;

assign MADDR = (init_done) ? maddr_r : maddr_i;
assign BA     = ba_r;
assign CS_n   = (init_done) ? cs_r_n : cs_i_n;
assign RAS_n  = (init_done) ? ras_r_n : ras_i_n;
assign CAS_n  = (init_done) ? cas_r_n : cas_i_n;
assign WE_n   = (init_done) ? we_r_n : we_i_n;

localparam init_cycle_precharge1 = 0,
           init_cycle_refresh1   = init_cycle_precharge1 + tRP,
           init_cycle_precharge2 = init_cycle_refresh1 + tRFC,
           init_cycle_refresh2   = init_cycle_precharge2 + tRP,
           init_cycle_load       = init_cycle_refresh2 + tRFC,
           init_cycle_done       = init_cycle_load + 1;

always @(negedge CLK or negedge RESET_n) begin
  if (!RESET_n) begin
    init_state  <= init_cycle_precharge1;
    init_done   <= 0;
    maddr_i     <= 13'b0;
    cs_i_n[1:0] <= 2'b00;
  end else begin
     // Ram Initialization //
      if (!init_done && configured) begin
        init_state <= init_state + 1;
        case (init_state)
          // Precharge
          init_cycle_precharge1, init_cycle_precharge2:
            begin
              `initcmd(cmd_precharge)
             maddr_i[11:0] <= {2'b01,10'b0};
            end
          // Autorefresh
          init_cycle_refresh1, init_cycle_refresh2:
            begin
              `initcmd(cmd_auto_refresh)
            end
          // Load Mode Register
          init_cycle_load:
            begin
              `initcmd(cmd_load_mode_reg)
              maddr_i[12:0] <= mode_register;
            end
           // Init done, ram idle
           init_cycle_done:
             begin
              init_done <= 1;
            end  
          default:
            begin
              `initcmd(cmd_nop)
              cs_i_n[1:0] <= 2'b00;
            end
        endcase
      end
      // End RAM Initialization //
    end
end



reg [4:0] ram_state = 0;
reg cycle_type = 0;

localparam ram_cycle_access  = 1'b1;
localparam ram_cycle_refresh = 1'b0;

localparam ram_cycle_idle         = 5'b00000,
           access_cycle_wait      = ram_cycle_idle+tRCD,
           access_cycle_rw        = access_cycle_wait+1,
           access_cycle_hold      = access_cycle_rw+1,
           access_cycle_precharge = access_cycle_hold+1,
           refresh_cycle_pre      = 5'b00000,
           refresh_cycle_auto     = refresh_cycle_pre+1,
           refresh_cycle_end      = refresh_cycle_auto+tRFC;

wire refreshreset = !refreshing & RESET_n;

always @(posedge ECLK or negedge refreshreset) begin
  if (!refreshreset) begin
    refresh_timer <= 4'h4;
  end else begin
    if (refresh_timer > 0) begin
      refresh_timer <= refresh_timer - 1;
    end
  end
end

always @(posedge CLK or negedge RESET_n) begin
  if (!RESET_n) begin
    refresh_request <= 0;
  end else begin
    refresh_request <= {refresh_request[0], refresh_timer == 0};
  end
end

reg [1:0] ram_cycle_sync;
reg dtack;

always @(posedge CLK) begin
  ram_cycle_sync[1:0] <= {ram_cycle_sync[0], ram_cycle};
end

always @(posedge CLK or negedge RESET_n)
begin
  if (!RESET_n) begin
    `cmd(cmd_nop)
    maddr_r[12:0]   <= 13'b0;
    ba_r[1:0]       <= 2'b0;
    CKE             <= 1'b0;
    dtack           <= 1'b0;
    refreshing      <= 1'b0;
    DQM_n[3:0]      <= 4'b1111;
    cs_r_n[1:0]     <= 2'b11;
    ram_state       <= 1'b0;
  end else begin
    if (ram_state == 0) begin
      CKE         <= 1'b1;
      dtack       <= 1'b0;
      DQM_n[3:0]  <= 4'b1111;
      cs_r_n[1:0] <= 2'b11;
      refreshing  <= 1'b0;
      if (init_done) begin
        // Refresh has the highest priority
        // If refresh_request active, go do a refresh
        if (refresh_request[1] == 1) begin
          `cmd(cmd_precharge)
          maddr_r[10]  <= 1'b1; // Precharge all banks
          cycle_type   <= ram_cycle_refresh;
          ram_state    <= refresh_cycle_auto;
          cs_r_n[1:0]  <= 2'b00; // Refresh all modules
          refreshing   <= 1'b1;
        // If refresh_request not active and we're in a ram cycle, go do a ram access
        end else if (ram_cycle_sync[1] && !FCS_n) begin
          `cmd(cmd_active)
          cycle_type    <= ram_cycle_access;
          ram_state     <= access_cycle_wait;
          maddr_r[12:0] <= ADDR[23:11];
          ba_r[1:0]     <= ADDR[25:24];
          cs_r_n[1:0]   <= {ADDR[26],~ADDR[26]};
        // No refresh needed at this time and no memory access, idle
        end else begin
          cs_r_n[1:0]    <= 2'b11;
          `cmd(cmd_nop)
        end
      end
    end else begin
      if (cycle_type == ram_cycle_access) begin
        case (ram_state)

          // Wait
          //
          // Wait for tRCD and also wait until we see data strobes before committing writes
          access_cycle_wait: begin
            `cmd(cmd_nop)
            if (DS_n[3:0] != 4'b1111 && DOE || RW)
              ram_state <= access_cycle_rw;
            else
              ram_state <= access_cycle_wait; // No data strobes seen yet, hold off
          end

          // Read/Write
          //
          // Uses A27 as MA9 so that memory is mirrored above 128MB when using 4x32MB chips
          // Kickstart will detect the mirror and add 128MB to the free pool rather than 256MB
          // This allows for the board to be assembled with 128MB or 256MB without needing separate firmware.
          access_cycle_rw: begin
            dtack <= 1;
            maddr_r[12:0] <= {3'b000,ADDR[27], ADDR[10:2]};
            if (!RW) begin
              `cmd(cmd_write)
              DQM_n[3:0] <= DS_n[3:0];
            end else begin
              `cmd(cmd_read)
              // Reads must return a full long regardless of DS (Zorro III Bus Specifications pg 3-3)
              DQM_n[3:0] <= 4'b0000;
            end
            ram_state <= access_cycle_hold;
          end

          // Hold
          //
          // Take CKE low until the end of the Zorro cycle in order to hold the read output
          // For write cycles, just keep NOP'ing
          access_cycle_hold: begin
            dtack <= 0;
            `cmd(cmd_nop)
            if (!FCS_n && DS_n[3:0] != 4'b1111) begin
              if (RW)
                CKE <= 0;
              ram_state <= access_cycle_hold;
            end else begin
              CKE <= 1;
              if (!FCS_n)
                // If Data strobes went inactive before FCS_n then it must be a burst
                // Go do the next burst cycle
                ram_state <= access_cycle_wait;
              else
                // Otherwise precharge and return to idle state
                ram_state <= access_cycle_precharge;
            end
          end

          // Precharge all banks
          access_cycle_precharge: begin
            `cmd(cmd_precharge)
            maddr_r[10] <= 1'b1;
            ram_state <= ram_cycle_idle;
          end

          default: begin
            // We should never get here...
            `cmd(cmd_nop)
            ram_state <= ram_state+1;
          end

        endcase
      end else begin
        ram_state <= ram_state + 1;
        case (ram_state)
          refresh_cycle_auto:
            `cmd(cmd_auto_refresh)

          refresh_cycle_end: begin
            ram_state <= ram_cycle_idle;
          end

          default:
            `cmd(cmd_nop)
        endcase
      end
    end
  end
end

reg [3:0] dtack_delayed;
always @(posedge CLK or negedge RESET_n) begin
  if (!RESET_n)
    dtack_delayed[3:0] <= 4'b0;
  else
    dtack_delayed[3:0] <= {dtack_delayed[2:0], dtack};
end

// Really bad hack to pulse dtack for 3xClock period during bursts... will be removed
assign DTACK_EN = dtack_delayed[1] || dtack_delayed[2] || dtack_delayed[3];

endmodule

