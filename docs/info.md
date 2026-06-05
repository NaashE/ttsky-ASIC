<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements a voxel ray tracing accelerator behind the standard
TinyTapeout eight-bit input, eight-bit output, and eight-bit bidirectional pin
interface.

The external interface is a simple byte-wide register file. The host writes
register bytes through `ui_in[7:0]`, selects registers with `uio_in[5:0]`, pulses
`uio_in[6]` to write, and pulses `uio_in[7]` to latch a read address. Read data
is returned on `uo_out[7:0]`. The bidirectional output path is unused, so
`uio_out` and `uio_oe` are held at zero.

Internally, host registers configure scene loading, ray start coordinates,
direction signs, DDA timers and increments, and the maximum step count. The
raytracer walks the voxel grid, checks occupancy through the voxel RAM, and
captures sticky result status for software to read back.

## How to test

Run the TinyTapeout cocotb smoke test from the `test` directory:

```sh
make
```

For local SystemVerilog testbenches on Windows with Icarus Verilog installed,
run:

```powershell
powershell -ExecutionPolicy Bypass -File .\test\run_iverilog.ps1
```

The register protocol can be tested by writing a byte to a writable register
and reading it back through the latched read address path. Scene data is loaded
by setting load mode, writing the load address and load bit, then pulsing the
load command in the control register. A ray is launched by programming the job
registers and setting the job-start bit in the control register.

## External hardware

No external hardware is required beyond a host capable of driving the
TinyTapeout digital pins.
