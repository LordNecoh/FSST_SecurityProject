from .base_module import DataLeakExtractor

# Dedicated Header Extractor:
# Extracts specific headers from the request and stores their values in the leaked_data dictionary under the corresponding entrypoint.
# Currently only the "data-leak" header is usede this way
class DedicatedHeaderExtractor(DataLeakExtractor):
    def extract(self, headers, entrypoint, leaked_data, bit_buffers):
        leaked_value = headers.get('X-dataleak')
        if leaked_value:
            leaked_data[entrypoint] = leaked_value