import numpy as np
import os

# Parameters
original_size = (520, 520)  # (height, width)
# crop_size = (512, 512)
crop_size = (64, 64)

start_y = (original_size[0] - crop_size[0]) // 2
start_x = (original_size[1] - crop_size[1]) // 2

input_folder = '/home/rahul/Documents/LRF/sim/data/raw_images'     # Path where raw files are stored
output_folder = '/home/rahul/Documents/LRF/sim/data/cropped_raw/'  # Folder to save cropped files

os.makedirs(output_folder, exist_ok=True)

for i in range(1, 301):
    filename = f'Door_{i:03d}.raw'
    input_path = os.path.join(input_folder, filename)
    
    if not os.path.exists(input_path):
        print(f"Warning: {filename} not found, skipping.")
        continue

    # Read the raw image
    with open(input_path, 'rb') as f:
        img = np.fromfile(f, dtype=np.uint8).reshape(original_size)
    
    # Crop the center 512x512
    cropped = img[start_y:start_y + crop_size[0], start_x:start_x + crop_size[1]]
    
    # Write cropped raw image
    output_path = os.path.join(output_folder, filename)
    with open(output_path, 'wb') as f:
        cropped.tofile(f)
    
    print(f"Processed: {filename}")

print("Batch cropping complete. Cropped files saved to:", output_folder)