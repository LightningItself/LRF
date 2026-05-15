import argparse
import os
import sys
import numpy as np

# Ensure your utility path is correct
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../utils/python')))
from axis_hex import write_axi_stream_hex

# RTL Parameters - DOUBLE CHECK THESE MATCH YOUR VERILOG PARAMETERS
IMAGE_DIM = 512
PIXELS_PER_BEAT = 16
PIXEL_SIZE = 8

S_DATA_WIDTH = PIXELS_PER_BEAT * PIXEL_SIZE
M_DATA_WIDTH = PIXELS_PER_BEAT * (PIXEL_SIZE * 2)

def apply_gauss_rtl_behavior(img):
    h, w = img.shape
    p = img.astype(np.uint64) 
    res = np.zeros((h, w), dtype=np.uint64)

    for r in range(h):
        for c in range(w):
            # 1. RTL: (row_ptr < 2) ? 0
            if r < 2:
                res[r, c] = 0
                continue
            
            # 2. RTL: (col_ptr == 0 && pixel_index < 2) ? 0
            # Note: In your RTL, pixels 2-15 of the first beat ARE calculated
            # but they use 'last_top/mid/bot' which are 0 at row start.
            if c < 2:
                res[r, c] = 0
                continue

            # 3. Gaussian Convolution Math (3x3)
            # p[r] is current row, p[r-1] is mid, p[r-2] is top
            val = ( (p[r-2, c-2]     ) + (p[r-2, c-1] << 1) + (p[r-2, c]     ) +
                    (p[r-1, c-2] << 1) + (p[r-1, c-1] << 2) + (p[r-1, c] << 1) +
                    (p[r,   c-2]     ) + (p[r,   c-1] << 1) + (p[r,   c]     ) ) >> 4
            res[r, c] = val
            
    return res

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_x", required=True)
    parser.add_argument("--input_y", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    # 1. Generate Random Inputs
    print(f"[PYTHON] Generating {IMAGE_DIM}x{IMAGE_DIM} images...")
    x_img = np.random.randint(0, 256, (IMAGE_DIM, IMAGE_DIM), dtype=np.uint8)
    y_img = np.random.randint(0, 256, (IMAGE_DIM, IMAGE_DIM), dtype=np.uint8)

    # 2. Calculate mu_x, mu_y (Gaussian mean of inputs)
    mu_x = apply_gauss_rtl_behavior(x_img).astype(np.int64)
    mu_y = apply_gauss_rtl_behavior(y_img).astype(np.int64)
    mu_x_mu_y = (mu_x * mu_y)

    # 3. Calculate E[XY] (Gaussian mean of products)
    xy_product = x_img.astype(np.uint16) * y_img.astype(np.uint16)
    e_xy = apply_gauss_rtl_behavior(xy_product).astype(np.int64)

    # 4. Final Difference: Sigma_XY = E[XY] - mu_x*mu_y
    # Cast to uint16 at the very end to mimic 16-bit hardware wrap-around
    sig_xy_final = (e_xy - mu_x_mu_y).astype(np.uint16)

    # 5. Write Hex files
    s_beats_x = write_axi_stream_hex(args.input_x, x_img, S_DATA_WIDTH)
    s_beats_y = write_axi_stream_hex(args.input_y, y_img, S_DATA_WIDTH)
    m_beats   = write_axi_stream_hex(args.output, sig_xy_final, M_DATA_WIDTH)

    # 6. Generate Configuration
    output_dir = os.path.dirname(args.output)
    config_file = os.path.join(output_dir, "tb_config.svh")
    with open(config_file, 'w') as f:
        f.write(f"`define S_AXIS_DATA_WIDTH  {S_DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS {s_beats_x}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH  {M_DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS {m_beats}\n")

    print(f"[PYTHON] Done. Expected data starts at Beat {64 if IMAGE_DIM==512 else 'check IMAGE_DIM'}")

if __name__ == "__main__":
    main()