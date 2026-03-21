IVERILOG ?= iverilog
VVP ?= vvp
IVERILOG_FLAGS ?= -g2012 -Wall -I../RTL
BUILD_DIR ?= .build

RTL_COMMON := ../RTL/globalparams.vh
TOP_RTL := ../RTL/top.v ../RTL/autoconfig.v ../RTL/sdram.v $(RTL_COMMON)
AUTOCONFIG_RTL := ../RTL/autoconfig.v $(RTL_COMMON)
SDRAM_RTL := ../RTL/sdram.v $(RTL_COMMON)

TESTS := autoconfig autoconfig-serial sdram top

.PHONY: all clean $(TESTS:%=run-%)

all: $(TESTS:%=run-%)

run-autoconfig: $(BUILD_DIR)/autoconfig_tb.vvp
	$(VVP) $<

run-autoconfig-serial: $(BUILD_DIR)/autoconfig_serial_tb.vvp
	$(VVP) $<

run-sdram: $(BUILD_DIR)/sdram_tb.vvp
	$(VVP) $<

run-top: $(BUILD_DIR)/top_tb.vvp
	$(VVP) $<

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/autoconfig_tb.vvp: tb/autoconfig_tb.v $(AUTOCONFIG_RTL) | $(BUILD_DIR)
	$(IVERILOG) $(IVERILOG_FLAGS) -o $@ tb/autoconfig_tb.v ../RTL/autoconfig.v

$(BUILD_DIR)/autoconfig_serial_tb.vvp: tb/autoconfig_serial_tb.v $(AUTOCONFIG_RTL) | $(BUILD_DIR)
	$(IVERILOG) $(IVERILOG_FLAGS) "-DSERIAL=32'h12345678" -o $@ tb/autoconfig_serial_tb.v ../RTL/autoconfig.v

$(BUILD_DIR)/sdram_tb.vvp: tb/sdram_tb.v $(SDRAM_RTL) | $(BUILD_DIR)
	$(IVERILOG) $(IVERILOG_FLAGS) -o $@ tb/sdram_tb.v ../RTL/sdram.v

$(BUILD_DIR)/top_tb.vvp: tb/top_tb.v $(TOP_RTL) | $(BUILD_DIR)
	$(IVERILOG) $(IVERILOG_FLAGS) -o $@ tb/top_tb.v ../RTL/top.v ../RTL/autoconfig.v ../RTL/sdram.v

clean:
	rm -rf $(BUILD_DIR)
