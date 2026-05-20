from .base_module import DataLeakExtractor

class DedicatedHeaderExtractor(DataLeakExtractor):
    def extract(self, headers, entrypoint, leaked_data, bit_buffers):
        leaked_value = headers.get('X-dataleak')
        if leaked_value:
            leaked_data[entrypoint] = leaked_value