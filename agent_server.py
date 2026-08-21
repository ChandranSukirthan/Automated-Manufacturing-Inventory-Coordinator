import asyncio
import logging
import random
import numpy as np
from sklearn.linear_model import LinearRegression
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import httpx

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

API_BASE_URL = "http://localhost:5158/api/Inventory"
ALERTS_URL = f"{API_BASE_URL}/alerts"
CHECK_INTERVAL_SECONDS = 60

# Model for incoming data based on the C# backend models
class InventoryItem(BaseModel):
    id: Optional[int] = None
    sku: str
    name: str
    category: str
    stockLevel: int
    reorderThreshold: int

def get_consumption_rate(sku: str) -> float:
    """
    Simulate historical inventory data for a SKU and use a linear regression model
    to predict the daily consumption rate.
    """
    # Create an array representing the past 30 days
    days = np.array(range(30)).reshape(-1, 1)
    
    # Generate a deterministic base consumption rate for this SKU (between 10 and 50)
    random.seed(sku)
    true_daily_consumption = random.uniform(10.0, 50.0)
    
    # Simulate past stock levels starting high and going down with some noise
    start_stock = 2000
    # Add random noise
    np.random.seed(hash(sku) % (2**32)) # consistent noise per sku
    noise = np.random.normal(0, 15, 30)
    
    past_stock = start_stock - (true_daily_consumption * days.flatten()) + noise
    
    # Fit linear regression model
    model = LinearRegression()
    model.fit(days, past_stock)
    
    # The rate of consumption is the absolute value of the negative slope
    consumption_rate = abs(model.coef_[0])
    return consumption_rate

# Define the background task
async def inventory_monitor_task():
    logger.info(f"Starting automated inventory monitor task. Checking every {CHECK_INTERVAL_SECONDS} seconds...")
    async with httpx.AsyncClient() as client:
        while True:
            logger.info("Checking inventory levels...")
            try:
                response = await client.get(API_BASE_URL, timeout=10.0)
                response.raise_for_status()
                inventory = response.json()
                
                if inventory:
                    for item in inventory:
                        stock_level = item.get("stockLevel", 0)
                        reorder_threshold = item.get("reorderThreshold", 0)
                        sku = item.get("sku", "Unknown")
                        
                        if stock_level <= reorder_threshold:
                            logger.warning(f"Low stock detected for {sku}: {stock_level} <= {reorder_threshold}. Triggering alert.")
                            await send_alert(client, item, is_predictive=False)
                        else:
                            # Predictive Machine Learning Forecast
                            daily_consumption = get_consumption_rate(sku)
                            predicted_stock_in_5_days = stock_level - (daily_consumption * 5)
                            
                            if predicted_stock_in_5_days <= reorder_threshold:
                                logger.warning(f"Predictive Alert for {sku}: Forecasted to drop below threshold ({reorder_threshold}) in 5 days! (Rate: {daily_consumption:.2f}/day).")
                                await send_alert(client, item, is_predictive=True)
                            else:
                                # Use debug to avoid cluttering logs
                                logger.debug(f"Stock level okay for {sku}: {stock_level} > {reorder_threshold}. Forecast in 5 days: {predicted_stock_in_5_days:.0f}")
                else:
                    logger.warning("No inventory data received or empty list.")
            except httpx.RequestError as e:
                logger.error(f"Failed to fetch inventory: {e}")
            except Exception as e:
                logger.error(f"Unexpected error in monitor task: {e}")
                
            # Sleep before next iteration
            await asyncio.sleep(CHECK_INTERVAL_SECONDS)

async def send_alert(client: httpx.AsyncClient, item: dict, is_predictive: bool = False):
    # Default reorder amount
    quantity_to_order = 500 
    
    worker_id = "Predictive Reorder Alert" if is_predictive else "Auto-Monitor-Bot"
    
    alert_payload = {
        "sku": item.get("sku", ""),
        "packagingType": item.get("category", "Unknown"),
        "quantityRequested": quantity_to_order,
        "workerId": worker_id
    }
    
    try:
        response = await client.post(ALERTS_URL, json=alert_payload, timeout=10.0)
        response.raise_for_status()
        logger.info(f"Successfully created alert for SKU: {alert_payload['sku']} (Quantity: {quantity_to_order})")
    except httpx.RequestError as e:
        logger.error(f"Failed to create alert for SKU {alert_payload['sku']}: {e}")

# Application lifespan to manage background tasks
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Start the background task
    task = asyncio.create_task(inventory_monitor_task())
    yield
    # Shutdown: Cancel the background task
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        logger.info("Inventory monitor task cancelled on shutdown.")

app = FastAPI(title="AI Agent Server", lifespan=lifespan)

@app.post("/api/predict")
async def predict_inventory_needs(items: List[InventoryItem]):
    """
    REST endpoint to process inventory data for machine learning inference.
    """
    try:
        logger.info(f"Received prediction request for {len(items)} items.")
        
        predictions = []
        for item in items:
            # Placeholder scaffolding for ML inference logic
            # E.g., computing risk score based on burn rate, lead time, etc.
            risk_score = 0.0
            
            # Simple heuristic mock
            if item.stockLevel < item.reorderThreshold * 1.2:
                risk_score = 0.85
            elif item.stockLevel < item.reorderThreshold * 2:
                risk_score = 0.45
            else:
                risk_score = 0.10
                
            predictions.append({
                "sku": item.sku,
                "riskScore": risk_score,
                "recommendedAction": "Reorder" if risk_score > 0.8 else "Monitor"
            })
            
        logger.info("Successfully processed predictions.")
        return {"status": "success", "predictions": predictions}
        
    except Exception as e:
        logger.error(f"Error during prediction: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error during prediction.")

if __name__ == "__main__":
    import uvicorn
    # Run the server on port 8000 (different from backend on 5158)
    uvicorn.run("agent_server:app", host="0.0.0.0", port=8000, reload=True)
