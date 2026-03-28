import argparse
import os
import sys
import numpy as np

# Utility import
try:
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../utils/python')))
    from axis_hex import write_axi_stream_hex
except ImportError:
    print("Warning: axis_hex utility not found. Ensure path is correct.")

IMAGE_WIDTH = 512
IMAGE_HEIGHT = 512
PIXELS_PER_BEAT = 16
PIXEL_SIZE = 8
DATA_WIDTH = PIXELS_PER_BEAT * PIXEL_SIZE

def main():
    parser = argparse.ArgumentParser(description="Sobel Gold Model & Verification Script")
    parser.add_argument("--input", required=True, help="Path to save input.hex")
    parser.add_argument("--output", required=True, help="Path to save expected_output.hex")
    parser.add_argument("--sim_results", help="Optional: Path to m_axis_tdata.hex from simulation")
    args = parser.parse_args()

    # 1. Generate Input Image (8-bit)
    np.random.seed(42)
    input_image = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    
    # 2. Setup Output (Initialized to 0)
    expected_output = np.zeros((IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)

    # Boundary safe pixel access
    def get_p(row, col):
        if row < 0 or row >= IMAGE_HEIGHT or col < 0 or col >= IMAGE_WIDTH:
            return 0
        return int(input_image[row, col])

    print(f"Generating Expected Output for {IMAGE_WIDTH}x{IMAGE_HEIGHT}...")

    # 3. Process image row by row, beat by beat to mimic RTL
    for r in range(IMAGE_HEIGHT):
        for b in range(0, IMAGE_WIDTH // PIXELS_PER_BEAT):
            b_start = b * PIXELS_PER_BEAT
            
            for i in range(PIXELS_PER_BEAT):
                curr_col = b_start + i
                
                # --- MATCHING RTL RESET LOGIC ---
                # Top two rows are zeroed (matches row_ptr < 2)
                if r < 2:
                    expected_output[r, curr_col] = 0
                    continue
                
                # ONLY the very first pixel of the row (i=0, b=0) is zeroed
                # This matches: conv_sum_x[0] <= (col_ptr == 0) ? 0 : ...
                if b == 0 and i == 0:
                    expected_output[r, curr_col] = 0
                    continue

                # --- SOBEL KERNELS (Gx and Gy) ---
                # For i=1, curr_col-2 is -1. get_p(-1) returns 0.
                gx = (
                    -get_p(r-2, curr_col-2) + get_p(r-2, curr_col) +
                    -2*get_p(r-1, curr_col-2) + 2*get_p(r-1, curr_col) +
                    -get_p(r, curr_col-2) + get_p(r, curr_col)
                )

                gy = (
                    get_p(r-2, curr_col-2) + 2*get_p(r-2, curr_col-1) + get_p(r-2, curr_col) +
                    -get_p(r, curr_col-2) - 2*get_p(r, curr_col-1) - get_p(r, curr_col)
                )

                # --- MAGNITUDE & SATURATION (Pipeline Logic) ---
                # Stage 2: Square
                gx2 = gx**2
                gy2 = gy**2
                
                # Stage 3: Sum and Shift
                sum_sq = (gx2 + gy2) >> 1
                
                # Stage 4: Square Root & Clipping
                mag = int(np.sqrt(sum_sq))
                expected_output[r, curr_col] = min(255, mag)

    # 4. Write HEX Files for Testbench
    s_beats = write_axi_stream_hex(args.input, input_image, DATA_WIDTH)
    m_beats = write_axi_stream_hex(args.output, expected_output, DATA_WIDTH)

    # 5. Config Generation for SV
    output_dir = os.path.dirname(args.output)
    with open(os.path.join(output_dir, "tb_config.svh"), 'w') as f:
        f.write(f"`define S_AXIS_DATA_WIDTH  {DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS {s_beats}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH  {DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS {m_beats}\n")
    
    print(f"Files generated: {args.input}, {args.output}, tb_config.svh")

    # 6. --- VERIFICATION BLOCK ---
    if args.sim_results and os.path.exists(args.sim_results):
        print("\n--- Comparing Simulation Output to Gold Model ---")
        with open(args.sim_results, 'r') as f:
            sim_lines = [line.strip() for line in f if line.strip()]
        
        mismatch_count = 0
        total_sim_beats = len(sim_lines)
        
        for b_idx in range(min(total_sim_beats, m_beats)):
            row = (b_idx * PIXELS_PER_BEAT) // IMAGE_WIDTH
            col_start = (b_idx * PIXELS_PER_BEAT) % IMAGE_WIDTH
            
            # Slice 16 pixels for this beat
            beat_pixels = expected_output[row, col_start : col_start + PIXELS_PER_BEAT]
            
            # Pack into HEX (Reverse because LSB is Pixel 0)
            expected_hex = "".join(f"{p:02x}" for p in reversed(beat_pixels))
            got_hex = sim_lines[b_idx].lower()
            
            if got_hex != expected_hex:
                mismatch_count += 1
                print(f"Mismatch at beat {b_idx}: got {got_hex}, expected {expected_hex}")
            else:
                # Print matches in intervals to show progress without flooding
                if b_idx % 100 == 0:
                    print(f"Match at beat {b_idx}: got {got_hex}, expected {expected_hex}")
        
        if mismatch_count == 0:
            print("\nSUCCESS: 0 mismatches found. Hardware matches Python perfectly.")
        else:
            print(f"\nFAILURE: Found {mismatch_count} mismatching beats.")

if __name__ == "__main__":
    main()