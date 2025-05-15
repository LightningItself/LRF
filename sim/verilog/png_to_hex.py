import os
import argparse
import re
from PIL import Image

def png_to_hex(image_path, hex_file_path, d):
    img = Image.open(image_path).convert('L')
    width, height = img.size

    # Resize or pad the image to d x d
    new_img = Image.new('L', (d, d), color=0)  # Create a black canvas of size d x d
    cropped_img = img.crop((0, 0, min(width, d), min(height, d)))
    new_img.paste(cropped_img, (0, 0))  # Paste cropped image into canvas

    pixels = list(new_img.getdata())

    with open(hex_file_path, 'w') as f:
        for pixel in pixels:
            hex_val = format(pixel, '02X')
            f.write(hex_val + '\n')

def sanitize_filename(filename):
    """Remove trailing zeros from numeric suffixes, if present."""
    name, _ = os.path.splitext(filename)
    match = re.search(r'(.*?)(\d+)$', name)
    if match:
        prefix, number = match.groups()
        return f"{prefix}{int(number)}"  # Remove leading zeros from number
    return name

def process_folder(input_folder, output_folder, d):
    os.makedirs(output_folder, exist_ok=True)

    for filename in os.listdir(input_folder):
        if filename.lower().endswith('.png'):
            input_path = os.path.join(input_folder, filename)
            sanitized_name = sanitize_filename(filename)
            output_filename = sanitized_name + '.hex'
            output_path = os.path.join(output_folder, output_filename)
            png_to_hex(input_path, output_path, d)
            print(f"Processed {filename} -> {output_filename} with size {d}x{d}")

def main():
    parser = argparse.ArgumentParser(description="Convert PNG images to .hex files with optional padding.")
    parser.add_argument("input_folder", help="Path to the folder containing PNG images")
    parser.add_argument("output_folder", help="Path to the folder to save HEX files")
    parser.add_argument("d", type=int, help="Target dimension (width = height) of output")

    args = parser.parse_args()
    process_folder(args.input_folder, args.output_folder, args.d)

if __name__ == "__main__":
    main()
