import time
import requests
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

API_BASE_URL = "http://localhost:5158/api/Inventory"
ALERTS_URL = f"{API_BASE_URL}/alerts"
CHECK_INTERVAL_SECONDS = 60

def fetch_inventory():
    try:
        response = requests.get(API_BASE_URL, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        logging.error(f"Failed to fetch inventory: {e}")
        return None

def send_alert(item):
    # Determine how much to reorder. 
    # For a simple monitor, a fixed amount like 500 is requested.
    quantity_to_order = 500 
    
    alert_payload = {
        "sku": item.get("sku", ""),
        "packagingType": item.get("category", "Unknown"), # Mapping Category to PackagingType
        "quantityRequested": quantity_to_order,
        "workerId": "Auto-Monitor-Bot"
    }
    
    try:
        response = requests.post(ALERTS_URL, json=alert_payload, timeout=10)
        response.raise_for_status()
        logging.info(f"Successfully created alert for SKU: {alert_payload['sku']} (Quantity: {quantity_to_order})")
    except requests.exceptions.RequestException as e:
        logging.error(f"Failed to create alert for SKU {alert_payload['sku']}: {e}")

def run_monitor():
    logging.info(f"Starting automated inventory monitor. Checking every {CHECK_INTERVAL_SECONDS} seconds...")
    
    while True:
        logging.info("Checking inventory levels...")
        inventory = fetch_inventory()
        
        if inventory:
            for item in inventory:
                stock_level = item.get("stockLevel", 0)
                reorder_threshold = item.get("reorderThreshold", 0)
                sku = item.get("sku", "Unknown")
                
                if stock_level <= reorder_threshold:
                    logging.warning(f"Low stock detected for {sku}: {stock_level} <= {reorder_threshold}. Triggering alert.")
                    send_alert(item)
                else:
                    # using debug level to avoid cluttering the standard output unless configured
                    logging.debug(f"Stock level okay for {sku}: {stock_level} > {reorder_threshold}")
        else:
            logging.warning("No inventory data received or failed to connect.")
            
        time.sleep(CHECK_INTERVAL_SECONDS)

if __name__ == "__main__":
    try:
        run_monitor()
    except KeyboardInterrupt:
        logging.info("Inventory monitor stopped by user.")
