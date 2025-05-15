from display import read_hex_image 
import cv2
import numpy as np

def create_video_from_images(images, output_path="output_video.avi", fps=30):

    if not images:
        raise ValueError("Image list is empty.")

    height, width = images[0].shape

    fourcc = cv2.VideoWriter_fourcc(*'XVID') 
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height), isColor=False)

    for img in images:
        if img.shape != (height, width):
            raise ValueError("All images must have the same dimensions.")
        
        # Ensure the image is 8-bit grayscale
        frame = img.astype(np.uint8)
        out.write(frame)

    out.release()
    print(f"Video saved to {output_path}")


if __name__ == "__main__":
    images = [read_hex_image(f"../door_hex16/Door{i}.hex") for i in range(0, 32)]  # 2 seconds at 30 FPS
    create_video_from_images(images, output_path="input_video.avi", fps=30)
