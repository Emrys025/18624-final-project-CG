import cocotb
from cocotb.clock import Clock
from cocotb.result import TestFailure
import hashlib
import os
import logging
from cocotb.triggers import *
from cocotb.runner import *
from cocotb.utils import get_sim_time
import itertools
import random

@cocotb.test()
async def test_sha256(dut):
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.start.value = 0
    dut.valid_in.value = 0
    dut.message_in.value = 0

    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # random test generation
    message_chunks = [random.randint(0, 0x3FF) for _ in range(64)]  # 64x 10-bit values
    bit_stream = "".join(f"{chunk:010b}" for chunk in message_chunks)
    message_bytes = int(bit_stream, 2).to_bytes(80, byteorder='big')
    # expected_hash = hashlib.sha256(message_bytes).digest()

    for chunk in message_chunks:
        dut.valid_in.value = 1
        dut.message_in.value = chunk
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0

    while True:
        await RisingEdge(dut.clk)
        if dut.valid_out.value == 1:
            break

    hash_chunks = []
    for _ in range(26):
        hash_chunks.append(dut.hash_out.value.integer)
        await RisingEdge(dut.clk)

    bit_stream = []
    for chunk in hash_chunks:
        bits = format(chunk, '010b') 
        for bit in bits:
            bit_stream.append(int(bit))
    bit_stream = bit_stream[:256]

    byte_array = bytearray()
    for i in range(0, 256, 8):
        byte_bits = bit_stream[i:i+8]
        byte = 0
        for bit in byte_bits:
            byte = (byte << 1) | bit
        byte_array.append(byte)

    hash_bytes = bytes(byte_array)

    
    words = []
    for i in range(0, 32, 4):
        word_bytes = hash_bytes[i:i+4]
        word = int.from_bytes(word_bytes, byteorder='little')
        words.append(word)
    expected_bytes = b''
    for word in words:
        expected_bytes += word.to_bytes(4, byteorder='little')

    # Compute expected hash using hashlib
    expected = hashlib.sha256(message_bytes).digest()

    if expected_bytes != expected:
        raise TestFailure(f"Hash mismatch.\nExpected: {expected.hex()}\nReceived: {expected_bytes.hex()}")
    else:
        print("TEST PASSED")
    dut._log.info("Test passed!")
    
def run_test():
    sim = os.getenv("SIM", "icarus")

    verilog_sources = ["sha256.sv"]
    runner = get_runner(sim)
    runner.build(
        verilog_sources=verilog_sources,
        hdl_toplevel="dff",
        always=True,
    )

    runner.test(hdl_toplevel="sha256",
                test_module=os.path.splitext(os.path.basename(__file__))[0]+",",
                verbose=False)

if __name__ == "__main__":
    run_test()