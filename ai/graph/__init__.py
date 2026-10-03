"""Compatibility exports; every workflow uses the canonical graph and state."""
from ai.graph.workflow import (run_workflow, build_workflow_graph, approve_and_resume,
                               reject_workflow, request_revision, get_final_output)

def run_data_extraction_workflow(material_id_or_batch, workflow_id=None):
    result = run_workflow(objective=f"Analyze inventory replenishment for {material_id_or_batch}",
                        workflow_id=workflow_id, material_id=material_id_or_batch)
    result["data_extraction_result"] = result.get("inventory_data", {})
    result["tool_execution_summary"] = [{"tool": name, "status": "SUCCESS"} for name in
        ("get_inventory_levels", "query_inventory_history", "calculate_burn_rate", "detect_low_stock")
        if name in result.get("tool_results", {})]
    return result
