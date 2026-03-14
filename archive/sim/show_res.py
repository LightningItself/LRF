import os
import cv2
import numpy as np
from pathlib import Path

# === CONFIGURATION ===
folder1 = "data/hex_data"
folder2 = "data/output_hex_data"
image_width = 64
image_height = 64
fps = 30
output_file = "output_video.avi"

# === Function to load a hex image (1 byte per line) ===
def load_hex_image(file_path, width, height):
    with open(file_path, 'r') as f:
        hex_lines = f.readlines()
    if len(hex_lines) != width * height:
        raise ValueError(f"Unexpected number of lines in {file_path}: expected {width*height}, got {len(hex_lines)}")
    pixels = [int(line.strip(), 16) for line in hex_lines]
    image = np.array(pixels, dtype=np.uint8).reshape((height, width))
    return image

# === Get sorted list of .hex files ===
def get_sorted_hex_files(folder):
    return sorted(Path(folder).glob("*.hex"))

files1 = get_sorted_hex_files(folder1)
files2 = get_sorted_hex_files(folder2)

# Truncate to the minimum number of frames
num_frames = min(len(files1), len(files2))
files1 = files1[:num_frames]
files2 = files2[:num_frames]

# === Setup video writer ===
frame_width = image_width * 2
frame_height = image_height
fourcc = cv2.VideoWriter_fourcc(*'XVID')
video_writer = cv2.VideoWriter(output_file, fourcc, fps, (frame_width, frame_height), isColor=False)

# === Frame generation loop ===
for idx, (f1, f2) in enumerate(zip(files1, files2)):
    img1 = load_hex_image(f1, image_width, image_height) 
    img2 = load_hex_image(f2, image_width, image_height)
    combined = np.hstack((img1, img2))
    video_writer.write(combined)
    print(f"Processed frame {idx+1}/{num_frames}")

video_writer.release()
print(f"Video saved to {output_file}")
