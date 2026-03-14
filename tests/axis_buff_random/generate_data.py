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