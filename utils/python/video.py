from axis_hex import write_axi_stream_hex
import glob
import numpy as np
from PIL import Image

INPUT_DIM = 520
OUTPUT_DIM = 512

def parse_video(input_folder):
    image_files = sorted(glob.glob(f"{input_folder}/*.png"))

    for i, file in enumerate(image_files):
        image = np.array(Image.open(file))

        # Crop from center (removes 4 pixels from each side)
        start = (INPUT_DIM - OUTPUT_DIM) // 2
        cropped = image[start:start+OUTPUT_DIM, start:start+OUTPUT_DIM]

        write_axi_stream_hex(
            f"../../data/hex_data/hex_img_{i:03d}",
            cropped,
            128
        )

parse_video("../../data/png_data")