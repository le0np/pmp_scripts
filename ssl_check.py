import requests
import json
from urllib.parse import urlparse

def format_domain(domain):
    domain = domain.strip()
    if not domain.startswith("http://") and not domain.startswith("https://"):
        domain = "https://" + domain
    parsed_url = urlparse(domain)
    formatted_domain = parsed_url.netloc or parsed_url.path
    return "https://" + formatted_domain

def check_ssl(domain):
    try:
        response = requests.get(domain, timeout=5)
        if response.status_code == 200:
            return {"valid": True, "error": None}
        else:
            return {"valid": False, "error": f"HTTP status code: {response.status_code}"}
    except requests.exceptions.SSLError as e:
        return {"valid": False, "error": str(e)}
    except requests.exceptions.RequestException as e:
        return {"valid": False, "error": str(e)}

def main():
    results = {}
    
    try:
        with open("domains.txt", "r") as file:
            domains = file.readlines()
    except FileNotFoundError:
        print("The file domains.txt was not found.")
        return

    for domain in domains:
        formatted_domain = format_domain(domain)
        result = check_ssl(formatted_domain)
        results[domain.strip()] = result
    
    with open("results.json", "w") as outfile:
        json.dump(results, outfile, indent=4)

    print("SSL check completed. Results are saved in results.json")

if __name__ == "__main__":
    main()