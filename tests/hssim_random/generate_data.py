import argparse
import os
import sys
import numpy as np

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../utils/python')))
from axis_hex import write_axi_stream_hex
from compute_gauss import compute_gauss

IMAGE_WIDTH      = 512
IMAGE_HEIGHT     = 512
PIXELS_PER_BEAT  = 16
PIXEL_SIZE       = 8
DATA_WIDTH       = PIXELS_PER_BEAT * PIXEL_SIZE

C1 = 6
C2 = 58

PART_BITS  = 2 * PIXEL_SIZE + 2
PROD_BITS  = 2 * PART_BITS
PART_MASK  = (1 << PART_BITS) - 1
PROD_MASK  = (1 << PROD_BITS) - 1

def compute_sigma_xy(image_x, image_y):
    xy_prod   = image_x.astype(np.uint32) * image_y.astype(np.uint32)
    gauss_xy  = compute_gauss(xy_prod, dtype=np.uint32)
    mu_x      = compute_gauss(image_x, dtype=np.uint8)
    mu_y      = compute_gauss(image_y, dtype=np.uint8)
    mu_x_mu_y = mu_x.astype(np.uint32) * mu_y.astype(np.uint32)
    sigma_xy  = gauss_xy.astype(np.int64) - mu_x_mu_y.astype(np.int64)
    return np.clip(sigma_xy, -(1 << (2*PIXEL_SIZE - 1)), (1 << (2*PIXEL_SIZE - 1)) - 1).astype(np.int32)

def compute_sigma_sq(image):
    x_sq     = image.astype(np.uint32) ** 2
    gauss_x2 = compute_gauss(x_sq, dtype=np.uint32)
    mu       = compute_gauss(image, dtype=np.uint8)
    mu_sq    = mu.astype(np.uint32) ** 2
    sigma_sq = gauss_x2.astype(np.int64) - mu_sq.astype(np.int64)
    return np.clip(sigma_sq, 0, (1 << (2 * PIXEL_SIZE)) - 1).astype(np.uint32)

def write_wide_hex(filename, arr_2d, total_bits, pixel_bits):
    hex_chars = total_bits // 4
    with open(filename, 'w') as f:
        for row in arr_2d:
            beat_val = 0
            for i, v in enumerate(row):
                beat_val |= (int(v) << (i * pixel_bits))
            f.write(f"{beat_val:0{hex_chars}X}\n")
    return len(arr_2d)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out_dir", required=True)
    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)

    input_x_path     = os.path.join(args.out_dir, "inputs_x.hex")
    input_y_path     = os.path.join(args.out_dir, "inputs_y.hex")
    output_numr_path = os.path.join(args.out_dir, "outputs_numr.hex")
    output_denr_path = os.path.join(args.out_dir, "outputs_denr.hex")
    output_sign_path = os.path.join(args.out_dir, "outputs_sign.hex")

    image_x = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    image_y = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)

    mu_x   = compute_gauss(image_x, dtype=np.uint8)
    mu_y   = compute_gauss(image_y, dtype=np.uint8)
    mu_x_u = mu_x.astype(np.uint32)
    mu_y_u = mu_y.astype(np.uint32)

    muX_sq   = (mu_x_u * mu_x_u) & ((1 << (2 * PIXEL_SIZE)) - 1)
    muY_sq   = (mu_y_u * mu_y_u) & ((1 << (2 * PIXEL_SIZE)) - 1)
    int_muXY = (mu_x_u * mu_y_u) & ((1 << (2 * PIXEL_SIZE)) - 1)

    muX_sq_plus_muY_sq = (muX_sq + muY_sq) & ((1 << (2 * PIXEL_SIZE + 1)) - 1)

    two_muXY    = (int_muXY << 1) & ((1 << (2 * PIXEL_SIZE + 1)) - 1)
    numr_part_1 = (two_muXY + C1)           & PART_MASK
    denr_part_1 = (muX_sq_plus_muY_sq + C1) & PART_MASK

    sigma_xy   = compute_sigma_xy(image_x, image_y)
    sigma_sq_x = compute_sigma_sq(image_x)
    sigma_sq_y = compute_sigma_sq(image_y)

    raw_sum = sigma_xy.astype(np.int64) * 2 + C2

    numr_sign_flat = (raw_sum.flatten() < 0).astype(np.uint16)
    numr_sign_flat = numr_sign_flat.reshape(-1, PIXELS_PER_BEAT)
    sign_packed    = np.zeros(numr_sign_flat.shape[0], dtype=np.uint16)
    for bit in range(PIXELS_PER_BEAT):
        sign_packed |= (numr_sign_flat[:, bit].astype(np.uint16) << bit)
    sign_packed = sign_packed.reshape(IMAGE_HEIGHT, IMAGE_WIDTH // PIXELS_PER_BEAT)

    abs_raw_sum = np.abs(raw_sum).astype(np.int64) & PART_MASK
    denr_part_2 = (sigma_sq_x.astype(np.int64) + sigma_sq_y.astype(np.int64) + C2) & PART_MASK

    numr_2d = ((numr_part_1.astype(object) * abs_raw_sum.astype(object)) & PROD_MASK).reshape(IMAGE_HEIGHT * IMAGE_WIDTH // PIXELS_PER_BEAT, PIXELS_PER_BEAT)
    denr_2d = ((denr_part_1.astype(object) * denr_part_2.astype(object)) & PROD_MASK).reshape(IMAGE_HEIGHT * IMAGE_WIDTH // PIXELS_PER_BEAT, PIXELS_PER_BEAT)

    NUMR_DENR_DATA_WIDTH = PROD_BITS * PIXELS_PER_BEAT
    SIGN_DATA_WIDTH      = PIXELS_PER_BEAT

    s_beats_x = write_axi_stream_hex(input_x_path,     image_x,     DATA_WIDTH)
    s_beats_y = write_axi_stream_hex(input_y_path,     image_y,     DATA_WIDTH)
    m_beats_n = write_wide_hex(output_numr_path, numr_2d, NUMR_DENR_DATA_WIDTH, PROD_BITS)
    m_beats_d = write_wide_hex(output_denr_path, denr_2d, NUMR_DENR_DATA_WIDTH, PROD_BITS)
    m_beats_s = write_axi_stream_hex(output_sign_path, sign_packed, SIGN_DATA_WIDTH)

    if s_beats_x != s_beats_y:
        raise ValueError(f"Beat count mismatch: x={s_beats_x}, y={s_beats_y}")
    if not (m_beats_n == m_beats_d == m_beats_s):
        raise ValueError(f"Output beat count mismatch: numr={m_beats_n}, denr={m_beats_d}, sign={m_beats_s}")

    config_path = os.path.join(args.out_dir, "tb_config.svh")
    with open(config_path, 'w') as f:
        f.write("`define NUM_S_AXIS 2\n")
        f.write("`define NUM_M_AXIS 3\n")
        f.write(f"`define S_AXIS_DATA_WIDTH      {DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH      {NUMR_DENR_DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS     {s_beats_x}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS     {m_beats_n}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_0   {s_beats_x}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_1   {s_beats_y}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS_0   {m_beats_n}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS_1   {m_beats_d}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS_2   {m_beats_s}\n")
        f.write(f"`define NUMR_DENR_DATA_WIDTH   {NUMR_DENR_DATA_WIDTH}\n")
        f.write(f"`define SIGN_DATA_WIDTH        {SIGN_DATA_WIDTH}\n")

    print(f"Success. Files generated in {args.out_dir}")

if __name__ == "__main__":
    main()