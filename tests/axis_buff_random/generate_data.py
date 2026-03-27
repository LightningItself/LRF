# This script generates test data and configuration files for AXI-stream simulation.
#
# Steps:
# 1. Parses command-line arguments for input and output file paths.
# 2. Generates random 8-bit input data of length LENGTH.
# 3. Creates expected output by casting input data to 16-bit.
# 4. Uses write_axi_stream_hex() to:
#    - Convert input data into AXI-stream hex format and write to input file.
#    - Convert expected output into AXI-stream hex format and write to output file.
# 5. Receives total number of AXI beats for both input and output.
# 6. Creates a configuration file (tb_config.svh) in the output directory.
# 7. Writes AXI parameters (data widths and total beats) as Verilog macros.
#
# Purpose:
# Automates generation of stimulus, expected results, and configuration
# for AXI-based testbench simulation.

import argparse
import os
import sys
import numpy as np

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../utils/python')))
from axis_hex import write_axi_stream_hex

LENGTH = 1024
S_AXIS_DATA_WIDTH = 8
M_AXIS_DATA_WIDTH = 16

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    input_data = np.random.randint(0, 256, LENGTH, dtype=np.uint8)   
    expected_output = input_data.astype(np.uint16)
    
    S_AXIS_TOTAL_BEATS = write_axi_stream_hex(args.input, input_data, S_AXIS_DATA_WIDTH)
    M_AXIS_TOTAL_BEATS = write_axi_stream_hex(args.output, expected_output, M_AXIS_DATA_WIDTH)
    
    output_dir = os.path.dirname(args.output)
    config_file = os.path.join(output_dir, "tb_config.svh")
    
    with open(config_file, 'w') as f:
        f.write(f"`define S_AXIS_DATA_WIDTH  {S_AXIS_DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS {S_AXIS_TOTAL_BEATS}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH  {M_AXIS_DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS {M_AXIS_TOTAL_BEATS}\n")

if __name__ == "__main__":
    main()