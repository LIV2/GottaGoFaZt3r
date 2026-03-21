# Regression Tests

This directory contains simulation regressions for the Verilog RTL:

- `autoconfig_tb.v` validates the Autoconfig ROM contents, configuration writes, and chain hand-off behavior.
- `autoconfig_serial_tb.v` validates that the optional serial-number fields expose the configured serial value.
- `sdram_tb.v` validates the SDRAM controller initialization sequence, refresh priority, read/write command flow, `DTACK` timing, and address/byte-lane mapping.
- `top_tb.v` validates top-level Zorro III decode, bus claiming rules, Autoconfig integration, base-address programming, and RAM read-cycle handshaking.

## Running

The suite is written for `iverilog` and `vvp`.

```sh
cd tests
make
```

Or run individual regressions:

```sh
cd tests
make run-autoconfig
make run-autoconfig-serial
make run-sdram
make run-top
```

## Coverage Intent

These tests are meant to guard the main behavior that future RTL changes can accidentally break:

- Zorro III Autoconfig identity fields and write semantics
- serial-number field encoding for non-default card serials
- card selection only in valid address/function-code spaces
- release from Autoconfig after configure or shut-up
- high-impedance behavior on shared bus lines when the card is not driving them
- SDRAM startup sequence and periodic refresh preference
- row, bank, chip-select, and mirrored column address mapping
- read/write `DTACK`, DS-gated write start, and data-buffer enable sequencing

These tests are spec-driven rather than implementation-driven. If current RTL disagrees with the expected Zorro III behavior, the regression should fail and force that mismatch to be resolved explicitly.

Verified locally with `iverilog`/`vvp` 13.0 on March 20, 2026 using:

```sh
cd tests
make clean && make
```
