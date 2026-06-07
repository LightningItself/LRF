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

SIG_XY_BITS = 2 * PIXEL_SIZE + 1
SIG_XY_MASK = (1 << SIG_XY_BITS) - 1

STREAM_COMPONENT_WIDTH = PROD_BITS * PIXELS_PER_BEAT
PACKED_AXIS_DATA_WIDTH = (2 * STREAM_COMPONENT_WIDTH) + PIXELS_PER_BEAT

def compute_sigma_xy(image_x, image_y):
    xy_prod   = image_x.astype(np.uint32) * image_y.astype(np.uint32)
    gauss_xy  = compute_gauss(xy_prod, dtype=np.uint32)
    mu_x      = compute_gauss(image_x, dtype=np.uint8)
    mu_y      = compute_gauss(image_y, dtype=np.uint8)
    mu_x_mu_y = mu_x.astype(np.uint32) * mu_y.astype(np.uint32)
    sigma_xy  = gauss_xy.astype(np.int64) - mu_x_mu_y.astype(np.int64)
    sigma_xy_17 = sigma_xy & SIG_XY_MASK
    sigma_xy_signed = np.where(sigma_xy_17 >= (1 << (SIG_XY_BITS - 1)),
                                sigma_xy_17 - (1 << SIG_XY_BITS),
                                sigma_xy_17).astype(np.int32)
    return sigma_xy_signed

def compute_sigma_sq(image):
    x_sq     = image.astype(np.uint32) ** 2
    gauss_x2 = compute_gauss(x_sq, dtype=np.uint32)
    mu       = compute_gauss(image, dtype=np.uint8)
    mu_sq    = mu.astype(np.uint32) ** 2
    sigma_sq = gauss_x2.astype(np.int64) - mu_sq.astype(np.int64)
    return (sigma_sq & ((1 << (2 * PIXEL_SIZE)) - 1)).astype(np.uint32)

def write_wide_hex(filename, packed_list, total_bits):
    hex_chars = total_bits // 4
    with open(filename, 'w') as f:
        for val in packed_list:
            f.write(f"{val:0{hex_chars}X}\n")
    return len(packed_list)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out_dir", required=True)
    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)

    input_x_path       = os.path.join(args.out_dir, "inputs_x.hex")
    input_y_path       = os.path.join(args.out_dir, "inputs_y.hex")
    output_packed_path = os.path.join(args.out_dir, "outputs_packed.hex")

    total_pixels = IMAGE_HEIGHT * IMAGE_WIDTH
    total_beats = total_pixels // PIXELS_PER_BEAT

    beats_x = np.random.randint(0, 256, size=(total_beats, PIXELS_PER_BEAT), dtype=np.uint8)
    beats_y = np.random.randint(0, 256, size=(total_beats, PIXELS_PER_BEAT), dtype=np.uint8)
    image_x = beats_x.reshape((IMAGE_HEIGHT, IMAGE_WIDTH))
    image_y = beats_y.reshape((IMAGE_HEIGHT, IMAGE_WIDTH))

    mu_x   = compute_gauss(image_x, dtype=np.uint8)
    mu_y   = compute_gauss(image_y, dtype=np.uint8)
    mu_x_u = mu_x.astype(np.uint32)
    mu_y_u = mu_y.astype(np.uint32)

    muX_sq   = (mu_x_u * mu_x_u) & ((1 << (2 * PIXEL_SIZE)) - 1)
    muY_sq   = (mu_y_u * mu_y_u) & ((1 << (2 * PIXEL_SIZE)) - 1)
    int_muXY = (mu_x_u * mu_y_u) & ((1 << (2 * PIXEL_SIZE)) - 1)

    muX_sq_plus_muY_sq = (muX_sq + muY_sq) & ((1 << (2 * PIXEL_SIZE + 1)) - 1)

    two_muXY    = (int_muXY << 1) & ((1 << (2 * PIXEL_SIZE + 1)) - 1)
    numr_part_1 = (two_muXY + C1)            & PART_MASK
    denr_part_1 = (muX_sq_plus_muY_sq + C1) & PART_MASK

    sigma_xy   = compute_sigma_xy(image_x, image_y)
    sigma_sq_x = compute_sigma_sq(image_x)
    sigma_sq_y = compute_sigma_sq(image_y)

    raw_sum = sigma_xy.astype(np.int64) * 2 + C2

    numr_sign_flat = (raw_sum.flatten() < 0).astype(np.uint16).reshape(-1, PIXELS_PER_BEAT)

    abs_raw_sum = np.abs(raw_sum).astype(np.int64) & PART_MASK
    denr_part_2 = (sigma_sq_x.astype(np.int64) + sigma_sq_y.astype(np.int64) + C2) & PART_MASK

    numr_2d = ((numr_part_1.astype(object) * abs_raw_sum.astype(object)) & PROD_MASK).reshape(-1, PIXELS_PER_BEAT)
    denr_2d = ((denr_part_1.astype(object) * denr_part_2.astype(object)) & PROD_MASK).reshape(-1, PIXELS_PER_BEAT)

    num_beats = numr_2d.shape[0]
    packed_list = []

    for b in range(num_beats):
        denr_x_val = 0
        for i, v in enumerate(denr_2d[b]):
            denr_x_val |= int(v) << (i * PROD_BITS)

        numr_x_val = 0
        for i, v in enumerate(numr_2d[b]):
            numr_x_val |= int(v) << (i * PROD_BITS)

        sign_val = 0
        for bit in range(PIXELS_PER_BEAT):
            sign_val |= int(numr_sign_flat[b, bit]) << bit

        packed_beat = (sign_val << (2 * STREAM_COMPONENT_WIDTH)) | (numr_x_val << STREAM_COMPONENT_WIDTH) | denr_x_val
        packed_list.append(packed_beat)

    s_beats_x = write_axi_stream_hex(input_x_path, image_x, DATA_WIDTH)
    s_beats_y = write_axi_stream_hex(input_y_path, image_y, DATA_WIDTH)
    m_beats_p = write_wide_hex(output_packed_path, packed_list, PACKED_AXIS_DATA_WIDTH)

    if s_beats_x != s_beats_y:
        raise ValueError(f"Input beat count mismatch: x={s_beats_x}, y={s_beats_y}")

    config_path = os.path.join(args.out_dir, "tb_config.svh")
    with open(config_path, 'w') as f:
        f.write("`define NUM_S_AXIS 2\n")
        f.write("`define NUM_M_AXIS 1\n")
        f.write(f"`define S_AXIS_DATA_WIDTH      {DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH      {PACKED_AXIS_DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS     {s_beats_x}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS     {m_beats_p}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_0   {s_beats_x}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_1   {s_beats_y}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS_0   {m_beats_p}\n")

    print(f"Success. Files generated in {args.out_dir}")

if __name__ == "__main__":
    main()