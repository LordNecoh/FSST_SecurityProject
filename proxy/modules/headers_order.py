import random
from .base_module import DataLeakSanitizer

# Headers Order Sanitizer:
# Randomizes the order of headers in the request to make it harder for fingerprinting techniques
#   that rely on header order to identify specific clients or libraries. 
class HeadersOrderSanitizer(DataLeakSanitizer):
    def sanitize(self, headers_list):
        if len(headers_list) <= 1:
            return headers_list
        first, rest = headers_list[0], headers_list[1:]
        random.shuffle(rest)
        return [first] + rest