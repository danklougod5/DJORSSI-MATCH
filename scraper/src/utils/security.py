import ipaddress
from urllib.parse import urlparse
import logging

def is_safe_url(url_str: str) -> bool:
    """
    Checks if a URL is safe for scraping (SSRF protection).
    Blocks private IP ranges, localhost, and non-http/https schemes.
    """
    try:
        parsed = urlparse(url_str)
        if parsed.scheme not in ['http', 'https']:
            return False
        
        hostname = parsed.hostname
        if not hostname:
            return False

        # Block localhost and common names
        blocked_hosts = ['localhost', '127.0.0.1', '[::1]', '0.0.0.0']
        if hostname.lower() in blocked_hosts:
            return False

        # Block private IP ranges
        try:
            ip = ipaddress.ip_address(hostname)
            if ip.is_loopback or ip.is_private or ip.is_link_local or ip.is_multicast:
                return False
        except ValueError:
            # Not an IP address, which is fine as long as it's not in blocked_hosts
            pass
            
        # Optional: Block AWS metadata and similar cloud services directly by IP
        if hostname == '169.254.169.254':
            return False

        return True
    except Exception as e:
        logging.error(f"Error validating URL {url_str}: {e}")
        return False
