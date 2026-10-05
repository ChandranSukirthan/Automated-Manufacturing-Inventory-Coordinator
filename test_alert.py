import requests
import json
import time

url = "http://localhost:5070/api/inventory/alerts"
payload = {
  "sku": "RM-STEEL-001",
  "packagingType": "Standard Roll",
  "quantityRequested": 500,
  "workerId": "worker@amic.com",
  "materialName": "Cold Rolled Steel Sheet"
}
headers = {'Content-Type': 'application/json'}

try:
    print("Creating alert...")
    response = requests.post(url, json=payload, headers=headers)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")
    
    if response.status_code in [200, 201]:
        data = response.json()
        alert_id = data.get("id")
        
        if alert_id:
            print(f"\nCreated Alert ID: {alert_id}")
            time.sleep(2)
            
            # Acknowledge the alert
            put_url = f"{url}/{alert_id}"
            put_payload = {"status": "Acknowledged"}
            print(f"Acknowledging alert {alert_id}...")
            put_resp = requests.put(put_url, json=put_payload, headers=headers)
            print(f"PUT Status Code: {put_resp.status_code}")
            
            # Check notifications
            get_resp = requests.get(url)
            print(f"\nCurrent Alerts count: {len(get_resp.json())}")
except Exception as e:
    print(f"Error: {e}")
