import argparse
import random

def main():
    parser = argparse.ArgumentParser(description="Structural Golden Data Generator for LSU")
    parser.add_argument("--input", required=True, help="Path to save inputs.hex")
    parser.add_argument("--output", required=True, help="Path to save outputs.hex")
    args = parser.parse_args()

    # Hardware Configuration Parameters
    S_AXIS_DATA_WIDTH = 128
    S_AXIS_TOTAL_BEATS = 16384
    MEM_DEPTH = 16384
    
    # Structural Offsets
    WRITE_DELAY = 0
    RW_SHIFT = 0

    # 1. Generate 1 full frame of random input data beats
    inputs = [random.randint(0, (1 << S_AXIS_DATA_WIDTH) - 1) for _ in range(S_AXIS_TOTAL_BEATS)]
    
    # 2. Create an array similar to RAM (Initialized to 0)
    ram = [0] * MEM_DEPTH

    # 3. Use WRITE_DELAY while indexing to populate the RAM array
    for i in range(S_AXIS_TOTAL_BEATS):
        write_ptr = (i - WRITE_DELAY) % MEM_DEPTH
        ram[write_ptr] = inputs[i]

    # 4. Use both WRITE_DELAY and RW_SHIFT when you generate the golden data
    outputs = [0] * S_AXIS_TOTAL_BEATS
    for j in range(S_AXIS_TOTAL_BEATS):
        read_ptr = (j + RW_SHIFT - WRITE_DELAY) % MEM_DEPTH
        outputs[j] = ram[read_ptr]

    # 5. Serialize out to standard zero-padded hex format strings
    hex_width = S_AXIS_DATA_WIDTH // 4 
    
    with open(args.input, "w") as f_in:
        for val in inputs:
            f_in.write(f"{val:0{hex_width}x}\n")
            
    with open(args.output, "w") as f_out:
        for val in outputs:
            f_out.write(f"{val:0{hex_width}x}\n")

    print(f"[SUCCESS] Structurally emulated RAM array mapping using WRITE_DELAY={WRITE_DELAY} and RW_SHIFT={RW_SHIFT}.")

if __name__ == "__main__":
    main()