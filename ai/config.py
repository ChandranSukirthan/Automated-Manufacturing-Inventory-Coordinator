import os
import logging

# Configure standard logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger("amic_agentic_ai")

# Safe environment configuration (no credentials/passwords exposed)
BACKEND_HOST = os.getenv("BACKEND_HOST", "http://localhost:5070")
INVENTORY_API_URL = os.getenv("INVENTORY_API_URL", f"{BACKEND_HOST}/api/inventory")
ALERTS_API_URL = os.getenv("ALERTS_API_URL", f"{BACKEND_HOST}/api/inventory/alerts")
PURCHASE_ORDERS_API_URL = os.getenv("PURCHASE_ORDERS_API_URL", f"{BACKEND_HOST}/api/purchase-orders")

API_TIMEOUT_SECONDS = float(os.getenv("API_TIMEOUT_SECONDS", "5.0"))
AI_SERVER_HOST = os.getenv("AI_SERVER_HOST", "0.0.0.0")
AI_SERVER_PORT = int(os.getenv("AI_SERVER_PORT", "8000"))
CHECK_INTERVAL_SECONDS = int(os.getenv("CHECK_INTERVAL_SECONDS", "60"))
