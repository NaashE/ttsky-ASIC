import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge


async def write_reg(dut, addr, data):
    dut.ui_in.value = data
    dut.uio_in.value = (1 << 6) | (addr & 0x3F)
    await RisingEdge(dut.clk)
    dut.uio_in.value = 0
    await RisingEdge(dut.clk)


async def read_reg(dut, addr):
    dut.uio_in.value = (1 << 7) | (addr & 0x3F)
    await RisingEdge(dut.clk)
    dut.uio_in.value = 0
    await RisingEdge(dut.clk)
    return int(dut.uo_out.value)


@cocotb.test()
async def test_wrapper_register_smoke(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 4)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    assert int(dut.uio_out.value) == 0
    assert int(dut.uio_oe.value) == 0

    await write_reg(dut, 0x10, 0x2A)
    assert await read_reg(dut, 0x10) == 0x2A

    dut.ena.value = 0
    await ClockCycles(dut.clk, 1)
    assert int(dut.uo_out.value) == 0
