# QSPI Stream Protocol

This design uses `ui_in[0]` as `qspi_sck`, `ui_in[1]` as active-low
`qspi_cs_n`, and `uio[3:0]` as the 4-bit bidirectional QSPI data bus.
Nibbles are transferred most-significant nibble first.

Commands are one byte:

- `0x00` reset internal ray state
- `0x10` write one ray context, followed by 18 payload bytes
- `0x20` write current voxel occupancy, followed by 1 payload byte
- `0x30` advance one DDA step using the current streamed voxel
- `0x40` read status, 2 bytes
- `0x41` read current coordinates, 5 bytes
- `0x42` read final result, 7 bytes

Context payload for `0x10`:

- byte 0: `voxel_x[5:0]`
- byte 1: `voxel_y[5:0]`
- byte 2: `voxel_z[5:0]`
- byte 3: `{unused[7:3], step_z_neg, step_y_neg, step_x_neg}`
- bytes 4-5: `timer_x[15:0]`
- bytes 6-7: `timer_y[15:0]`
- bytes 8-9: `timer_z[15:0]`
- bytes 10-11: `inc_x[15:0]`
- bytes 12-13: `inc_y[15:0]`
- bytes 14-15: `inc_z[15:0]`
- byte 16: `max_steps`
- byte 17: `pixel_id`

Typical host loop:

1. Send `0x10` with a context.
2. Read `0x41` to get the voxel coordinate requested by the ASIC.
3. Look up that voxel in host memory.
4. Send `0x20` with bit 0 set to the occupancy value.
5. Send `0x30` to step.
6. Read `0x40`; if `result_valid` is not set, repeat from step 2.
7. Read `0x42` for the final hit/timeout result.

Status byte bits:

- bit 0: `active`
- bit 1: `needs_voxel`
- bit 2: `result_valid`
- bit 3: `result_hit`
- bit 4: `result_timeout`
- bit 5: `busy`
- bit 6: `qspi_driving`
- bit 7: reserved
