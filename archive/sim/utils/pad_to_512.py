import os
from PIL import Image

def pad_to_512_gray(image, fill_color=0):
    """
    Pads a grayscale (mode 'L') PIL image to 512x512 with the specified fill color.
    Keeps the image centered.
    """
    desired_size = 512
    old_size = image.size  # (width, height)
    
    # Calculate padding
    delta_w = desired_size - old_size[0]
    delta_h = desired_size - old_size[1]
    padding = (delta_w // 2, delta_h // 2, delta_w - (delta_w // 2), delta_h - (delta_h // 2))
    
    # Apply padding
    new_im = Image.new("L", (desired_size, desired_size), fill_color)
    new_im.paste(image, padding[:2])
    
    return new_im

# Directory setup
# input_dir = "/home/rahul/Documents/LRF/sim/data/OTIS_PNG_Gray/Fixed Patterns/Pattern16"   # CHANGE this to your dataset folder path
# output_dir = "/home/rahul/Documents/LRF/sim/data/OTIS_PNG_PADDED/Fixed_Patterns/Pattern16" # CHANGE this to your desired output folder path

input_dir = "/home/rahul/Documents/LRF/sim/data/OTIS_PNG_Gray/Fixed Patterns/Pattern16/GT"   # CHANGE this to your dataset folder path
output_dir = "/home/rahul/Documents/LRF/sim/data/OTIS_PNG_PADDED/Fixed_Patterns/Pattern16/GT" # CHANGE this to your desired output folder path

os.makedirs(output_dir, exist_ok=True)

# Process all grayscale images in the input directory
for filename in os.listdir(input_dir):
    if filename.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp', '.tiff')):
        img_path = os.path.join(input_dir, filename)
        img = Image.open(img_path).convert("L")  # Convert to grayscale ('L')
        padded_img = pad_to_512_gray(img)
        
        # Save the padded image
        padded_img.save(os.path.join(output_dir, filename))

print("✅ All grayscale images have been padded to 512x512 and saved to:", output_dir)