import importlib.util
from pathlib import Path

from ai.graph.workflow import (
    run_workflow,
    approve_and_resume,
    reject_workflow,
    build_workflow_graph,
    WORKFLOW_SESSIONS,
)

_graph_py = Path(__file__).resolve().parent.parent / "graph.py"
if _graph_py.exists():
    _spec = importlib.util.spec_from_file_location("ai._graph_module", _graph_py)
    if _spec and _spec.loader:
        _mod = importlib.util.module_from_spec(_spec)
        _spec.loader.exec_module(_mod)
        run_data_extraction_workflow = getattr(_mod, "run_data_extraction_workflow", None)
        build_manufacturing_workflow = getattr(_mod, "build_manufacturing_workflow", None)


