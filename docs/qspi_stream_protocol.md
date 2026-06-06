# QSPI Stream Protocol

This design uses `ui_in[0]` as `qspi_sck`, `ui_in[1]` as active-low
`qspi_cs_n`, and `uio[3:0]` as the 4-bit bidirectional QSPI data bus.
Nibbles are transferred most-significant nibble first.

The core stores up to five in-flight ray contexts. A `STEP` command schedules
one context that already has a streamed voxel response. When a context finishes,
its compact result is queued and the context slot becomes free for a new ray.

Commands are one byte:

- `0x00` reset all contexts, results, and error state
- `0x10` auto-load one ray context, followed by 18 payload bytes
- `0x20` write voxel response, followed by context id byte and occupancy byte
- `0x30` step one ready context selected by the round-robin scheduler
- `0x40` read status, 4 bytes
- `0x41` read one voxel request, 4 bytes
- `0x42` read oldest result, 8 bytes
- `0x43` pop oldest result after reading it

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

Voxel response payload for `0x20`:

- byte 0: context id, 0 through 4
- byte 1: bit 0 is voxel occupancy

Status packet for `0x40`:

- byte 0: status bits
- byte 1: free context id, or `0xff` if no free slot exists
- byte 2: requesting context id, or `0xff` if no voxel request exists
- byte 3: result FIFO count

Status byte bits:

- bit 0: at least one active context
- bit 1: at least one free context slot
- bit 2: at least one voxel request exists
- bit 3: result available
- bit 4: all context slots full
- bit 5: at least one context is ready to step
- bit 6: QSPI data pins are being driven by the ASIC
- bit 7: protocol/error flag

Voxel request packet for `0x41`:

- byte 0: requesting context id, or `0xff` if no request exists
- byte 1: requested `voxel_x`
- byte 2: requested `voxel_y`
- byte 3: requested `voxel_z`

Result packet for `0x42`:

- byte 0: context id, or `0xff` if no result exists
- byte 1: `{unused[7:2], timeout, hit}`
- byte 2: pixel id
- byte 3: result x
- byte 4: result y
- byte 5: result z
- byte 6: step count
- byte 7: face id

Typical host loop:

1. Send `0x10` while the status packet reports a free slot.
2. Read `0x41` when status bit 2 is high.
3. Look up the requested voxel for that context id.
4. Send `0x20` with the context id and occupancy bit.
5. Send `0x30` while status bit 5 is high.
6. Read `0x42` when status bit 3 is high, then send `0x43` to pop it.
7. Keep loading new contexts whenever status bit 1 reports a free slot.
