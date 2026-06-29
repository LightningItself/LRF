from axis_hex import write_axi_stream_hex
import glob
import numpy as np
from PIL import Image

def parse_video(input_folder, output_folder, file_prefix):
    images = [np.array(Image.open(f)) for f in sorted(glob.glob(f"{input_folder}/*.png"))]
    for i, image in enumerate(images):
        write_axi_stream_hex(f"../../data/hex_data/hex_img_{i:03d}", image[:512, :512], 128)

parse_video("../../data/png_data", "", "")
