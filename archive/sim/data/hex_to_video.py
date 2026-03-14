import os
import cv2
import numpy as np
import argparse

# Argument parser
parser = argparse.ArgumentParser(description="Convert hex images to video.")
parser.add_argument('--hex_dir', required=True, help='Directory containing .hex image files')
parser.add_argument('--width', type=int, required=True, help='Width of the image')
parser.add_argument('--height', type=int, required=True, help='Height of the image')
parser.add_argument('--is_color', action='store_true', help='Set this flag if the image is RGB (default is grayscale)')
parser.add_argument('--fps', type=int, default=30, help='Frames per second for the output video')
parser.add_argument('--output', default='output_video.avi', help='Output video filename')
args = parser.parse_args()

# Extract config
hex_dir = args.hex_dir
frame_width = args.width
frame_height = args.height
is_color = args.is_color
fps = args.fps
output_video = args.output

# Compute bytes per frame
channels = 3 if is_color else 1
bytes_per_frame = frame_width * frame_height * channels

# Collect .hex files
hex_files = sorted([f for f in os.listdir(hex_dir) if f.endswith('.hex')])

# Setup VideoWriter
fourcc = cv2.VideoWriter_fourcc(*'XVID')
video_writer = cv2.VideoWriter(output_video, fourcc, fps, (frame_width, frame_height), isColor=True)

for filename in hex_files:
    file_path = os.path.join(hex_dir, filename)
    with open(file_path, 'r') as file:
        hex_data = file.read().replace('\n', '').replace(' ', '')

    byte_data = bytes.fromhex(hex_data)

    if len(byte_data) != bytes_per_frame:
        print(f"Skipping {filename}: Unexpected byte size ({len(byte_data)} bytes)")
        continue

    frame = np.frombuffer(byte_data, dtype=np.uint8)

    if is_color:
        frame = frame.reshape((frame_height, frame_width, 3))
    else:
        frame = frame.reshape((frame_height, frame_width))
        frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR)  # Convert grayscale to BGR

    video_writer.write(frame)

video_writer.release()
print(f"Video saved as: {output_video}")