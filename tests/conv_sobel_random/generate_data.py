import argparse
import os
import sys
import numpy as np

try:
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../utils/python')))
    from axis_hex import write_axi_stream_hex
except ImportError:
    print("Warning: axis_hex utility not found. Ensure path is correct.")

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

    np.random.seed(42)
    input_image = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    
    expected_output = np.zeros((IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)

    def get_rtl_pixel(r, c):
        if r < 0 or r >= IMAGE_HEIGHT: return 0
        # Horizontal wrap-around logic to mimic 'last_top/mid/bot' registers
        if c < 0: return int(input_image[r-1, IMAGE_WIDTH + c]) if r > 0 else 0
        if c >= IMAGE_WIDTH: return 0
        return int(input_image[r, c])

    print("Computing Sobel (RTL Match)...")
    for r in range(IMAGE_HEIGHT):
        for c in range(IMAGE_WIDTH):
            if r < 2 or c == 0:
                expected_output[r, c] = 0
                continue
            
            p00 = get_rtl_pixel(r-2, c-2); p01 = get_rtl_pixel(r-2, c-1); p02 = get_rtl_pixel(r-2, c)
            p10 = get_rtl_pixel(r-1, c-2); p11 = get_rtl_pixel(r-1, c-1); p12 = get_rtl_pixel(r-1, c)
            p20 = get_rtl_pixel(r, c-2);   p21 = get_rtl_pixel(r, c-1);   p22 = get_rtl_pixel(r, c)

            gx = (-p00 + p02 - (p10 << 1) + (p12 << 1) - p20 + p22)
            
            gy = (p00 + (p01 << 1) + p02 - p20 - (p21 << 1) - p22)
            
            mag_sq = (gx**2 + gy**2) >> 1
            mag = int(np.sqrt(mag_sq))
            
            expected_output[r, c] = min(255, mag)

    s_beats = write_axi_stream_hex(args.input, input_image, DATA_WIDTH)
    m_beats = write_axi_stream_hex(args.output, expected_output, DATA_WIDTH)

    output_dir = os.path.dirname(args.output)
    config_file = os.path.join(output_dir, "tb_config.svh")
    
    with open(config_file, 'w') as f:
        f.write(f"`define S_AXIS_DATA_WIDTH   {DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS {s_beats}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH   {DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS {m_beats}\n")

    print(f"Success. Generated {m_beats} beats and config file.")

if __name__ == "__main__":
    main()