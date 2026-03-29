import argparse
import os
import sys
import numpy as np

# Adjust path to your utility
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../utils/python')))
from axis_hex import write_axi_stream_hex

IMAGE_WIDTH = 512
IMAGE_HEIGHT = 512
PIXELS_PER_BEAT = 16
PIXEL_SIZE = 8

DATA_WIDTH = PIXELS_PER_BEAT * PIXEL_SIZE

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    input_image = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    
    padded_img = np.pad(input_image, pad_width=((0, 2), (0, 2)), mode='constant', constant_values=0)
    p = padded_img.astype(np.int32)

    gx = (
        -p[0:-2, 0:-2] + p[0:-2, 2:] +
        -(p[1:-1, 0:-2] << 1) + (p[1:-1, 2:] << 1) +
        -p[2:, 0:-2] + p[2:, 2:]
    )

    gy = (
        p[0:-2, 0:-2] + (p[0:-2, 1:-1] << 1) + p[0:-2, 2:] +
        -p[2:, 0:-2] - (p[2:, 1:-1] << 1) - p[2:, 2:]
    )

    mag = np.sqrt(gx**2 + gy**2)
    out_data = np.clip(mag, 0, 255).astype(np.uint8)

    expected_output = np.zeros((IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    expected_output[2:, 2:] = out_data[0:-2, 0:-2]

    s_beats = write_axi_stream_hex(args.input, input_image, DATA_WIDTH)
    m_beats = write_axi_stream_hex(args.output, expected_output, DATA_WIDTH)

    output_dir = os.path.dirname(args.output)
    config_file = os.path.join(output_dir, "tb_config.svh")
    
    with open(config_file, 'w') as f:
        f.write(f"`define S_AXIS_DATA_WIDTH   {DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS {s_beats}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH   {DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS {m_beats}\n")

    print(f"Success: Generated {m_beats} beats for Sobel operator.")

if __name__ == "__main__":
    main()