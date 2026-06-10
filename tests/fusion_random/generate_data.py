import numpy as np
import argparse
import os

PIXELS_PER_BEAT = 16
IMAGE_DIM       = 512
BIT_WIDTH       = 8
TOTAL_PIXELS    = IMAGE_DIM * IMAGE_DIM          # 262144
TOTAL_BEATS     = TOTAL_PIXELS // PIXELS_PER_BEAT  # 16384

def fuse(old_frame, new_frame, del_gauss):
    dbar = (~del_gauss.astype(np.uint8)).astype(np.uint16)
    d    = del_gauss.astype(np.uint16)
    x    = old_frame.astype(np.uint16)
    y    = new_frame.astype(np.uint16)
    result_16 = x * dbar + y * d
    result_8  = (result_16 >> 8).astype(np.uint8)
    return result_8

def write_hex(path, pixels_flat):
    beats = pixels_flat.reshape(TOTAL_BEATS, PIXELS_PER_BEAT)
    with open(path, 'w') as f:
        for beat in beats:
            val = 0
            for k in range(PIXELS_PER_BEAT):
                val |= int(beat[k]) << (k * BIT_WIDTH)
            f.write(f"{val:0{PIXELS_PER_BEAT * BIT_WIDTH // 4}x}\n")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', required=True)
    args = parser.parse_args()

    rng = np.random.default_rng()

    old_frame = rng.integers(0, 256, size=TOTAL_PIXELS, dtype=np.uint8)
    new_frame = rng.integers(0, 256, size=TOTAL_PIXELS, dtype=np.uint8)
    del_gauss = rng.integers(0, 256, size=TOTAL_PIXELS, dtype=np.uint8)

    fused = fuse(old_frame, new_frame, del_gauss)

    write_hex(os.path.join(args.out_dir, 'inputs_old.hex'),   old_frame)
    write_hex(os.path.join(args.out_dir, 'inputs_new.hex'),   new_frame)
    write_hex(os.path.join(args.out_dir, 'inputs_gauss.hex'), del_gauss)
    write_hex(os.path.join(args.out_dir, 'outputs_fused.hex'), fused)

    print(f"Generated {TOTAL_BEATS} beats each for old/new/gauss/fused → {args.out_dir}")

if __name__ == '__main__':
    main()