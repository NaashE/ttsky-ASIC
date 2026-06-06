import cocotb
from cocotb.triggers import ClockCycles


async def qspi_set(dut, cs_n, sck, dq):
    dut.ui_in.value = (cs_n << 1) | sck
    dut.uio_in.value = dq & 0x0F
    await ClockCycles(dut.clk, 3)


async def qspi_nibble(dut, value):
    await qspi_set(dut, 0, 0, value)
    await qspi_set(dut, 0, 1, value)
    await qspi_set(dut, 0, 0, value)


async def qspi_byte(dut, value):
    await qspi_nibble(dut, (value >> 4) & 0x0F)
    await qspi_nibble(dut, value & 0x0F)


async def qspi_transaction(dut, values):
    await qspi_set(dut, 1, 0, 0)
    await qspi_set(dut, 0, 0, 0)
    for value in values:
        await qspi_byte(dut, value)
    await qspi_set(dut, 1, 0, 0)
    await ClockCycles(dut.clk, 4)


def status(dut):
    return int(dut.uo_out.value)


@cocotb.test()
async def test_qspi_stream_smoke(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0x02
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 4)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    assert int(dut.uio_out.value) == 0
    assert int(dut.uio_oe.value) == 0

    # CMD_WRITE_CONTEXT followed by one compact 18-byte ray context.
    # Start at (0,0,0), step positive X/Y/Z, timers 0/1/2, increments 1,
    # allow ten steps, and tag the ray with pixel id 0x2a.
    await qspi_transaction(dut, [
        0x10,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00,
        0x00, 0x01,
        0x00, 0x02,
        0x00, 0x01,
        0x00, 0x01,
        0x00, 0x01,
        0x0A, 0x2A,
    ])

    assert status(dut) & 0x01  # active
    assert status(dut) & 0x02  # needs_voxel

    await qspi_transaction(dut, [0x20, 0x00])  # stream empty voxel
    assert (status(dut) & 0x02) == 0

    await qspi_transaction(dut, [0x30])  # advance one DDA step
    assert status(dut) & 0x01
    assert status(dut) & 0x02
    assert (status(dut) & 0x04) == 0

    dut.ena.value = 0
    await ClockCycles(dut.clk, 1)
    assert int(dut.uo_out.value) == 0
