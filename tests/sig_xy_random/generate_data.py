import argparse
import os
import sys
import numpy as np

# Utility import - ensures write_axi_stream_hex is accessible
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../utils/python')))
from axis_hex import write_axi_stream_hex

IMAGE_WIDTH = 512
IMAGE_HEIGHT = 512
PIXELS_PER_BEAT = 16
PIXEL_SIZE = 8
DATA_WIDTH = PIXELS_PER_BEAT * PIXEL_SIZE # 128 bits

def compute_gauss(image_array, out_dtype=np.uint16):
    """
    Bit-accurate 3x3 Gaussian filter with 2-row/2-pixel hardware latency.
    Matches the CONV_GAUSS module behavior.
    """
    # Use uint32 for internal sums to prevent intermediate overflow
    p = np.pad(image_array, pad_width=((0, 2), (0, 2)), mode='constant', constant_values=0).astype(np.uint32)
    
    # 3x3 Gaussian approximation: 1/16 * [1 2 1; 2 4 2; 1 2 1]
    out_data = (
        (p[0:-2, 0:-2]     ) + (p[0:-2, 1:-1] << 1) + (p[0:-2, 2:]     ) +
        (p[1:-1, 0:-2] << 1) + (p[1:-1, 1:-1] << 2) + (p[1:-1, 2:] << 1) +
        (p[2:,   0:-2]     ) + (p[2:,   1:-1] << 1) + (p[2:,   2:]     )
    ) >> 4

    # Create output container with 2-row/2-pixel delay alignment
    expected_output = np.zeros((image_array.shape[0], image_array.shape[1]), dtype=out_dtype)
    expected_output[2:, 2:] = out_data[0:-2, 0:-2].astype(out_dtype)
    return expected_output

def main():
    parser = argparse.ArgumentParser(description="Generate data for SIG_XY module verification.")
    parser.add_argument("--input_x", required=True)
    parser.add_argument("--input_y", required=True)
    parser.add_argument("--output",  required=True)
    args = parser.parse_args()

    # 1. Generate random 8-bit unsigned images
    image_x = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    image_y = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)

    # 2. Hardware Logic: Right shift by 1 before processing
    x_shifted = (image_x.astype(np.uint16) >> 1).astype(np.uint8)
    y_shifted = (image_y.astype(np.uint16) >> 1).astype(np.uint8)

    # 3. Path A: gauss(x_shifted * y_shifted)
    # xy product: Max 127*127 = 16,129 (fits in uint16)
    xy = (x_shifted.astype(np.uint16) * y_shifted.astype(np.uint16))
    gauss_xy = compute_gauss(xy, out_dtype=np.uint16)

    # 4. Path B: mu_x * mu_y
    # CONV_GAUSS in Path B outputs 8-bit pixels (PIXEL_SIZE=8)
    mu_x = compute_gauss(x_shifted, out_dtype=np.uint8)
    mu_y = compute_gauss(y_shifted, out_dtype=np.uint8)
    mu_x_mu_y = (mu_x.astype(np.uint16) * mu_y.astype(np.uint16))

    # 5. Final Stage: Subtraction (Signed 16-bit)
    # sigma_xy = gauss_xy - mu_x_mu_y
    sigma_xy = gauss_xy.astype(np.int32) - mu_x_mu_y.astype(np.int32)
    
    # FIX: Cast to int16 for 2's complement, then uint16 for the hex utility mask
    sigma_xy_final = sigma_xy.astype(np.int16).astype(np.uint16)

    # Define Data Widths
    INPUT_DATA_WIDTH  = DATA_WIDTH           # 128 bits (8-bit pixels)
    OUTPUT_DATA_WIDTH = PIXELS_PER_BEAT * 16 # 256 bits (16-bit signed results)

    # 6. Generate AXI-Stream Hex Files
    s_beats_x = write_axi_stream_hex(args.input_x, image_x, INPUT_DATA_WIDTH)
    s_beats_y = write_axi_stream_hex(args.input_y, image_y, INPUT_DATA_WIDTH)
    m_beats   = write_axi_stream_hex(args.output,  sigma_xy_final, OUTPUT_DATA_WIDTH)

    # 7. Write SystemVerilog Config Header
    output_dir = os.path.dirname(args.output)
    config_file = os.path.join(output_dir, "tb_config.svh")
    
    with open(config_file, 'w') as f:
        f.write("// Auto-generated SIG_XY Testbench Configuration\n")
        f.write(f"`define S_AXIS_DATA_WIDTH  {INPUT_DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS {s_beats_x}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH  {OUTPUT_DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS {m_beats}\n")

    print(f"Generated {args.input_x}, {args.input_y}, {args.output}, and {config_file}")

if __name__ == "__main__":
    main()