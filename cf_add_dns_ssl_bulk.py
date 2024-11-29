import requests
import time

# Cloudflare API endpoint for managing DNS records
api_base_url = "https://api.cloudflare.com/client/v4"

# Your Cloudflare API token
api_token = "1meIiHGUvK5t0_MD3PjB_Mlu7TWVVAwlx5GAvnRx"

# Headers with authorization token
headers = {
    "Authorization": f"Bearer {api_token}",
    "Content-Type": "application/json"
}

# Prompt the user for the IP address
ip_address = input("Enter the IP address for the A record: ")

# DNS records to add
dns_records_to_add = [
    {"type": "A", "name": "@", "content": ip_address, "ttl": 3600, "proxied": True},
    {"type": "CNAME", "name": "www", "content": "@", "ttl": 3600, "proxied": True}
]

# Function to set SSL/TLS to Full
def set_ssl_to_full(zone_id, domain):
    ssl_url = f"{api_base_url}/zones/{zone_id}/settings/ssl"
    data = {"value": "full"}
    response = requests.patch(ssl_url, headers=headers, json=data)
    if response.status_code == 200:
        print(f"Successfully set SSL/TLS to Full for domain: {domain}")
    else:
        print(f"\nFailed to set SSL/TLS to Full for domain: {domain}. Error: {response.json()}".upper())

# Function to add DNS records for domains listed in a file
def add_dns_records_from_file(file_path):
    try:
        with open(file_path, 'r') as file:
            domains = file.readlines()
            domains = [domain.strip() for domain in domains if domain.strip()]

        for domain in domains:
            # Step 1: Get zone ID for the domain
            zone_id = None
            zones_url = f"{api_base_url}/zones"
            params = {"name": domain}
            response = requests.get(zones_url, headers=headers, params=params)
            if response.status_code == 200 and response.json()["result"]:
                zone_id = response.json()["result"][0]["id"]
            else:
                print(f"\nFailed to retrieve zone ID for domain: {domain}. Error: {response.json()}".upper())
                continue

            # Step 2: Add DNS records
            for record in dns_records_to_add:
                api_url = f"{api_base_url}/zones/{zone_id}/dns_records"
                response = requests.post(api_url, headers=headers, json=record)
                if response.status_code == 200:
                    print(f"Successfully added {record['type']} record for {domain}: {record['name']} -> {record['content']}")
                else:
                    print(f"\nFailed to add {record['type']} record for {domain}: {record['name']}. Error: {response.json()}".upper())

            # Step 3: Set SSL/TLS to Full
            set_ssl_to_full(zone_id, domain)
    except FileNotFoundError:
        print(f"File not found: {file_path}")
    except Exception as e:
        print(f"An error occurred: {e}".upper())

# Main function
def main():
    file_path = "domains.txt"
    add_dns_records_from_file(file_path)

if __name__ == "__main__":
    main()