import os
import numpy as np
import matplotlib.pyplot as plt

def read_hex_image(file_path, width=520, height=520):
    with open(file_path, 'r') as file:
        hex_data = file.read().split()

    if len(hex_data) == 1 and len(hex_data[0]) == width * height * 2:
        hex_data = [hex_data[0][i:i+2] for i in range(0, len(hex_data[0]), 2)]

    if len(hex_data) != width * height:
        raise ValueError(f"Unexpected number of pixels in {file_path}: expected {width*height}, got {len(hex_data)}")

    # Convert hex values to integers
    pixel_values = np.array([int(val, 16) for val in hex_data], dtype=np.float32)
    image = pixel_values.reshape((height, width))
    return image

def load_hex_images(folder_path, n, width=520, height=520):
    images = []
    files = sorted([f for f in os.listdir(folder_path) if f.endswith('.hex')])[:n]
    
    for filename in files:
        file_path = os.path.join(folder_path, filename)
        try:
            image = read_hex_image(file_path, width, height)
            images.append(image)
        except Exception as e:
            print(f"Error reading {filename}: {e}")
    
    return images

def average_images(image_list):
    if not image_list:
        raise ValueError("The image list is empty.")
    # Stack and compute the mean across the stack
    stacked = np.stack(image_list, axis=0)  # Shape: (N, H, W)
    average = np.mean(stacked, axis=0)

    # Convert to uint8 (rounded and clipped)
    average_uint8 = np.clip(np.round(average), 0, 255)
    return average_uint8
import numpy as np
from scipy.ndimage import convolve

import numpy as np

def sobel_filter(image: np.ndarray) -> np.ndarray:
    """Applies 3x3 Sobel filter to a grayscale image and returns gradient magnitude."""
    sobel_x = np.array([[-1, 0, 1],
                        [-2, 0, 2],
                        [-1, 0, 1]], dtype=np.float64)
    sobel_y = np.array([[-1, -2, -1],
                        [ 0,  0,  0],
                        [ 1,  2,  1]], dtype=np.float64)

    gx = convolve2d(image, sobel_x)
    gy = convolve2d(image, sobel_y)

    return np.sqrt(gx**2 + gy**2)

def gaussian_kernel_3x3():
    """Returns a 3x3 Gaussian kernel with sigma ≈ 1."""
    kernel = np.array([[1, 2, 1],
                       [2, 4, 2],
                       [1, 2, 1]], dtype=np.float64)
    return kernel / np.sum(kernel)

def convolve2d(image: np.ndarray, kernel: np.ndarray) -> np.ndarray:
    """Performs 2D convolution with zero-padding, kernel must be 3x3."""
    h, w = image.shape
    output = np.zeros((h, w), dtype=np.float64)
    padded = np.pad(image, pad_width=1, mode='reflect')

    for i in range(h):
        for j in range(w):
            region = padded[i:i+3, j:j+3]
            output[i, j] = np.sum(region * kernel)
    
    return output

def calculate_ssim_with_sobel_local(image1: np.ndarray, image2: np.ndarray) -> float:
    """Computes SSIM after applying Sobel filter and local Gaussian averaging (pure NumPy)."""
    if image1.shape != (520, 520) or image2.shape != (520, 520):
        raise ValueError("Images must be grayscale and of size 520x520.")

    # Convert to float64
    img1 = image1.astype(np.float64)
    img2 = image2.astype(np.float64)

    # Step 1: Apply Sobel filter
    img1 = sobel_filter(img1)
    img2 = sobel_filter(img2)

    # Constants
    L = 255.0  # Set to 1.0 if using normalized [0,1] images
    K1, K2 = 0.01, 0.03
    C1 = (K1 * L) ** 2
    C2 = (K2 * L) ** 2

    # Step 2: Local statistics using 3x3 Gaussian filter
    kernel = gaussian_kernel_3x3()

    mu1 = convolve2d(img1, kernel)
    mu2 = convolve2d(img2, kernel)

    mu1_sq = mu1 ** 2
    mu2_sq = mu2 ** 2
    mu1_mu2 = mu1 * mu2

    sigma1_sq = convolve2d(img1**2, kernel) - mu1_sq
    sigma2_sq = convolve2d(img2**2, kernel) - mu2_sq
    sigma12 = convolve2d(img1 * img2, kernel) - mu1_mu2

    # Step 3: Compute SSIM map
    numerator = (2 * mu1_mu2 + C1) * (2 * sigma12 + C2)
    denominator = (mu1_sq + mu2_sq + C1) * (sigma1_sq + sigma2_sq + C2)
    ssim_map = numerator / denominator

    # Step 4: Average over all pixels
    return ssim_map

def compare_ssim_maps_with_blur(ssim_a: np.ndarray, ssim_b: np.ndarray) -> np.ndarray:
    """
    Compares two SSIM maps pixel-wise and returns a blurred binary image:
    - 255 where SSIM_A > SSIM_B
    -   0 where SSIM_A < SSIM_B
    - 127 where equal (optional)
    Then applies a 3x3 Gaussian blur.

    Parameters:
        ssim_a (np.ndarray): First SSIM map
        ssim_b (np.ndarray): Second SSIM map

    Returns:
        np.ndarray: Blurred comparison image (float64 or uint8)
    """
    if ssim_a.shape != ssim_b.shape:
        raise ValueError("SSIM maps must have the same shape.")

    # Step 1: Binary comparison
    binary = np.zeros_like(ssim_a, dtype=np.uint8)
    binary[ssim_a > ssim_b] = 255
    binary[ssim_a < ssim_b] = 0
    binary[ssim_a == ssim_b] = 127  # Optional tie case

    # Step 2: Apply 3x3 Gaussian blur
    kernel = gaussian_kernel_3x3()
    blurred = convolve2d(binary.astype(np.float64), kernel)

    return blurred

def merge_images_by_ssim(image_a: np.ndarray, image_b: np.ndarray, ssim_blurred: np.ndarray) -> np.ndarray:
    """
    Merges two images based on a blurred SSIM comparison map.
    
    Parameters:
        image_a (np.ndarray): Grayscale image A, shape (H, W)
        image_b (np.ndarray): Grayscale image B, shape (H, W)
        ssim_blurred (np.ndarray): Blurred SSIM comparison map, shape (H, W), values in [0, 255]

    Returns:
        np.ndarray: Interpolated merged image, float64, same shape as input
    """
    if image_a.shape != image_b.shape or image_a.shape != ssim_blurred.shape:
        raise ValueError("All inputs must have the same shape.")

    # Normalize blurred SSIM map to [0, 1] for interpolation weights
    alpha = ssim_blurred.astype(np.float64) / 255.0

    # Ensure images are float for interpolation
    img_a = image_a.astype(np.float64)
    img_b = image_b.astype(np.float64)

    # Interpolate: output = (1 - alpha) * A + alpha * B
    merged = (1 - alpha) * img_a + alpha * img_b

    return merged

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

def fuse(image1, image2, image_ref):
    hssim_old = calculate_ssim_with_sobel_local(image1, image_ref)
    hssim_new = calculate_ssim_with_sobel_local(image2, image_ref)

    comp = compare_ssim_maps_with_blur(hssim_old, hssim_new)
    return merge_images_by_ssim(image2, image1, comp)   

def fuse_sequence(images, window_size=5):
    N = len(images)
    outputs = []

    for start in range(N - window_size + 1):
        # Get the current window of images
        window = images[start:start + window_size]

        # Calculate the average of the current window to use as the reference image
        ref = np.mean(window, axis=0).astype(np.uint8)  # Average image

        # Start the fusion process using the first image in the window
        fused = window[0]
        
        for i in range(1, window_size):
            fused = fuse(fused, window[i], ref)  # Fuse with each image in the window

        outputs.append(fused)
    return outputs

# Example usage
if __name__ == "__main__":
    folder = "C:/Users/Indrayudh/Research/LRF/sim/door_hex16"
    num_images = 30
    images = load_hex_images(folder, num_images)

    # hssim_old = hssim_map(images[0], avg_img)
    
    # hssim_new = hssim_map(images[1], avg_img)
    output = fuse_sequence(images)

    display_image(output)
