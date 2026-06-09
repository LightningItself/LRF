import argparse
import random

def main():
    parser = argparse.ArgumentParser(description="Functional Parameterized Golden Data Generator for LSU")
    parser.add_argument("--input", required=True, help="Path to save inputs.hex")
    parser.add_argument("--output", required=True, help="Path to save outputs.hex")
    args = parser.parse_args()

    S_AXIS_DATA_WIDTH = 128
    S_AXIS_TOTAL_BEATS = 16384
    
    WRITE_DELAY = 0
    RW_SHIFT = 0

    inputs = [random.randint(0, (1 << S_AXIS_DATA_WIDTH) - 1) for _ in range(S_AXIS_TOTAL_BEATS)]
    
    outputs = [0] * S_AXIS_TOTAL_BEATS
    for j in range(S_AXIS_TOTAL_BEATS):
        target_input_idx = j + RW_SHIFT
        
        if target_input_idx < S_AXIS_TOTAL_BEATS:
            outputs[j] = inputs[target_input_idx]
        else:
            outputs[j] = inputs[target_input_idx % S_AXIS_TOTAL_BEATS]

    for j in range(RW_SHIFT):
        outputs[j] = 0

    hex_width = S_AXIS_DATA_WIDTH // 4 
    
    with open(args.input, "w") as f_in:
        for val in inputs:
            f_in.write(f"{val:0{hex_width}x}\n")
            
    with open(args.output, "w") as f_out:
        for val in outputs:
            f_out.write(f"{val:0{hex_width}x}\n")

    print(f"[SUCCESS] Generated parameterized golden data (WRITE_DELAY={WRITE_DELAY}, RW_SHIFT={RW_SHIFT}).")

if __name__ == "__main__":
    main()