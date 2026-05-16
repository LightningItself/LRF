import argparse
import os
import sys
import numpy as np

# Importing your specific utilities
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../utils/python')))
from axis_hex import write_axi_stream_hex
from compute_gauss import compute_gauss # Assuming it's in gauss_utils.py or similar

IMAGE_WIDTH = 512
IMAGE_HEIGHT = 512
PIXELS_PER_BEAT = 16
PIXEL_SIZE = 8
DATA_WIDTH = PIXELS_PER_BEAT * PIXEL_SIZE

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_x",  required=True)
    parser.add_argument("--input_y",  required=True)
    parser.add_argument("--output",   required=True)
    args = parser.parse_args()

    # Generate 8-bit random images
    image_x = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    image_y = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)

    # 1. Hardware-level Right Shift
    x_s = (image_x.astype(np.uint16) >> 1).astype(np.uint8)
    y_s = (image_y.astype(np.uint16) >> 1).astype(np.uint8)

    # 2. Path A: E[XY] 
    # Note: xy_prod can be up to 16129 (127*127)
    xy_prod = (x_s.astype(np.uint16) * y_s.astype(np.uint16))
    gauss_xy = compute_gauss(xy_prod, dtype=np.uint16)

    # 3. Path B: E[X] * E[Y]
    mu_x = compute_gauss(x_s, dtype=np.uint8)
    mu_y = compute_gauss(y_s, dtype=np.uint8)
    mu_x_mu_y = (mu_x.astype(np.uint16) * mu_y.astype(np.uint16))

    # 4. Local Covariance Calculation
    # sigma = E[XY] - E[X]E[Y]
    # We use int32 for the subtraction to handle the signed result
    sigma_xy = gauss_xy.astype(np.int32) - mu_x_mu_y.astype(np.int32)
    
    # Cast to int16 for 2's complement, then uint16 for hex writing
    sigma_xy_hex = sigma_xy.astype(np.int16).astype(np.uint16)

    # Output parameters
    OUTPUT_PIXEL_SIZE = 16
    OUTPUT_DATA_WIDTH = PIXELS_PER_BEAT * OUTPUT_PIXEL_SIZE

    # 5. Generate AXI-Stream Hex Files
    s_beats_x = write_axi_stream_hex(args.input_x, image_x, DATA_WIDTH)
    s_beats_y = write_axi_stream_hex(args.input_y, image_y, DATA_WIDTH)
    m_beats = write_axi_stream_hex(args.output,  sigma_xy_hex, OUTPUT_DATA_WIDTH)

    if s_beats_x != s_beats_y:
        raise ValueError(f"SIG_XY input streams must have matching beat counts: x={s_beats_x}, y={s_beats_y}")

    # 6. Generate Testbench Configuration
    output_dir = os.path.dirname(args.output)
    os.makedirs(output_dir, exist_ok=True)
    config_path = os.path.join(output_dir, "tb_config.svh")
    with open(config_path, 'w') as f:
        f.write("`define NUM_S_AXIS 2\n")
        f.write("`define NUM_M_AXIS 1\n")
        f.write(f"`define S_AXIS_DATA_WIDTH  {DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH  {OUTPUT_DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS {s_beats_x}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS {m_beats}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_0 {s_beats_x}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_1 {s_beats_y}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS_0 {m_beats}\n")

    print(f"Success. Files generated in {output_dir}")

if __name__ == "__main__":
    main()
