# import cv2
# import os

# # image_folder = "C:/Users/Indrayudh/Downloads/LRF-20231103T121935Z-001/LRF/Abhishek/OTIS_PNG_Gray/Fixed Backgrounds/Door"  # Change this
# image_folder = "/home/rahul/Documents/LRF/sim/data/OTIS_PNG_Gray/Fixed Backgrounds/Door/"  # Change this

# output_video = '/home/rahul/Documents/LRF/sim/runs/input_orig/door_input.avi'
# fps = 10
# frame_size = (64, 64)

# # Get sorted list of .png files
# image_files = sorted([
#     f for f in os.listdir(image_folder)
#     if f.lower().endswith('.png')
# ])

# # Define the video writer (3-channel color output)
# fourcc = cv2.VideoWriter_fourcc(*'XVID')
# video_writer = cv2.VideoWriter(output_video, fourcc, fps, frame_size)

# for filename in image_files:
#     img_path = os.path.join(image_folder, filename)
#     gray = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)

#     if gray is None:
#         print(f"Skipping unreadable image: {filename}")
#         continue

#     # Resize if necessary
#     if gray.shape != frame_size:
#         gray = cv2.resize(gray, frame_size)

#     # Convert grayscale to BGR (3-channel)
#     bgr = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
#     video_writer.write(bgr)

# video_writer.release()
# print(f"✅ Video written to: {output_video}")


import cv2
import os

def create_video_from_images(image_folder, output_video_path, fps=10):
    # Get sorted list of .png files
    image_files = sorted([
        f for f in os.listdir(image_folder)
        if f.lower().endswith('.png')
    ])

    if not image_files:
        print(f"⚠️ No PNG images found in: {image_folder}")
        return

    # Read first image to get frame size
    first_img_path = os.path.join(image_folder, image_files[0])
    first_img = cv2.imread(first_img_path, cv2.IMREAD_GRAYSCALE)
    if first_img is None:
        print(f"⚠️ Cannot read first image: {first_img_path}")
        return

    frame_size = (first_img.shape[1], first_img.shape[0])  # (width, height)

    fourcc = cv2.VideoWriter_fourcc(*'XVID')
    video_writer = cv2.VideoWriter(output_video_path, fourcc, fps, frame_size)

    for filename in image_files:
        img_path = os.path.join(image_folder, filename)
        gray = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)

        if gray is None:
            print(f"Skipping unreadable image: {filename}")
            continue

        # Resize if necessary
        if (gray.shape[1], gray.shape[0]) != frame_size:
            gray = cv2.resize(gray, frame_size)

        # Convert grayscale to BGR (3-channel)
        bgr = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
        video_writer.write(bgr)

    video_writer.release()
    print(f"✅ Video written to: {output_video_path}")

# === GENERALIZED USAGE ===
input_base_dir = "/home/rahul/Documents/LRF/sim/data/OTIS_PNG_Gray/Fixed Patterns/"
output_base_dir = "/home/rahul/Documents/LRF/sim/runs/input_orig/"
fps = 10

os.makedirs(output_base_dir, exist_ok=True)

for dataset in os.listdir(input_base_dir):
    dataset_path = os.path.join(input_base_dir, dataset)
    if not os.path.isdir(dataset_path):
        continue

    output_video = os.path.join(output_base_dir, f"{dataset}_input.avi")
    create_video_from_images(dataset_path, output_video, fps)
