import urllib.request
import urllib.error

try:
    print("Testing connection to http://192.168.1.33:8000/health...")
    response = urllib.request.urlopen("http://192.168.1.33:8000/health", timeout=2)
    print("Success. Body:", response.read().decode("utf-8"))
except urllib.error.URLError as e:
    print("URLError:", type(e.reason), e.reason)
except Exception as e:
    print("Exception:", type(e), e)
