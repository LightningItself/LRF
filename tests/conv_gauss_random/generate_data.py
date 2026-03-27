# This script generates image-based test data and expected outputs
# for AXI-stream simulation of a convolution (Gaussian-like) module.
#
# Steps:
# 1. Parses command-line arguments for input and output HEX file paths.
# 2. Generates a random grayscale image (512x512, 8-bit pixels).
#
# 3. Pads the image with zeros (2 rows/columns) to handle boundary conditions.
# 4. Converts image to 16-bit for intermediate computation (to prevent overflow).
#
# 5. Applies a 3x3 weighted convolution (Gaussian-like filter):
#       [1 2 1
#        2 4 2   ] / 16
#       [1 2 1]
#    - Uses bit shifts for efficient multiplication.
#    - Final result is normalized by shifting right by 4.
#
# 6. Stores the filtered result into expected_output:
#    - Output is aligned with a 2-pixel offset (due to padding and pipeline behavior).
#
# 7. Converts both input image and expected output into AXI-stream HEX format:
#    - Packs pixels into beats based on DATA_WIDTH.
#    - Writes them into input and output HEX files.
#
# 8. Generates a configuration file (tb_config.svh) containing:
#    - AXI data widths
#    - Total number of beats for input and output
#
# Purpose:
# Automates creation of image stimulus and expected results for verifying
# a Gaussian convolution hardware design using AXI-stream interface.

import argparse
import os
import sys
import numpy as np

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
    p = padded_img.astype(np.uint16)

    out_data = (
        (p[0:-2, 0:-2]     ) + (p[0:-2, 1:-1] << 1) + (p[0:-2, 2:]     ) +
        (p[1:-1, 0:-2] << 1) + (p[1:-1, 1:-1] << 2) + (p[1:-1, 2:] << 1) +
        (p[2:,   0:-2]     ) + (p[2:,   1:-1] << 1) + (p[2:,   2:]     )
    ) >> 4

    expected_output = np.zeros((IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    expected_output[2:, 2:] = out_data[0:-2, 0:-2].astype(np.uint8)

    s_beats = write_axi_stream_hex(args.input, input_image, DATA_WIDTH)
    m_beats = write_axi_stream_hex(args.output, expected_output, DATA_WIDTH)

    output_dir = os.path.dirname(args.output)
    config_file = os.path.join(output_dir, "tb_config.svh")
    
    with open(config_file, 'w') as f:
        f.write(f"`define S_AXIS_DATA_WIDTH  {DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS {s_beats}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH  {DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS {m_beats}\n")

if __name__ == "__main__":
    main()