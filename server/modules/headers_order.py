from .base_module import DataLeakExtractor


# Headers Order Extractor:
# Extracts bits of information based on the order of headers in the request.
# It compares the 2nd and 3rd headers(if present) and appends a "0" or "1" to the bit buffer for the entrypoint accordingly.
# Once 8 bits are collected, it converts them to a character and appends it to the leaked data for that entrypoint.
class HeadersOrderExtractor(DataLeakExtractor):
    def extract(self, headers, entrypoint, leaked_data, bit_buffers):
        headers_list = list(headers.keys())
        print(f"[DEBUG] Headers received: {headers_list}")
        
        if len(headers_list) >= 3:
            row3, row4 = headers_list[1], headers_list[2]
            bit = "0" if row3 < row4 else "1"
            print(f"[DEBUG] Comparing '{row3}' < '{row4}' -> bit={bit}")
            bit_buffers[entrypoint] += bit

            if len(bit_buffers[entrypoint]) >= 8:
                byte_str = bit_buffers[entrypoint][:8]
                bit_buffers[entrypoint] = bit_buffers[entrypoint][8:]
                print(f"[DEBUG] byte_str={byte_str} -> chr={chr(int(byte_str, 2)) if byte_str != '00000000' else 'NULL'}")
                if byte_str != "00000000":
                    leaked_data[entrypoint] += chr(int(byte_str, 2))