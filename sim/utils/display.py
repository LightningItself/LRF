import numpy as np
import matplotlib.pyplot as plt

def read_hex_image(filepath, width=512, height=512):
    """
    Reads an 8-bit grayscale image from a .hex file and returns a 2D numpy array.
    
    :param filepath: Path to the .hex file
    :param width: Image width in pixels
    :param height: Image height in pixels
    :return: 2D numpy array of shape (height, width)
    """
    hex_values = []
    
    with open(filepath, 'r') as file:
        for line in file:
            # Clean line and split into tokens
            tokens = line.strip().split()
            for token in tokens:
                # Convert hex string (like '1F') to integer
                if len(token) > 0:
                    hex_values.append(int(token, 16))

    expected_pixels = width * height
    if len(hex_values) != expected_pixels:
        raise ValueError(f"Expected {expected_pixels} pixels, but got {len(hex_values)}.")

    # Convert to 2D numpy array
    image_array = np.array(hex_values, dtype=np.uint8).reshape((height, width))
    return image_array

def display_image(images, titles=None):
    """
    Displays one or more 2D grayscale images using matplotlib.

    :param images: List of 2D numpy arrays (each image)
    :param titles: Optional list of titles for each subplot
    """
    num_images = len(images)
    cols = min(num_images, 3)
    rows = (num_images + cols - 1) // cols

    plt.figure(figsize=(4 * cols, 4 * rows))
    
    for i, image in enumerate(images):
        plt.subplot(rows, cols, i + 1)
        plt.imshow(image, cmap='gray', vmin=0, vmax=255)
        if titles and i < len(titles):
            plt.title(titles[i])
        plt.axis('off')

    plt.tight_layout()
    plt.show()

# -------- Main Execution --------
if __name__ == "__main__":
    # fused_image_path = "../runs/fused_output.hex"
    input_image_path = "../data/cropped_hex/Door_1.hex"
    fused_image_path = "../data/output_hex_data/conv_output_1.hex"
    image_dim = 64
    fused_image = read_hex_image(fused_image_path, image_dim, image_dim)
    input_image = read_hex_image(input_image_path, image_dim, image_dim)

    images = read_hex_image(input_image_path, image_dim, image_dim) 
    display_image([fused_image, input_image], ["fused image", "input_image"])