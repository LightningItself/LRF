

import socket
import os
import time

# Define server IP and port
ip_address = "192.168.1.10"
port_number = 5001

# Define folder 
image_folder = "raw_images"
       
# Define folder to store processed images
processed_images = "processed_images"
os.makedirs(processed_images, exist_ok=True)  # Create if not exists


# Get list of images
image_files = [f for f in os.listdir(image_folder) if f.endswith(".raw")]
image_files.sort()
total_images = len(image_files)
batch_size = 16

print(f"Found {total_images} images to send.")

# Create socket connection
print(f"\nConnecting to {ip_address}:{port_number}...")
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(30)  # Timeout for error handling
s.connect((ip_address, port_number))

# Function to send an image
def send_image(image_path, image_name):
    with open(image_path, 'rb') as f:
        imgData = f.read()

    # Send only image data
    s.sendall(imgData)
    print(f"Sent {image_name} ({len(imgData)} bytes)")

    # Wait for acknowledgment before sending the next image
    ack = s.recv(3).decode().strip()  # Ensure we only get "ACK"

    if ack == "ACK":
        print(f"Server acknowledged receipt of {image_name}")
    else:
        print(f"Unexpected response: {ack}, retrying...")
        
# **Step 1: Send first 16 images for reference**
print("\nSending first 16 images for reference (No output expected).")
for i in range(16):
    send_image(os.path.join(image_folder, image_files[i]), image_files[i])

# **Step 2: Send images in batches of 16**
print("\nNow sending batches of 16 images and expecting 1 processed image after each batch.")
for i in range(16, total_images, batch_size):
    batch = image_files[i: i + batch_size]

    # Send 16 images
    for img_name in batch:
        send_image(os.path.join(image_folder, img_name), img_name)
        
 
    # Wait for 1 processed image
    processed_img_name = f"processed_output_{i // 16}.raw"
    processed_img_path = os.path.join(processed_images, processed_img_name)

    print(f"\nWaiting for processed image {processed_img_name}...")

        # Receive processed image
    try:
        with open(processed_img_path, 'wb') as f:
            total_received = 0
            while total_received < 512*512:  # Ensure full image is received
                recvData = s.recv(8192)
                if not recvData:
                    print("Server closed connection before full image was received!")
                    break  
                f.write(recvData)
                total_received += len(recvData)
                print(f"Received {total_received}/270400 bytes")

        if total_received == 512*512:
            print(f"Received and saved {processed_img_name}")
        else:
            print(f"ERROR: Incomplete image received ({total_received} bytes).")

    except socket.timeout:
        print("Timeout while waiting for processed image.")


s.close()

