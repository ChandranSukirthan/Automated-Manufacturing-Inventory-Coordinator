"""Compatibility exports; every workflow uses the canonical graph and state."""
from ai.graph.workflow import (run_workflow, build_workflow_graph, approve_and_resume,
                               reject_workflow, request_revision, get_final_output)

def run_data_extraction_workflow(material_id_or_batch, workflow_id=None):
    import uuid
    from ai.graph.workflow import _record_stage, data_extraction_node, WORKFLOW_SESSIONS
    from ai.core.state import WorkflowStatus
    result = {"workflow_id": workflow_id or f"WF-{uuid.uuid4().hex}",
              "objective": f"Analyze inventory for {material_id_or_batch}",
              "material_id": material_id_or_batch, "workflow_type": "InventoryAnalysis",
              "inventory_data": {}, "tool_results": {}, "completed_steps": [],
              "errors": [], "status": WorkflowStatus.Running}
    result.update(_record_stage(data_extraction_node)(result))
    if result.get("status") != WorkflowStatus.Failed:
        result["status"] = WorkflowStatus.Completed
    WORKFLOW_SESSIONS[result["workflow_id"]] = result
    result["data_extraction_result"] = result.get("inventory_data", {})
    result["tool_execution_summary"] = [{"tool": name, "status": "SUCCESS"} for name in
        ("get_inventory_levels", "query_inventory_history", "calculate_burn_rate", "detect_low_stock")
        if name in result.get("tool_results", {})]
    return result
