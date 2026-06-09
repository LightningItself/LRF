import argparse
import random

def main():
    parser = argparse.ArgumentParser(description="Clean Structural Golden Data Generator for LSU")
    parser.add_argument("--input", required=True, help="Path to save inputs.hex")
    parser.add_argument("--output", required=True, help="Path to save outputs.hex")
    args = parser.parse_args()

    # Hardware Configuration Parameters
    S_AXIS_DATA_WIDTH = 128
    S_AXIS_TOTAL_BEATS = 16384
    MEM_DEPTH = 16384

    inputs = [random.randint(0, (1 << S_AXIS_DATA_WIDTH) - 1) for _ in range(S_AXIS_TOTAL_BEATS)]

    ram = [0] * MEM_DEPTH

    for i in range(S_AXIS_TOTAL_BEATS):
        write_ptr = i % MEM_DEPTH
        ram[write_ptr] = inputs[i]

    outputs = [0] * S_AXIS_TOTAL_BEATS
    for j in range(S_AXIS_TOTAL_BEATS):
        read_ptr = j % MEM_DEPTH
        outputs[j] = ram[read_ptr]

    hex_width = S_AXIS_DATA_WIDTH // 4 
    
    with open(args.input, "w") as f_in:
        for val in inputs:
            f_in.write(f"{val:0{hex_width}x}\n")
            
    with open(args.output, "w") as f_out:
        for val in outputs:
            f_out.write(f"{val:0{hex_width}x}\n")

    print("[SUCCESS] Generated clean golden data with no structural offsets.")

if __name__ == "__main__":
    main()