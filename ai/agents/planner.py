from typing import List, Dict, Any
from ai.core.state import AgentState, WorkflowStatus, ApprovalStatus


# Structured 11-step procurement plan (requirement §1)
PROCUREMENT_PLAN: List[str] = [
    "1. Identify material and validate procurement requirement",
    "2. Retrieve internal inventory, stock, and open PO data",
    "3. Retrieve approved supplier candidates and historical rates",
    "4. Search external market for additional supplier candidates",
    "5. Compare all candidates on price, MOQ, quality, availability, and lead time",
    "6. Validate required quantity against MOQ and pack size",
    "7. Validate estimated total cost against budget limit",
    "8. Validate supplier verification status",
    "9. Validate quality evidence and certifications",
    "10. Prepare structured procurement recommendation",
    "11. Route to Supply Chain Manager for human approval",
]

MAINTENANCE_PLAN: List[str] = [
    "1. Check machine status and uptime telemetry",
    "2. Calculate machine uptime against maintenance interval",
    "3. Check maintenance requirement and overdue status",
    "4. Assess production line schedule impact",
    "5. Prepare maintenance work order",
    "6. Validate technician availability and safety lockout",
    "7. Route to IT Admin for human approval",
]

SCHEDULE_PLAN: List[str] = [
    "1. Query production schedule and shift targets",
    "2. Calculate production impact from material constraints",
    "3. Inspect raw material sufficiency",
    "4. Evaluate machine operational capacities",
    "5. Formulate revised shift targets",
    "6. Validate schedule feasibility",
    "7. Route to Supply Chain Manager for human approval",
]


def _select_plan(objective: str, state: AgentState) -> List[str]:
    """
    Selects the correct structured plan.
    Procurement plan is used when a net_deficit or procurement_requirement is present,
    or when the objective contains procurement-related keywords.
    """
    # Authoritative: if ASP.NET sent a net_deficit, this is a procurement workflow
    if state.get("net_deficit") is not None or state.get("procurement_requirement"):
        return PROCUREMENT_PLAN

    obj_lower = objective.lower()
    if any(k in obj_lower for k in ["procure", "replenish", "material", "stock", "inventory", "raw", "film", "copper", "arduino", "supplier"]):
        return PROCUREMENT_PLAN
    if any(k in obj_lower for k in ["maintenance", "uptime", "overhaul", "repair", "service", "machine"]):
        return MAINTENANCE_PLAN
    if any(k in obj_lower for k in ["schedule", "shift", "capacity", "output", "target"]):
        return SCHEDULE_PLAN
    return PROCUREMENT_PLAN


def planner_node(state: AgentState) -> Dict[str, Any]:
    """
    Planner / Coordinator Agent Node.
    Generates a structured execution plan and initialises procurement context
    from the authoritative ASP.NET Core input fields.
    Does NOT store chain-of-thought — only structured plan steps.
    """
    objective = state.get("objective", "Procure required raw material.")
    plan = _select_plan(objective, state)

    # Promote legacy procurement_requirement fields into top-level state fields
    # so downstream agents always read from canonical locations.
    req = dict(state.get("procurement_requirement") or {})
    updates: Dict[str, Any] = {}

    def _promote(state_key: str, *req_keys: str):
        if state.get(state_key) is None:
            for k in req_keys:
                if req.get(k) is not None:
                    updates[state_key] = req[k]
                    return

    _promote("material_id", "materialId", "material_id")
    _promote("material_name", "materialName", "material_name", "material")
    _promote("current_stock", "currentStock", "current_stock")
    _promote("required_quantity", "requiredQuantity", "required_quantity", "productionRequirement")
    _promote("safety_stock", "safetyStock", "safety_stock")
    _promote("open_po_quantity", "openPOQuantity", "open_po_quantity", "existingOpenPoQuantity")
    _promote("net_deficit", "netDeficit", "net_deficit")
    _promote("budget_limit", "budgetLimit", "maximumBudget", "budget_limit", "maximumBudget")
    _promote("unit", "unit")
    _promote("quality_requirement", "qualityRequirement", "quality_requirement")
    _promote("preferred_region", "preferredRegion", "preferred_region")
    _promote("required_by_date", "requiredByDate", "required_by_date")
    _promote("specification", "requiredSpecification", "specification")

    # If material_name was not provided, infer from objective
    if not updates.get("material_name") and not state.get("material_name"):
        obj_lower = objective.lower()
        if "boxpouch" in obj_lower or "film" in obj_lower:
            updates["material_name"] = "BoxPouch Film"
            updates["specification"] = "BP-FILM-001"
        elif "copper" in obj_lower:
            updates["material_name"] = "Copper Wire"
            updates["specification"] = "CW-100"
        elif "arduino" in obj_lower:
            updates["material_name"] = "Arduino UNO R3"
            updates["specification"] = "MCU-UNO-R3"

    # If net_deficit was not provided, infer default for replenishment objectives
    if updates.get("net_deficit") is None and state.get("net_deficit") is None:
        obj_lower = objective.lower()
        if any(w in obj_lower for w in ["replenish", "procure", "low", "shortage", "reorder", "purchase"]):
            updates["net_deficit"] = 1000.0
            if updates.get("required_quantity") is None and state.get("required_quantity") is None:
                updates["required_quantity"] = 1000.0
            if updates.get("budget_limit") is None and state.get("budget_limit") is None:
                updates["budget_limit"] = 20000.0

    completed = list(state.get("completed_steps") or [])
    completed.append("Planner: Generated structured execution plan")

    return {
        **updates,
        "plan": plan,
        "current_agent": "Planner",
        "status": WorkflowStatus.Running,
        "approval_status": state.get("approval_status") or ApprovalStatus.Pending,
        "completed_steps": completed,
        "errors": list(state.get("errors") or []),
    }
