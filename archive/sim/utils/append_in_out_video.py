import cv2
import os

def create_side_by_side_video(input_video_path, output_video_path, combined_video_path):
    cap_input = cv2.VideoCapture(input_video_path)
    cap_output = cv2.VideoCapture(output_video_path)

    if not cap_input.isOpened() or not cap_output.isOpened():
        print(f"❌ Cannot open: {input_video_path} or {output_video_path}")
        return

    fps = cap_input.get(cv2.CAP_PROP_FPS)
    input_width = int(cap_input.get(cv2.CAP_PROP_FRAME_WIDTH))
    input_height = int(cap_input.get(cv2.CAP_PROP_FRAME_HEIGHT))

    output_width = int(cap_output.get(cv2.CAP_PROP_FRAME_WIDTH))
    output_height = int(cap_output.get(cv2.CAP_PROP_FRAME_HEIGHT))

    target_width = max(input_width, output_width)
    target_height = max(input_height, output_height)

    frame_size = (target_width * 2, target_height)

    fourcc = cv2.VideoWriter_fourcc(*'XVID')
    writer = cv2.VideoWriter(combined_video_path, fourcc, fps, frame_size)

    frames_written = 0

    while True:
        ret_input, frame_input = cap_input.read()
        ret_output, frame_output = cap_output.read()

        if not ret_input or not ret_output:
            break

        frame_input = cv2.resize(frame_input, (target_width, target_height))
        frame_output = cv2.resize(frame_output, (target_width, target_height))

        combined = cv2.hconcat([frame_input, frame_output])
        writer.write(combined)
        frames_written += 1

    cap_input.release()
    cap_output.release()
    writer.release()

    if frames_written == 0:
        print(f"⚠️ No frames written for: {combined_video_path}")
    else:
        print(f"✅ Combined video written to: {combined_video_path} with {frames_written} frames")

# === CONFIG ===
input_video_dir = "/home/rahul/Documents/LRF/sim/runs/input_orig/"
output_video_dir = "/home/rahul/Documents/LRF/sim/runs/output_orig/"
combined_video_dir = "/home/rahul/Documents/LRF/sim/runs/combined/"
os.makedirs(combined_video_dir, exist_ok=True)

input_videos = [f for f in os.listdir(input_video_dir) if f.lower().endswith('.avi')]
output_videos = [f for f in os.listdir(output_video_dir) if f.lower().endswith('.avi')]

# === Matching logic with debug ===
matched = 0
for input_vid in input_videos:
    in_base = os.path.splitext(input_vid)[0].lower()
    matching_outputs = [f for f in output_videos if in_base in f.lower()]

    if not matching_outputs:
        print(f"⚠️ No matching output video found for: {input_vid}")
        continue

    output_vid = matching_outputs[0]
    in_path = os.path.join(input_video_dir, input_vid)
    out_path = os.path.join(output_video_dir, output_vid)
    combined_path = os.path.join(combined_video_dir, f"combined_{input_vid}")

    print(f"➡️ Combining: {input_vid} + {output_vid}")
    create_side_by_side_video(in_path, out_path, combined_path)
    matched += 1

if matched == 0:
    print("❗ No video pairs matched. Check file names.")