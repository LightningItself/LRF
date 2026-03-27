# This function converts a NumPy data array into AXI-stream compatible hex format.
# Steps:
# 1. Flatten the input array into a 1D sequence.
# 2. Calculate how many elements fit into one AXI data beat.
# 3. Pad with zeros if data does not align to full beats.
# 4. Split data into chunks (each chunk = one AXI beat).
# 5. Reverse element order inside each chunk (LSB-first packing).
# 6. Convert each element to hexadecimal and concatenate into one string.
# 7. Write one AXI beat per line into the output file.
# 8. Return total number of AXI beats generated.
#
# Purpose: Generate AXI-stream formatted hex files for simulation/testing.

import numpy as np

def write_axi_stream_hex(filename, data_array, data_width_bits):
    flat_data = data_array.flatten()
    element_width_bits = flat_data.dtype.itemsize * 8
    
    if data_width_bits % element_width_bits != 0:
        raise ValueError("data_width_bits must be a multiple of element width")
        
    elements_per_beat = data_width_bits // element_width_bits
    
    remainder = len(flat_data) % elements_per_beat
    if remainder != 0:
        pad_width = elements_per_beat - remainder
        flat_data = np.pad(flat_data, (0, pad_width), mode='constant', constant_values=0)
        
    total_beats = len(flat_data) // elements_per_beat
    hex_chars = element_width_bits // 4
    fmt = f"{{:0{hex_chars}X}}"
    
    with open(filename, 'w') as f:
        for i in range(0, len(flat_data), elements_per_beat):
            chunk = flat_data[i : i + elements_per_beat]
            hex_string = "".join(fmt.format(x) for x in reversed(chunk))
            f.write(hex_string + "\n")
            
    return total_beats