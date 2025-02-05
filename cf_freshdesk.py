import requests
# Cloudflare API base URL
api_base_url = "https://api.cloudflare.com/client/v4"
# API token should be obtained from Cloudflare -> My Profile -> API Tokens (create one if it does not exist)
api_token = "1meIiHGUvK5t0_MD3PjB_Mlu7TWVVAwlx5GAvnRx"
# Headers with authorization token
headers = {
    "Authorization": f"Bearer {api_token}",
    "Content-Type": "application/json"
}
# Function to get the zone ID from the domain name
def get_zone_id(domain):
    zones_url = f"{api_base_url}/zones"
    params = {"name": domain}
    response = requests.get(zones_url, headers=headers, params=params)
    if response.status_code == 200 and response.json()["result"]:
        return response.json()["result"][0]["id"]
    else:
        print(f"Failed to retrieve zone ID for domain: {domain}. Error: {response.json()}".upper())
        return None
# Function to list DNS records and prompt the user to delete records based on type
def list_and_delete_old_records(zone_id):
    api_url = f"{api_base_url}/zones/{zone_id}/dns_records"
    response = requests.get(api_url, headers=headers)
    dns_records = response.json()["result"]
    print("\n*** Existing DNS Records ***")
    for i, record in enumerate(dns_records, start=1):
        print(f"{i}. {record['type']} - {record['name']} -> {record['content']}")
    print("\nSelect the types of DNS records to DELETE:")
    print("(1)  A       (2)  CNAME")
    print("(3)  TXT     (4)  MX")
    print("(5)  AAAA    (6)  NS")
    print("(7)  SRV     (8)  PTR")
    print("(9)  CAA     (10) Done")
    types_to_delete = input("\nEnter the numbers corresponding to the DNS record types to delete, separated by commas (e.g., 1,2,3): ")
    record_types_to_delete = [record_type.strip() for record_type in types_to_delete.split(",")]
    record_type_mapping = {
        '1': 'A',
        '2': 'CNAME',
        '3': 'TXT',
        '4': 'MX',
        '5': 'AAAA',
        '6': 'NS',
        '7': 'SRV',
        '8': 'PTR',
        '9': 'CAA'
    }
    record_types_to_delete = [record_type_mapping[record_type] for record_type in record_types_to_delete if record_type in record_type_mapping]
    for record in dns_records:
        record_id = record["id"]
        record_type = record["type"]
        record_name = record["name"]
        if record_type in record_types_to_delete:
            delete_url = f"{api_url}/{record_id}"
            delete_response = requests.delete(delete_url, headers=headers)
            if delete_response.status_code == 200:
                print(f"Deleted {record_type} record: {record_name}")
            else:
                print(f"Failed to delete {record_type} record: {record_name}. Error: {delete_response.json()}".upper())
        else:
            print(f"Skipping {record_type} record: {record_name}")
# Function to set SSL/TLS to Full
def set_ssl_to_full(zone_id, domain):
    ssl_url = f"{api_base_url}/zones/{zone_id}/settings/ssl"
    data = {"value": "full"}
    response = requests.patch(ssl_url, headers=headers, json=data)
    if response.status_code == 200:
        print(f"Successfully set SSL/TLS to Full for domain: {domain}")
    else:
        print(f"Failed to set SSL/TLS to Full for domain: {domain}. Error: {response.json()}".upper())
# Function to add a DNS record
def add_dns_record(zone_id, record):
    api_url = f"{api_base_url}/zones/{zone_id}/dns_records"
    response = requests.post(api_url, headers=headers, json=record)
    if response.status_code == 200:
        print(f"Successfully added {record['type']} record: {record['name']} -> {record['content']}")
    else:
        print(f"Failed to add {record['type']} record: {record['name']}. Error: {response.json()}".upper())
# Function to prompt the user for DNS record input
def get_user_dns_records():
    user_dns_records = []
    while True:
        print("\nSelect the type of DNS record to ADD:")
        print("(1)  A       (2)  CNAME")
        print("(3)  TXT     (4)  MX")
        print("(5)  AAAA    (6)  NS")
        print("(7)  SRV     (8)  PTR")
        print("(9)  CAA     (10) Done")
        choice = input("\nEnter the number corresponding to the DNS record type: ")
        if choice == '10':
            print("\n*** Adding DNS records ***")
            break
        record_type = {
            '1': 'A',
            '2': 'CNAME',
            '3': 'TXT',
            '4': 'MX',
            '5': 'AAAA',
            '6': 'NS',
            '7': 'SRV',
            '8': 'PTR',
            '9': 'CAA'
        }.get(choice)
        if not record_type:
            print("\nInvalid choice. Please enter a number from 1 to 10.")
            continue
        name = input(f"\nEnter the {record_type} record name/host: ")
        content = input(f"Enter the {record_type} record content: ")
        record = {"type": record_type, "name": name, "content": content}
        if record_type == "MX":
            priority = int(input("Enter the MX record priority: "))
            record["priority"] = priority
        elif record_type == "SRV":
            service = input("Enter the SRV record service: ")
            proto = input("Enter the SRV record protocol: ")
            priority = int(input("Enter the SRV record priority: "))
            weight = int(input("Enter the SRV record weight: "))
            port = int(input("Enter the SRV record port: "))
            target = input("Enter the SRV record target: ")
            record.update({
                "data": {
                    "service": service,
                    "proto": proto,
                    "name": name,
                    "priority": priority,
                    "weight": weight,
                    "port": port,
                    "target": target
                }
            })
        user_dns_records.append(record)
    return user_dns_records
# Main function
def main():
    # Get the domain name from the user
    domain = input("Enter the domain name: ")
    # Get the zone ID for the domain
    zone_id = get_zone_id(domain)
    if not zone_id:
        return
    # List and delete old records
    list_and_delete_old_records(zone_id)
    # Hardcoded MX and SPF records
    dns_records_to_add = [
        {"type": "TXT", "name": "@", "content": "v=spf1 include:mailgun.org ~all"},
        {"type": "MX", "name": "@", "content": "mxa.mailgun.org", "priority": 10},
        {"type": "MX", "name": "@", "content": "mxb.mailgun.org", "priority": 10},
        {"type": "CNAME", "name": f"fwdkim1.{domain}", "content": "spfmx1.domainkey.freshemail.io"}
    ]
    # Get DNS records from user input
    user_dns_records = get_user_dns_records()
    dns_records_to_add.extend(user_dns_records)
    # Add each DNS record
    for record in dns_records_to_add:
        add_dns_record(zone_id, record)
    # Set SSL/TLS to Full
    set_ssl_to_full(zone_id, domain)
if __name__ == "__main__":
    main()
