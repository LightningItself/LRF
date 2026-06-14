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

PART_BITS   = 2 * PIXEL_SIZE + 2
PART_MASK   = (1 << PART_BITS) - 1
SIG_XY_BITS = 2 * PIXEL_SIZE + 1
SIG_XY_MASK = (1 << SIG_XY_BITS) - 1

def compute_sobel(image):
    padded = np.pad(image, pad_width=((0, 2), (0, 2)), mode='constant', constant_values=0)
    p = padded.astype(np.int32)
    gx = (
        -p[0:-2, 0:-2] + p[0:-2, 2:] +
        -(p[1:-1, 0:-2] << 1) + (p[1:-1, 2:] << 1) +
        -p[2:,   0:-2] + p[2:,   2:]
    )
    gy = (
         p[0:-2, 0:-2] + (p[0:-2, 1:-1] << 1) + p[0:-2, 2:] +
        -p[2:,   0:-2] - (p[2:,   1:-1] << 1) - p[2:,   2:]
    )
    mag = np.sqrt(gx.astype(np.float64)**2 + gy.astype(np.float64)**2)
    out = np.clip(mag, 0, 255).astype(np.uint8)
    result = np.zeros((IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)
    result[2:, 2:] = out[0:-2, 0:-2]
    return result

def compute_sigma_xy(image_x, image_y):
    xy_prod         = image_x.astype(np.uint32) * image_y.astype(np.uint32)
    gauss_xy        = compute_gauss(xy_prod, dtype=np.uint32)
    mu_x            = compute_gauss(image_x, dtype=np.uint8)
    mu_y            = compute_gauss(image_y, dtype=np.uint8)
    mu_x_mu_y       = mu_x.astype(np.uint32) * mu_y.astype(np.uint32)
    sigma_xy        = gauss_xy.astype(np.int64) - mu_x_mu_y.astype(np.int64)
    sigma_xy_17     = sigma_xy & SIG_XY_MASK
    sigma_xy_signed = np.where(
        sigma_xy_17 >= (1 << (SIG_XY_BITS - 1)),
        sigma_xy_17 - (1 << SIG_XY_BITS),
        sigma_xy_17
    ).astype(np.int32)
    return sigma_xy_signed

def compute_sigma_sq(image):
    x_sq     = image.astype(np.uint32) ** 2
    gauss_x2 = compute_gauss(x_sq, dtype=np.uint32)
    mu       = compute_gauss(image, dtype=np.uint8)
    mu_sq    = mu.astype(np.uint32) ** 2
    sigma_sq = gauss_x2.astype(np.int64) - mu_sq.astype(np.int64)
    return (sigma_sq & ((1 << (2 * PIXEL_SIZE)) - 1)).astype(np.uint32)

def compute_hssim_del(edge_old, edge_avg, edge_new):
    mu_old = compute_gauss(edge_old, dtype=np.uint8).astype(np.uint32)
    mu_avg = compute_gauss(edge_avg, dtype=np.uint8).astype(np.uint32)
    mu_new = compute_gauss(edge_new, dtype=np.uint8).astype(np.uint32)

    muOA_sq    = (mu_old * mu_old) & ((1 << (2*PIXEL_SIZE)) - 1)
    muAA_sq    = (mu_avg * mu_avg) & ((1 << (2*PIXEL_SIZE)) - 1)
    int_muOA   = (mu_old * mu_avg) & ((1 << (2*PIXEL_SIZE)) - 1)
    two_muOA   = (int_muOA << 1) & ((1 << (2*PIXEL_SIZE+1)) - 1)
    numr_p1_OA = (two_muOA + C1) & PART_MASK
    denr_p1_OA = ((muOA_sq + muAA_sq) + C1) & PART_MASK
    sig_xy_OA  = compute_sigma_xy(edge_old, edge_avg)
    sig_sq_O   = compute_sigma_sq(edge_old)
    sig_sq_A   = compute_sigma_sq(edge_avg)
    raw_OA     = sig_xy_OA.astype(np.int64) * 2 + C2
    denr_p2_OA = (sig_sq_O.astype(np.int64) + sig_sq_A.astype(np.int64) + C2) & PART_MASK
    denr_OA    = denr_p1_OA.astype(np.int64) * denr_p2_OA.astype(np.int64)
    numr_OA    = numr_p1_OA.astype(np.int64) * raw_OA.astype(np.int64)

    muNN_sq    = (mu_new * mu_new) & ((1 << (2*PIXEL_SIZE)) - 1)
    int_muAN   = (mu_avg * mu_new) & ((1 << (2*PIXEL_SIZE)) - 1)
    two_muAN   = (int_muAN << 1) & ((1 << (2*PIXEL_SIZE+1)) - 1)
    numr_p1_AN = (two_muAN + C1) & PART_MASK
    denr_p1_AN = ((muAA_sq + muNN_sq) + C1) & PART_MASK
    sig_xy_AN  = compute_sigma_xy(edge_avg, edge_new)
    sig_sq_N   = compute_sigma_sq(edge_new)
    raw_AN     = sig_xy_AN.astype(np.int64) * 2 + C2
    denr_p2_AN = (sig_sq_A.astype(np.int64) + sig_sq_N.astype(np.int64) + C2) & PART_MASK
    denr_AN    = denr_p1_AN.astype(np.int64) * denr_p2_AN.astype(np.int64)
    numr_AN    = numr_p1_AN.astype(np.int64) * raw_AN.astype(np.int64)

    p1 = numr_OA * denr_AN
    p2 = numr_AN * denr_OA
    return np.where(p2 > p1, np.uint8(0xFF), np.uint8(0x00)).astype(np.uint8)

def compute_fusion(old_frame, new_frame, del_gauss):
    dbar      = (~del_gauss.astype(np.uint8)).astype(np.uint16)
    d         = del_gauss.astype(np.uint16)
    result_16 = old_frame.astype(np.uint16) * dbar + new_frame.astype(np.uint16) * d
    return (result_16 >> 8).astype(np.uint8)

def compute_output(old_fused, fused_frame, del_map):
    return np.where(del_map == 0, old_fused, fused_frame).astype(np.uint8)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out_dir', required=True)
    args = parser.parse_args()
    os.makedirs(args.out_dir, exist_ok=True)

    rng = np.random.default_rng(seed=20)

    total_pixels = IMAGE_HEIGHT * IMAGE_WIDTH
    pixels_per_beat = 16
    total_beats = total_pixels // pixels_per_beat  # 16384 total beats

    # Target the exact middle beat index
    middle_beat = total_beats // 2                 # Beat 8192
    
    start_pixel = middle_beat * pixels_per_beat     # Pixel index 131072
    end_pixel = start_pixel + pixels_per_beat       # Pixel index 131088

    # 1. Start with completely flat zero frames
    flat_old = np.zeros(total_pixels, dtype=np.uint8)
    flat_avg = np.zeros(total_pixels, dtype=np.uint8)
    flat_new = np.zeros(total_pixels, dtype=np.uint8)

    # 2. Assign random data to ONLY that single 16-pixel wide center beat
    flat_old[start_pixel:end_pixel] = rng.integers(0, 256, pixels_per_beat, dtype=np.uint8)
    flat_avg[start_pixel:end_pixel] = rng.integers(0, 256, pixels_per_beat, dtype=np.uint8)
    flat_new[start_pixel:end_pixel] = rng.integers(0, 256, pixels_per_beat, dtype=np.uint8)

    # 3. Reshape back to the 2D dimensions your filters expect
    image_old = flat_old.reshape((IMAGE_HEIGHT, IMAGE_WIDTH))
    image_avg = flat_avg.reshape((IMAGE_HEIGHT, IMAGE_WIDTH))
    image_new = flat_new.reshape((IMAGE_HEIGHT, IMAGE_WIDTH))

    edge_old = compute_sobel(image_old)
    edge_avg = compute_sobel(image_avg)
    edge_new = compute_sobel(image_new)

    del_map = compute_hssim_del(edge_old, edge_avg, edge_new)

    del_gauss = compute_gauss(del_map, dtype=np.uint8)

    fused = compute_fusion(image_old, image_new, del_gauss)

    output = compute_output(image_old, fused, del_map)

    s0 = write_axi_stream_hex(os.path.join(args.out_dir, 'inputs_old.hex'), image_old, DATA_WIDTH)
    s1 = write_axi_stream_hex(os.path.join(args.out_dir, 'inputs_avg.hex'), image_avg, DATA_WIDTH)
    s2 = write_axi_stream_hex(os.path.join(args.out_dir, 'inputs_new.hex'), image_new, DATA_WIDTH)
    m0 = write_axi_stream_hex(os.path.join(args.out_dir, 'outputs_top.hex'), output,   DATA_WIDTH)

    config_path = os.path.join(args.out_dir, 'tb_config.svh')
    with open(config_path, 'w') as f:
        f.write(f"`define BIT_WIDTH            {PIXEL_SIZE}\n")
        f.write(f"`define PIXELS_PER_BEAT      {PIXELS_PER_BEAT}\n")
        f.write(f"`define IMAGE_WIDTH          {IMAGE_WIDTH}\n")
        f.write(f"`define S_AXIS_DATA_WIDTH    {DATA_WIDTH}\n")
        f.write(f"`define M_AXIS_DATA_WIDTH    {DATA_WIDTH}\n")
        f.write(f"`define S_AXIS_TOTAL_BEATS   {s0}\n")
        f.write(f"`define M_AXIS_TOTAL_BEATS   {m0}\n")

    print(f"Generated {s0} input beats and {m0} output beats -> {args.out_dir}")

if __name__ == '__main__':
    main()