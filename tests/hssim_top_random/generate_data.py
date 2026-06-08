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
PART_MASK  = (1 << PART_BITS) - 1

SIG_XY_BITS = 2 * PIXEL_SIZE + 1
SIG_XY_MASK = (1 << SIG_XY_BITS) - 1

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

def get_hssim_components(image_x, image_y):
    mu_x = compute_gauss(image_x, dtype=np.uint8).astype(np.uint32)
    mu_y = compute_gauss(image_y, dtype=np.uint8).astype(np.uint32)
    
    muX_sq = (mu_x * mu_x) & ((1 << (2 * PIXEL_SIZE)) - 1)
    muY_sq = (mu_y * mu_y) & ((1 << (2 * PIXEL_SIZE)) - 1)
    int_muXY = (mu_x * mu_y) & ((1 << (2 * PIXEL_SIZE)) - 1)
    
    muX_sq_plus_muY_sq = (muX_sq + muY_sq) & ((1 << (2 * PIXEL_SIZE + 1)) - 1)
    two_muXY = (int_muXY << 1) & ((1 << (2 * PIXEL_SIZE + 1)) - 1)
    
    numr_part_1 = (two_muXY + C1) & PART_MASK
    denr_part_1 = (muX_sq_plus_muY_sq + C1) & PART_MASK
    
    sigma_xy = compute_sigma_xy(image_x, image_y)
    sigma_sq_x = compute_sigma_sq(image_x)
    sigma_sq_y = compute_sigma_sq(image_y)
    
    raw_sum = sigma_xy.astype(np.int64) * 2 + C2
    denr_part_2 = (sigma_sq_x.astype(np.int64) + sigma_sq_y.astype(np.int64) + C2) & PART_MASK
    
    denr = denr_part_1 * denr_part_2
    
    return numr_part_1, raw_sum, denr

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out_dir", required=True)
    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)

    input_old_path     = os.path.join(args.out_dir, "inputs_old.hex")
    input_avg_path     = os.path.join(args.out_dir, "inputs_avg.hex")
    input_new_path     = os.path.join(args.out_dir, "inputs_new.hex")
    output_packed_path = os.path.join(args.out_dir, "outputs_packed.hex")

    total_pixels = IMAGE_HEIGHT * IMAGE_WIDTH
    total_beats = total_pixels // PIXELS_PER_BEAT

    # Generate random matrix base sets
    beats_old = np.random.randint(0, 256, size=(total_beats, PIXELS_PER_BEAT), dtype=np.uint8)
    beats_avg = np.random.randint(0, 256, size=(total_beats, PIXELS_PER_BEAT), dtype=np.uint8)
    beats_new = np.random.randint(0, 256, size=(total_beats, PIXELS_PER_BEAT), dtype=np.uint8)
    # beats_old = np.zeros((total_beats, PIXELS_PER_BEAT), dtype=np.uint8)
    # beats_avg = np.zeros((total_beats, PIXELS_PER_BEAT), dtype=np.uint8)
    # beats_new = np.zeros((total_beats, PIXELS_PER_BEAT), dtype=np.uint8)
    #beats_old = np.full((total_beats, PIXELS_PER_BEAT), 255, dtype=np.uint8)
    # beats_avg = np.full((total_beats, PIXELS_PER_BEAT), 255, dtype=np.uint8)
    # beats_new = np.full((total_beats, PIXELS_PER_BEAT), 255, dtype=np.uint8)
    
    image_old = beats_old.reshape((IMAGE_HEIGHT, IMAGE_WIDTH))
    image_avg = beats_avg.reshape((IMAGE_HEIGHT, IMAGE_WIDTH))
    image_new = beats_new.reshape((IMAGE_HEIGHT, IMAGE_WIDTH))

    # Compute intermediate components for both structural paths
    numr_p1_x, raw_sum_x, denr_x = get_hssim_components(image_old, image_avg)
    numr_p1_z, raw_sum_z, denr_z = get_hssim_components(image_avg, image_new)

    # Convert to standard 1D flat structures for linear beat packing
    numr_p1_x_f = numr_p1_x.flatten()
    raw_sum_x_f = raw_sum_x.flatten()
    denr_x_f    = denr_x.flatten()
    
    numr_p1_z_f = numr_p1_z.flatten()
    raw_sum_z_f = raw_sum_z.flatten()
    denr_z_f    = denr_z.flatten()

    packed_list = []
    
    for b in range(total_beats):
        del_beat_val = 0
        for lane in range(PIXELS_PER_BEAT):
            idx = b * PIXELS_PER_BEAT + lane
            
            # Extract true high-level signed representation for both numerators
            numr_x_signed = int(numr_p1_x_f[idx]) * int(raw_sum_x_f[idx])
            numr_z_signed = int(numr_p1_z_f[idx]) * int(raw_sum_z_f[idx])
            
            # Execute true mathematical signed cross-multiplications
            p1_signed = numr_x_signed * int(denr_z_f[idx])
            p2_signed = numr_z_signed * int(denr_x_f[idx])
            
            # Decide mask value based on direct high-level comparison
            pixel_mask = 255 if (p2_signed > p1_signed) else 0
            
            del_beat_val |= pixel_mask << (lane * PIXEL_SIZE)
            
        packed_list.append(del_beat_val)

    # Write out the three input streams and the single combined mask master file
    s_beats_old = write_axi_stream_hex(input_old_path, image_old, DATA_WIDTH)
    s_beats_avg = write_axi_stream_hex(input_avg_path, image_avg, DATA_WIDTH)
    s_beats_new = write_axi_stream_hex(input_new_path, image_new, DATA_WIDTH)
    m_beats_p   = write_wide_hex(output_packed_path, packed_list, DATA_WIDTH)

    config_path = os.path.join(args.out_dir, "tb_config.svh")
    with open(config_path, 'w') as f:
        f.write("`define NUM_S_AXIS           3\n")
        f.write("`define NUM_M_AXIS           1\n")
        f.write(f"`define S_AXIS_DATA_WIDTH    {DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH    {DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_0 {s_beats_old}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_1 {s_beats_avg}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS_2 {s_beats_new}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS_0 {m_beats_p}\n")

    print(f"Success. Complete 3-Stream Top-Level files generated in {args.out_dir}")

if __name__ == "__main__":
    main()