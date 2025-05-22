import cv2
import os

image_folder = "C:/Users/Indrayudh/Downloads/LRF-20231103T121935Z-001/LRF/Abhishek/OTIS_PNG_Gray/Fixed Backgrounds/Door"  # Change this
output_video = 'output.avi'
fps = 10
frame_size = (520, 520)

# Get sorted list of .png files
image_files = sorted([
    f for f in os.listdir(image_folder)
    if f.lower().endswith('.png')
])

# Define the video writer (3-channel color output)
fourcc = cv2.VideoWriter_fourcc(*'XVID')
video_writer = cv2.VideoWriter(output_video, fourcc, fps, frame_size)

for filename in image_files:
    img_path = os.path.join(image_folder, filename)
    gray = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)

    if gray is None:
        print(f"Skipping unreadable image: {filename}")
        continue

    # Resize if necessary
    if gray.shape != frame_size:
        gray = cv2.resize(gray, frame_size)

    # Convert grayscale to BGR (3-channel)
    bgr = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
    video_writer.write(bgr)

video_writer.release()
print(f"✅ Video written to: {output_video}")
