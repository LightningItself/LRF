import argparse
import os
import sys
import numpy as np

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../utils/python')))
from axis_hex import write_axi_stream_hex
from compute_gauss import compute_gauss

IMAGE_WIDTH     = 512
IMAGE_HEIGHT    = 512
PIXELS_PER_BEAT = 16
PIXEL_SIZE      = 8
DATA_WIDTH      = PIXELS_PER_BEAT * PIXEL_SIZE

C1 = 6
C2 = 58

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_old", required=True)
    parser.add_argument("--input_avg", required=True)
    parser.add_argument("--input_new", required=True)
    parser.add_argument("--output",    required=True)
    args = parser.parse_args()

    old_map = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    avg_map = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    new_map = np.random.randint(0, 256, (IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)

    mu_x = compute_gauss(old_map, dtype=np.uint8)
    mu_y = compute_gauss(avg_map, dtype=np.uint8)
    mu_z = compute_gauss(new_map, dtype=np.uint8)

    gauss_old_sq  = compute_gauss(old_map.astype(np.uint16) * old_map.astype(np.uint16), dtype=np.uint16)
    gauss_avg_sq  = compute_gauss(avg_map.astype(np.uint16) * avg_map.astype(np.uint16), dtype=np.uint16)
    gauss_new_sq  = compute_gauss(new_map.astype(np.uint16) * new_map.astype(np.uint16), dtype=np.uint16)
    gauss_old_avg = compute_gauss(old_map.astype(np.uint16) * avg_map.astype(np.uint16), dtype=np.uint16)
    gauss_new_avg = compute_gauss(new_map.astype(np.uint16) * avg_map.astype(np.uint16), dtype=np.uint16)

    mu_x32 = mu_x.astype(np.int32)
    mu_y32 = mu_y.astype(np.int32)
    mu_z32 = mu_z.astype(np.int32)

    sig_sq_x = np.clip(gauss_old_sq.astype(np.int32) - (mu_x32 * mu_x32), -32768, 32767).astype(np.int16)
    sig_sq_y = np.clip(gauss_avg_sq.astype(np.int32) - (mu_y32 * mu_y32), -32768, 32767).astype(np.int16)
    sig_sq_z = np.clip(gauss_new_sq.astype(np.int32) - (mu_z32 * mu_z32), -32768, 32767).astype(np.int16)
    sig_xy   = np.clip(gauss_old_avg.astype(np.int32) - (mu_x32 * mu_y32), -32768, 32767).astype(np.int16)
    sig_zy   = np.clip(gauss_new_avg.astype(np.int32) - (mu_z32 * mu_y32), -32768, 32767).astype(np.int16)

    mu_x_sq   = mu_x32 * mu_x32
    mu_y_sq   = mu_y32 * mu_y32
    mu_z_sq   = mu_z32 * mu_z32
    mu_x_mu_y = mu_x32 * mu_y32
    mu_z_mu_y = mu_z32 * mu_y32

    sig_sq_x64 = sig_sq_x.astype(np.int64)
    sig_sq_y64 = sig_sq_y.astype(np.int64)
    sig_sq_z64 = sig_sq_z.astype(np.int64)
    sig_xy64   = sig_xy.astype(np.int64)
    sig_zy64   = sig_zy.astype(np.int64)

    numr_part1_x = (2 * mu_x_mu_y + C1).astype(np.int64)
    numr_part1_z = (2 * mu_z_mu_y + C1).astype(np.int64)
    denr_part1_x = (mu_x_sq + mu_y_sq + C1).astype(np.int64)
    denr_part1_z = (mu_z_sq + mu_y_sq + C1).astype(np.int64)
 
    numr_part2_x = (2 * sig_xy64 + C2)
    numr_part2_z = (2 * sig_zy64 + C2)
    denr_part2_x = (sig_sq_x64 + sig_sq_y64 + C2)
    denr_part2_z = (sig_sq_z64 + sig_sq_y64 + C2)

    numr_x = numr_part1_x * numr_part2_x
    numr_z = numr_part1_z * numr_part2_z
    denr_x = denr_part1_x * denr_part2_x
    denr_z = denr_part1_z * denr_part2_z

    p1 = numr_x * denr_z
    p2 = numr_z * denr_x

    del_out = np.where(p2 > p1, np.uint8(255), np.uint8(0))

    OUTPUT_DATA_WIDTH = PIXELS_PER_BEAT * PIXEL_SIZE

    s_beats_old = write_axi_stream_hex(args.input_old, old_map, DATA_WIDTH)
    s_beats_avg = write_axi_stream_hex(args.input_avg, avg_map, DATA_WIDTH)
    s_beats_new = write_axi_stream_hex(args.input_new, new_map, DATA_WIDTH)
    m_beats     = write_axi_stream_hex(args.output,    del_out, OUTPUT_DATA_WIDTH)

    if not (s_beats_old == s_beats_avg == s_beats_new):
        raise ValueError(f"Beat count mismatch: old={s_beats_old}, avg={s_beats_avg}, new={s_beats_new}")

    output_dir  = os.path.dirname(args.output)
    os.makedirs(output_dir, exist_ok=True)
    config_path = os.path.join(output_dir, "tb_config.svh")

    with open(config_path, 'w') as f:
        f.write("`define NUM_S_AXIS 3\n")
        f.write("`define NUM_M_AXIS 1\n")
        f.write(f"`define S_AXIS_DATA_WIDTH    {DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH    {OUTPUT_DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS   {s_beats_old}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS   {m_beats}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_0 {s_beats_old}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_1 {s_beats_avg}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_2 {s_beats_new}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS_0 {m_beats}\n")

    print(f"Success. Files generated in {output_dir}")

if __name__ == "__main__":
    main()