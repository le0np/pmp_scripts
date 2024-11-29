import requests
import time

# Cloudflare API endpoint for adding a zone
api_url = "https://api.cloudflare.com/client/v4/zones"

# Your Cloudflare API token
api_token = "1meIiHGUvK5t0_MD3PjB_Mlu7TWVVAwlx5GAvnRx"

# Headers with authorization token
headers = {
    "Authorization": f"Bearer {api_token}",
    "Content-Type": "application/json"
}

# Function to add a new domain to Cloudflare
def add_domain_to_cloudflare(domain_name):
    data = {
        "name": domain_name,
        "jump_start": True  # Set to True to automatically fetch existing DNS records
    }

    response = requests.post(api_url, headers=headers, json=data)
    if response.status_code == 200:
        print(f"\nSuccessfully added domain: {domain_name}")
        zone_id = response.json()["result"]["id"]
        return zone_id
    else:
        print(f"\nFailed to add domain: {domain_name}. Error: {response.json()}".upper())
        return None

# Function to get nameservers for a domain
def get_nameservers(zone_id):
    ns_url = f"{api_url}/{zone_id}"
    response = requests.get(ns_url, headers=headers)
    if response.status_code == 200:
        nameservers = response.json()["result"]["name_servers"]
        return nameservers
    else:
        print(f"\nFailed to get nameservers for zone ID: {zone_id}. Error: {response.json()}".upper())
        return None

# Function to read domains from a file and add them to Cloudflare
def add_domains_from_file(file_path):
    try:
        with open(file_path, 'r') as file:
            domains = file.readlines()
            domains = [domain.strip() for domain in domains if domain.strip()]

        for domain in domains:
            zone_id = add_domain_to_cloudflare(domain)
            if zone_id:
                # Pause to ensure that the DNS records are processed
                time.sleep(5)
                nameservers = get_nameservers(zone_id)
                if nameservers:
                    print(f"Nameservers for {domain}: \n{', '.join(nameservers)}")   # NEW LINE 
    except FileNotFoundError:
        print(f"File not found: {file_path}")
    except Exception as e:
        print(f"An error occurred: {e}")

# Main function
def main():
    file_path = "domains.txt"
    add_domains_from_file(file_path)

if __name__ == "__main__":
    main()