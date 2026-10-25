import zipfile
import struct
import io

aab_path = r"build\app\outputs\bundle\release\app-release.aab"

def check_elf(name, data):
    if len(data) < 64 or data[:4] != b'\x7fELF':
        return None
    ei_class = data[4]
    ei_data = data[5]
    if ei_class != 2 or ei_data != 1: # ELF64, Little Endian
        return f"Class {ei_class}, not ELF64"
    
    e_phoff = struct.unpack_from('<Q', data, 32)[0]
    e_phentsize = struct.unpack_from('<H', data, 54)[0]
    e_phnum = struct.unpack_from('<H', data, 56)[0]
    
    alignments = []
    for i in range(e_phnum):
        ph_offset = e_phoff + i * e_phentsize
        if ph_offset + e_phentsize > len(data):
            break
        p_type = struct.unpack_from('<I', data, ph_offset)[0]
        if p_type == 1: # PT_LOAD
            p_align = struct.unpack_from('<Q', data, ph_offset + 48)[0]
            alignments.append(p_align)
            
    min_align = min(alignments) if alignments else 0
    max_align = max(alignments) if alignments else 0
    is_16kb = all(a >= 16384 for a in alignments) if alignments else False
    return is_16kb, alignments

with zipfile.ZipFile(aab_path, 'r') as z:
    for filename in z.namelist():
        if filename.endswith('.so') and ('arm64-v8a' in filename or 'x86_64' in filename):
            data = z.read(filename)
            res = check_elf(filename, data)
            print(f"{filename}: {res}")
