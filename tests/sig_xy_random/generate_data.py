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

def compute_raw_gauss(image_array):
    """
    Performs 3x3 Gaussian convolution math without applying latency.
    """
    p = np.pad(image_array, pad_width=((1, 1), (1, 1)), mode='constant', constant_values=0).astype(np.uint32)
    out_data = (
        (p[0:-2, 0:-2]     ) + (p[0:-2, 1:-1] << 1) + (p[0:-2, 2:]     ) +
        (p[1:-1, 0:-2] << 1) + (p[1:-1, 1:-1] << 2) + (p[1:-1, 2:] << 1) +
        (p[2:,   0:-2]     ) + (p[2:,   1:-1] << 1) + (p[2:,   2:]     )
    ) >> 4
    return out_data.astype(np.uint16)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_x",  required=True)
    parser.add_argument("--input_y",  required=True)
    parser.add_argument("--output",   required=True)
    args = parser.parse_args()

    image_x = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    image_y = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)

    # 1. Hardware shifts inputs right by 1
    x_shifted = (image_x.astype(np.uint16) >> 1).astype(np.uint8)
    y_shifted = (image_y.astype(np.uint16) >> 1).astype(np.uint8)

    # 2. Path A: gauss(x_shifted * y_shifted)
    xy_prod = (x_shifted.astype(np.uint16) * y_shifted.astype(np.uint16))
    gauss_xy_raw = compute_raw_gauss(xy_prod)

    # 3. Path B: mu_x * mu_y
    mu_x_raw = compute_raw_gauss(x_shifted).astype(np.uint8)
    mu_y_raw = compute_raw_gauss(y_shifted).astype(np.uint8)
    mu_x_mu_y_raw = (mu_x_raw.astype(np.uint16) * mu_y_raw.astype(np.uint16))

    # 4. Compute Sigma (Subtraction)
    sigma_xy_raw = gauss_xy_raw.astype(np.int32) - mu_x_mu_y_raw.astype(np.int32)
    
    # 5. APPLY HARDWARE LATENCY (Crucial Step)
    # 2 rows from Line Buffers
    # 2 pixels from Gauss Window + 1 pixel from Mult + 1 pixel from Subtraction Reg = 4 pixels
    ROW_DELAY = 2
    PIXEL_DELAY = 4 

    final_output = np.zeros((IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.int16)
    
    # Slice the raw calculation into the delayed position
    final_output[ROW_DELAY:, PIXEL_DELAY:] = sigma_xy_raw[0:IMAGE_HEIGHT-ROW_DELAY, 0:IMAGE_WIDTH-PIXEL_DELAY]

    # 6. Convert to uint16 for the hex writer (Fixes OverflowError)
    sigma_xy_hex_ready = final_output.astype(np.int16).astype(np.uint16)

    # 7. Generate Files
    OUTPUT_PIXEL_SIZE = 16
    OUTPUT_DATA_WIDTH = PIXELS_PER_BEAT * OUTPUT_PIXEL_SIZE

    s_beats_x = write_axi_stream_hex(args.input_x, image_x, DATA_WIDTH)
    s_beats_y = write_axi_stream_hex(args.input_y, image_y, DATA_WIDTH)
    m_beats   = write_axi_stream_hex(args.output,  sigma_xy_hex_ready, OUTPUT_DATA_WIDTH)

    # 8. Write Config
    output_dir = os.path.dirname(args.output)
    with open(os.path.join(output_dir, "tb_config.svh"), 'w') as f:
        f.write(f"`define S_AXIS_DATA_WIDTH  {DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS {s_beats_x}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH  {OUTPUT_DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS {m_beats}\n")

if __name__ == "__main__":
    main()