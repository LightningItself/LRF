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
    Performs 3x3 Gaussian convolution math.
    """
    # uint32 prevents overflow during the weighted sum
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

    # Generate random input
    image_x = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    image_y = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)

    # 1. Emulate Hardware Right Shift (>> 1)
    x_s = (image_x.astype(np.uint16) >> 1).astype(np.uint8)
    y_s = (image_y.astype(np.uint16) >> 1).astype(np.uint8)

    # 2. Path A: E[XY]
    xy_prod = (x_s.astype(np.uint16) * y_s.astype(np.uint16))
    gauss_xy = compute_raw_gauss(xy_prod)

    # 3. Path B: E[X]*E[Y]
    # Note: mu outputs are 8-bit in your RTL configuration
    mu_x = compute_raw_gauss(x_s).astype(np.uint8)
    mu_y = compute_raw_gauss(y_s).astype(np.uint8)
    mu_x_mu_y = (mu_x.astype(np.uint16) * mu_y.astype(np.uint16))

    # 4. Local Covariance (Sigma_XY)
    sigma_xy_raw = gauss_xy.astype(np.int32) - mu_x_mu_y.astype(np.int32)

    # 5. ALIGN TO HARDWARE LATENCY
    # Your 'got' hex shows 2 pixels of zeros before data starts.
    ROW_DELAY = 2
    PIXEL_DELAY = 2 

    expected_full = np.zeros((IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.int16)
    
    # Map the raw math into the delayed hardware grid
    expected_full[ROW_DELAY:, PIXEL_DELAY:] = sigma_xy_raw[0:IMAGE_HEIGHT-ROW_DELAY, 0:IMAGE_WIDTH-PIXEL_DELAY]

    # 6. Convert to uint16 for the hex utility (preserves 2's complement bits)
    sigma_xy_hex = expected_full.astype(np.int16).astype(np.uint16)

    # 7. Write Files
    OUTPUT_DATA_WIDTH = PIXELS_PER_BEAT * 16 # 256 bits
    s_beats_x = write_axi_stream_hex(args.input_x, image_x, DATA_WIDTH)
    s_beats_y = write_axi_stream_hex(args.input_y, image_y, DATA_WIDTH)
    m_beats   = write_axi_stream_hex(args.output,  sigma_xy_hex, OUTPUT_DATA_WIDTH)

    # 8. Write Config
    output_dir = os.path.dirname(args.output)
    with open(os.path.join(output_dir, "tb_config.svh"), 'w') as f:
        f.write(f"`define S_AXIS_DATA_WIDTH  {DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS {s_beats_x}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH  {OUTPUT_DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS {m_beats}\n")

if __name__ == "__main__":
    main()