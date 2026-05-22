from .base_module import DataLeakSanitizer

# List of headers that are considered safe and will be forwarded without modification.
# (These are common headers that typically do not contain sensitive information.)
ALLOWED_HEADERS = {
    "host", "content-type", "content-length", "accept",
    "accept-encoding", "accept-language", "connection",
    "user-agent", "cache-control"
}

# Dedicated Header Sanitizer: 
# Only allows a predefined set of headers to be forwarded, dropping any non-standard or potentially sensitive headers.
class DedicatedHeaderSanitizer(DataLeakSanitizer):
    def sanitize(self, headers_list):
        sanitized = [(k, v) for k, v in headers_list if k.lower() in ALLOWED_HEADERS]
        dropped = [k for k, v in headers_list if k.lower() not in ALLOWED_HEADERS]
        if dropped:
            print(f"[!] Sanitizer dropped non-standard headers: {dropped}")
        return sanitized