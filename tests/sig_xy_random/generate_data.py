import argparse
import os
import sys
import numpy as np

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../utils/python')))
from axis_hex import write_axi_stream_hex
from compute_gauss import compute_gauss

IMAGE_WIDTH     = 512
IMAGE_HEIGHT    = 512
PIXELS_PER_BEAT = 16
PIXEL_SIZE      = 8
DATA_WIDTH      = PIXELS_PER_BEAT * PIXEL_SIZE

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_x", required=True)
    parser.add_argument("--input_y", required=True)
    parser.add_argument("--output",  required=True)
    args = parser.parse_args()

    image_x = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    image_y = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8) 

    xy_prod   = image_x.astype(np.uint16) * image_y.astype(np.uint16)
    gauss_xy  = compute_gauss(xy_prod, dtype=np.uint16)

    mu_x      = compute_gauss(image_x, dtype=np.uint8)
    mu_y      = compute_gauss(image_y, dtype=np.uint8)
    mu_x_mu_y = mu_x.astype(np.uint16) * mu_y.astype(np.uint16)

    sigma_xy     = gauss_xy.astype(np.int32) - mu_x_mu_y.astype(np.int32)
    sigma_xy_sat = np.clip(sigma_xy, -32768, 32767)
    sigma_xy_hex = sigma_xy_sat.astype(np.int16).astype(np.uint16)

    OUTPUT_PIXEL_SIZE = 16
    OUTPUT_DATA_WIDTH = PIXELS_PER_BEAT * OUTPUT_PIXEL_SIZE

    s_beats_x = write_axi_stream_hex(args.input_x, image_x,      DATA_WIDTH)
    s_beats_y = write_axi_stream_hex(args.input_y, image_y,      DATA_WIDTH)
    m_beats   = write_axi_stream_hex(args.output,  sigma_xy_hex, OUTPUT_DATA_WIDTH)

    if s_beats_x != s_beats_y:
        raise ValueError(f"Beat count mismatch: x={s_beats_x}, y={s_beats_y}")

    output_dir  = os.path.dirname(args.output)
    os.makedirs(output_dir, exist_ok=True)
    config_path = os.path.join(output_dir, "tb_config.svh")

    with open(config_path, 'w') as f:
        f.write("`define NUM_S_AXIS 2\n")
        f.write("`define NUM_M_AXIS 1\n")
        f.write(f"`define S_AXIS_DATA_WIDTH    {DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH    {OUTPUT_DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS   {s_beats_x}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS   {m_beats}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_0 {s_beats_x}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_1 {s_beats_y}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS_0 {m_beats}\n")

    print(f"Success. Files generated in {output_dir}")

if __name__ == "__main__":
    main()