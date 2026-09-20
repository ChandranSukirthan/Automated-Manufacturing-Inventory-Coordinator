import datetime
import logging
from langchain_core.messages import AIMessage
from ai.state import AgentState

logger = logging.getLogger("amic_agentic_ai.purchasing_node")


def purchasing_node(state: AgentState) -> dict:
    """
    Stage 3: Purchasing Agent Node
    Ingests the structured inventory result from the Data Extraction Agent.
    Prepares procurement options and matched quotes without finalizing without approval.
    """
    extraction = state.get("data_extraction_result") or {}
    mat_id = state.get("target_material_id", "RM001")
    low_stock = extraction.get("lowStock", False)
    req_qty = extraction.get("requiredQuantity", 0.0)

    logger.info(f"[Purchasing Agent] Evaluating replenishment for {mat_id}: low_stock={low_stock}, qty={req_qty}")

    unit_price = 4.50
    est_cost = round(req_qty * unit_price, 2)

    if low_stock and req_qty > 0:
        purchasing_msg = (
            f"Purchasing Agent Proposal:\n"
            f"• Sourced supplier: Apex Industrial Materials (Rank #1 SLA)\n"
            f"• Replenishment Quantity: {req_qty} units @ ${unit_price:.2f}/unit\n"
            f"• Estimated Procurement Total: ${est_cost:,.2f} USD\n"
            f"• Target Delivery Horizon: 3-5 business days"
        )
    else:
        purchasing_msg = f"Purchasing Agent: Stock level is healthy ({extraction.get('currentStock', 0)} units). No procurement required."

    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
    timestamps = state.get("timestamps", {})
    timestamps["purchasing_completed"] = now_iso

    return {
        "current_agent": "Validation",
        "timestamps": timestamps,
        "messages": [AIMessage(content=purchasing_msg, name="PurchasingAgent")]
    }
