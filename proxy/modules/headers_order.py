import random
from .base_module import DataLeakSanitizer

class HeadersOrderSanitizer(DataLeakSanitizer):
    def sanitize(self, headers_list):
        if len(headers_list) <= 1:
            return headers_list
        first, rest = headers_list[0], headers_list[1:]
        random.shuffle(rest)
        return [first] + rest