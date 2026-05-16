import numpy as np

def compute_gauss(image_array, dtype=np.uint8):
    dtype = np.dtype(dtype)

    if not np.issubdtype(dtype, np.integer):
        raise TypeError(f"dtype must be an integer dtype, got {dtype}")

    # The DUT keeps the same pixel width at the input and output of CONV_GAUSS.
    # Use a wider accumulator here so the weighted sum cannot overflow.
    if dtype.itemsize <= 1:
        accum_dtype = np.uint16
    elif dtype.itemsize <= 2:
        accum_dtype = np.uint32
    else:
        accum_dtype = np.uint64

    # 1. Pad, quantize to the requested pixel dtype, then widen for arithmetic
    p = np.pad(
        image_array.astype(dtype),
        pad_width=((0, 2), (0, 2)),
        mode='constant',
        constant_values=0
    ).astype(accum_dtype)

    # 2. Convolution logic
    out_data = (
        (p[0:-2, 0:-2]     ) + (p[0:-2, 1:-1] << 1) + (p[0:-2, 2:]     ) +
        (p[1:-1, 0:-2] << 1) + (p[1:-1, 1:-1] << 2) + (p[1:-1, 2:] << 1) +
        (p[2:,   0:-2]     ) + (p[2:,   1:-1] << 1) + (p[2:,   2:]     )
    ) >> 4

    # 3. Apply 2-row, 2-pixel hardware delay
    expected_output = np.zeros(image_array.shape, dtype=dtype)
    expected_output[2:, 2:] = out_data[0:-2, 0:-2].astype(dtype)

    return expected_output
