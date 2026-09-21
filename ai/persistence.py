import datetime
import json
import logging
import threading
from typing import Dict, Any, List, Optional
from ai.state import AgentState

logger = logging.getLogger("amic_agentic_ai.persistence")


class WorkflowStateRepository:
    """
    Persists workflow state through the AgentWorkflow mechanism.
    Stores:
    - workflow ID
    - inventory result
    - tool execution summary
    - low-stock result
    - timestamps
    - errors
    CRITICAL: Does NOT store hidden chain-of-thought or raw internal reasoning tokens.
    """

    def __init__(self):
        self._lock = threading.Lock()
        self._store: Dict[str, Dict[str, Any]] = {}

    def save_workflow(self, state: AgentState) -> Dict[str, Any]:
        """Sanitizes and saves workflow execution record."""
        wf_id = state.get("workflow_id") or f"WF-{datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')}"
        mat_id = state.get("target_material_id") or state.get("target_batch") or "RM001"

        # Explicitly extract ONLY permitted fields — NEVER store hidden chain-of-thought
        inventory_res = state.get("data_extraction_result") or state.get("inventory_result")
        low_stock_res = state.get("low_stock_data")
        tool_summary = state.get("tool_execution_summary", [])
        timestamps = state.get("timestamps", {})
        errors = state.get("errors", [])
        status = "Completed" if state.get("human_approval_status") == "APPROVED" else "WaitingForApproval" if state.get("requires_human_approval") else "Active"

        record = {
            "workflowId": wf_id,
            "materialId": mat_id,
            "currentAgent": state.get("current_agent", "Validation"),
            "status": status,
            "requiresHumanApproval": state.get("requires_human_approval", False),
            "humanApprovalStatus": state.get("human_approval_status", "PENDING"),
            "finalDecision": state.get("final_decision", ""),
            "inventoryResult": inventory_res,
            "lowStockResult": low_stock_res,
            "toolExecutionSummary": tool_summary,
            "timestamps": timestamps,
            "errors": errors,
            "savedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        }

        with self._lock:
            self._store[wf_id] = record

        logger.info(f"[Persistence] Successfully stored workflow record: {wf_id} (No chain-of-thought stored)")
        return record

    def get_workflow(self, workflow_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve stored workflow by ID."""
        with self._lock:
            return self._store.get(workflow_id)

    def list_workflows(self) -> List[Dict[str, Any]]:
        """List all persisted workflow records."""
        with self._lock:
            return list(self._store.values())

    def clear(self):
        """Reset repository store (used in testing)."""
        with self._lock:
            self._store.clear()


# Global shared singleton repository
workflow_repo = WorkflowStateRepository()
