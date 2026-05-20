from .base_module import DataLeakSanitizer

ALLOWED_HEADERS = {
    "host", "content-type", "content-length", "accept",
    "accept-encoding", "accept-language", "connection",
    "user-agent", "referer", "authorization", "cookie",
    "cache-control", "pragma", "origin"
}

class DedicatedHeaderSanitizer(DataLeakSanitizer):
    def sanitize(self, headers_list):
        sanitized = [(k, v) for k, v in headers_list if k.lower() in ALLOWED_HEADERS]
        dropped = [k for k, v in headers_list if k.lower() not in ALLOWED_HEADERS]
        if dropped:
            print(f"[!] Sanitizer dropped non-standard headers: {dropped}")
        return sanitized