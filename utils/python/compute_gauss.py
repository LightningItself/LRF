import numpy as np

def compute_gauss(image_array):
    # 1. Pad and convert to uint16
    p = np.pad(image_array, pad_width=((0, 2), (0, 2)), mode='constant', constant_values=0).astype(np.uint16)

    # 2. Convolution logic
    out_data = (
        (p[0:-2, 0:-2]     ) + (p[0:-2, 1:-1] << 1) + (p[0:-2, 2:]     ) +
        (p[1:-1, 0:-2] << 1) + (p[1:-1, 1:-1] << 2) + (p[1:-1, 2:] << 1) +
        (p[2:,   0:-2]     ) + (p[2:,   1:-1] << 1) + (p[2:,   2:]     )
    ) >> 4

    # 3. Apply 2-row, 2-pixel hardware delay
    expected_output = np.zeros_like(image_array, dtype=np.uint8)
    expected_output[2:, 2:] = out_data[0:-2, 0:-2].astype(np.uint8)

    return expected_output