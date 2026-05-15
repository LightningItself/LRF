import numpy as np

def write_axi_stream_hex(filename, data_array, data_width_bits):
    # Ensure we are working with a flat array
    flat_data = data_array.flatten()
    
    # Determine how many bits each element in the NumPy array uses
    # itemsize is bytes, so * 8 = bits
    element_width_bits = flat_data.dtype.itemsize * 8
    
    if data_width_bits % element_width_bits != 0:
        raise ValueError(f"Bus width ({data_width_bits}) must be a multiple of element width ({element_width_bits})")
        
    elements_per_beat = data_width_bits // element_width_bits
    
    # Padding logic: Ensure the total number of elements fits perfectly into beats
    remainder = len(flat_data) % elements_per_beat
    if remainder != 0:
        pad_width = elements_per_beat - remainder
        flat_data = np.pad(flat_data, (0, pad_width), mode='constant', constant_values=0)
        
    total_beats = len(flat_data) // elements_per_beat
    hex_chars_per_element = element_width_bits // 4
    
    # Bitmask for handling signed numbers (e.g., 0xFF for 8-bit, 0xFFFF for 16-bit)
    mask = (1 << element_width_bits) - 1
    
    with open(filename, 'w') as f:
        for i in range(0, len(flat_data), elements_per_beat):
            chunk = flat_data[i : i + elements_per_beat]
            
            # Logic Breakdown:
            # 1. (x & mask): Converts signed negative to 2's complement bit pattern
            # 2. fmt.format: Converts to hex string
            # 3. reversed: Packs chunk[0] into LSB (rightmost in array, leftmost in hex? No.)
            #    In AXI, TDATA[7:0] is the first element. 
            #    In hex files, the RIGHTMOST chars are the LSB.
            #    So, for element 0 at LSB, element 0 must be at the END of the string.
            
            hex_string = "".join(f"{ (x & mask) :0{hex_chars_per_element}X}" for x in reversed(chunk))
            f.write(hex_string + "\n")
            
    return total_beats