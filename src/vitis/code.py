import socket
import os
from PIL import Image

IP_ADDRESS = "192.168.1.10"
PORT = 5001

INPUT_DIM = 520
FPGA_DIM = 512
IMAGE_SIZE = FPGA_DIM * FPGA_DIM
FRAMES_PER_FUSION = 16

image_folder = "raw_images"
processed_folder = "processed_images"
os.makedirs(processed_folder, exist_ok=True)

image_files = sorted(
    [f for f in os.listdir(image_folder) if f.endswith(".raw")]
)

print(f"Found {len(image_files)} images")

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(None)
s.connect((IP_ADDRESS, PORT))

print("Connected.")
print("Sending all frames...")

for img in image_files:
    path = os.path.join(image_folder, img)

    with open(path, "rb") as f:
        raw = f.read()

    image = Image.frombytes("L", (INPUT_DIM, INPUT_DIM), raw)
    image = image.crop((4, 4, 516, 516))

    s.sendall(image.tobytes())

    print(f"Sent {img}")

print("All frames sent.")

num_outputs = len(image_files) // FRAMES_PER_FUSION

print(f"Expecting {num_outputs} fused images")

for i in range(num_outputs):

    received = bytearray()

    while len(received) < IMAGE_SIZE:
        data = s.recv(min(8192, IMAGE_SIZE - len(received)))
        if not data:
            raise RuntimeError("Connection closed")
        received.extend(data)

    img = Image.frombytes("L", (FPGA_DIM, FPGA_DIM), bytes(received))

    outfile = os.path.join(
        processed_folder,
        f"fusion_{i:03d}.png"
    )

    img.save(outfile)

    print(f"Received {outfile}")

print("Done.")

s.close()