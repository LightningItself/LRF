import argparse
import os
import sys
import numpy as np

# Utility import
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../utils/python')))
from axis_hex import write_axi_stream_hex

IMAGE_WIDTH = 512
IMAGE_HEIGHT = 512
PIXELS_PER_BEAT = 16
PIXEL_SIZE = 8
DATA_WIDTH = PIXELS_PER_BEAT * PIXEL_SIZE

def compute_gauss(image_array, out_dtype=np.uint16):
    # Use uint32 for the sum to prevent overflow during intermediate addition
    p = np.pad(image_array, pad_width=((0, 2), (0, 2)), mode='constant', constant_values=0).astype(np.uint32)
    
    # 3x3 Gaussian Kernel logic
    out_data = (
        (p[0:-2, 0:-2]     ) + (p[0:-2, 1:-1] << 1) + (p[0:-2, 2:]     ) +
        (p[1:-1, 0:-2] << 1) + (p[1:-1, 1:-1] << 2) + (p[1:-1, 2:] << 1) +
        (p[2:,   0:-2]     ) + (p[2:,   1:-1] << 1) + (p[2:,   2:]     )
    ) >> 4

    expected_output = np.zeros((image_array.shape[0], image_array.shape[1]), dtype=out_dtype)
    # Hardware latency alignment (2-row, 2-pixel delay)
    expected_output[2:, 2:] = out_data[0:-2, 0:-2].astype(out_dtype)
    return expected_output

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_x",  required=True)
    parser.add_argument("--input_y",  required=True)
    parser.add_argument("--output",   required=True)
    args = parser.parse_args()

    image_x = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    image_y = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)

    # 1. Hardware shifts inputs right by 1 (8-bit unsigned becomes 7-bit value)
    x_shifted = (image_x.astype(np.uint16) >> 1).astype(np.uint8)
    y_shifted = (image_y.astype(np.uint16) >> 1).astype(np.uint8)

    # 2. Path A: gauss(x_shifted * y_shifted)
    # xy product fits in uint16 (127*127 = 16129)
    xy = (x_shifted.astype(np.uint16) * y_shifted.astype(np.uint16))
    gauss_xy = compute_gauss(xy, out_dtype=np.uint16)

    # 3. Path B: mu_x * mu_y
    # CRITICAL: In RTL, mean_x/y PIXEL_SIZE is 8. Cast to uint8 to match hardware.
    mu_x = compute_gauss(x_shifted, out_dtype=np.uint8)
    mu_y = compute_gauss(y_shifted, out_dtype=np.uint8)
    mu_x_mu_y = (mu_x.astype(np.uint16) * mu_y.astype(np.uint16))

    # 4. Final Subtraction (Signed 16-bit)
    # Range: ~ -16129 to +16129
    sigma_xy = gauss_xy.astype(np.int32) - mu_x_mu_y.astype(np.int32)
    sigma_xy_final = sigma_xy.astype(np.int16)

    # Data Widths
    INPUT_DATA_WIDTH = DATA_WIDTH # 128 bits
    OUTPUT_DATA_WIDTH = PIXELS_PER_BEAT * 16 # 256 bits

    s_beats_x = write_axi_stream_hex(args.input_x, image_x, INPUT_DATA_WIDTH)
    s_beats_y = write_axi_stream_hex(args.input_y, image_y, INPUT_DATA_WIDTH)
    m_beats   = write_axi_stream_hex(args.output,  sigma_xy_final, OUTPUT_DATA_WIDTH)

    # Config Generation
    output_dir = os.path.dirname(args.output)
    config_file = os.path.join(output_dir, "tb_config.svh")
    with open(config_file, 'w') as f:
        f.write(f"`define S_AXIS_DATA_WIDTH  {INPUT_DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS {s_beats_x}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH  {OUTPUT_DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS {m_beats}\n")

if __name__ == "__main__":
    main()