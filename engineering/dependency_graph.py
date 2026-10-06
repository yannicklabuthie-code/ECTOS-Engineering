from __future__ import annotations
import argparse, json
from pathlib import Path
from typing import Any

SCHEMA_ID = "ECTOS_PACKAGE_DEPENDENCY_GRAPH_V01"
ZERO_COUNTERS = (
    "undeclared_dependency_count",
    "unresolved_transitive_dependency_count",
    "untested_dependency_count",
    "implicit_environment_assumption_count",
    "unknown_blast_radius_edge_count",
)
REQUIRED_NODE_FIELDS = ("dependency_id","type","name","currentness","physical_evidence","test_coverage","fail_closed_behavior","impact_if_changed")
REQUIRED_EDGE_FIELDS = ("edge_id","from","to","type","direct_or_transitive","required_by","contract","currentness","physical_evidence","test_coverage","fail_closed_behavior","status")
ALLOWED_NODE_TYPES = {"PACKAGE","ENGINE","SOURCE_FILE","MODULE","CALL_IMPORT","WORKFLOW","TEST","FIXTURE","CONFIGURATION","ENVIRONMENT","OS_RUNTIME","PROCESS","STATE","REGISTRY","AUTHORITY","UAC","HANDOFF","OUTPUT_ARTIFACT","EXTERNAL_SERVICE","REPOSITORY","OTHER"}
ALLOWED_EDGE_TYPES = {"DEPENDS_ON","CALLS","IMPORTS","LOADS","REQUIRES","GENERATES","VALIDATES","ROUTES_TO","CONSUMES","PRODUCES","BINDS","EXECUTES_ON","READS_STATE","WRITES_STATE","GUARDED_BY","QUALIFIED_BY","HANDS_OFF_TO","AGGREGATES","OTHER"}
ALLOWED_CURRENTNESS = {"CURRENT","HISTORICAL","SUPERSEDED","NOT_PROVEN"}
ALLOWED_EDGE_STATUS = {"RESOLVED","UNRESOLVED","NOT_PROVEN"}
ALLOWED_DIRECTNESS = {"DIRECT","TRANSITIVE"}

def load_graph(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))

def validate_graph(graph: dict[str, Any]) -> dict[str, Any]:
    errors: list[str] = []
    if graph.get("schema_id") != SCHEMA_ID: errors.append("SCHEMA_ID_INVALID")
    package = graph.get("package") if isinstance(graph.get("package"), dict) else {}
    if not package: errors.append("PACKAGE_OBJECT_MISSING")
    for key in ("package_id","package_name","version","environment","producer"):
        if not package.get(key): errors.append(f"PACKAGE_FIELD_MISSING:{key}")
    nodes = graph.get("nodes") if isinstance(graph.get("nodes"), list) else []
    if not nodes: errors.append("NODES_MISSING")
    node_ids: list[str] = []
    for i,node in enumerate(nodes):
        if not isinstance(node, dict): errors.append(f"NODE_INVALID:{i}"); continue
        for key in REQUIRED_NODE_FIELDS:
            if key not in node or node.get(key) in ("",None): errors.append(f"NODE_FIELD_MISSING:{i}:{key}")
        dep_id = node.get("dependency_id")
        if dep_id: node_ids.append(dep_id)
        if node.get("type") not in ALLOWED_NODE_TYPES: errors.append(f"NODE_TYPE_INVALID:{dep_id or i}:{node.get('type')}")
        if node.get("currentness") not in ALLOWED_CURRENTNESS: errors.append(f"NODE_CURRENTNESS_INVALID:{dep_id or i}:{node.get('currentness')}")
        elif node.get("currentness") != "CURRENT": errors.append(f"NODE_CURRENTNESS_NOT_CURRENT:{dep_id or i}:{node.get('currentness')}")
    if len(node_ids) != len(set(node_ids)): errors.append("DUPLICATE_DEPENDENCY_ID")
    edges = graph.get("edges") if isinstance(graph.get("edges"), list) else []
    edge_ids: list[str] = []; known_nodes = set(node_ids)
    for i,edge in enumerate(edges):
        if not isinstance(edge, dict): errors.append(f"EDGE_INVALID:{i}"); continue
        for key in REQUIRED_EDGE_FIELDS:
            if key not in edge or edge.get(key) in ("",None): errors.append(f"EDGE_FIELD_MISSING:{i}:{key}")
        edge_id = edge.get("edge_id")
        if edge_id: edge_ids.append(edge_id)
        if edge.get("type") not in ALLOWED_EDGE_TYPES: errors.append(f"EDGE_TYPE_INVALID:{edge_id or i}:{edge.get('type')}")
        if edge.get("direct_or_transitive") not in ALLOWED_DIRECTNESS: errors.append(f"EDGE_DIRECTNESS_INVALID:{edge_id or i}:{edge.get('direct_or_transitive')}")
        if edge.get("from") not in known_nodes: errors.append(f"DANGLING_EDGE_FROM:{edge_id or i}")
        if edge.get("to") not in known_nodes: errors.append(f"DANGLING_EDGE_TO:{edge_id or i}")
        if edge.get("status") not in ALLOWED_EDGE_STATUS: errors.append(f"EDGE_STATUS_INVALID:{edge_id or i}:{edge.get('status')}")
        elif edge.get("status") != "RESOLVED": errors.append(f"EDGE_NOT_RESOLVED:{edge_id or i}")
        if edge.get("currentness") not in ALLOWED_CURRENTNESS: errors.append(f"EDGE_CURRENTNESS_INVALID:{edge_id or i}:{edge.get('currentness')}")
        elif edge.get("currentness") != "CURRENT": errors.append(f"EDGE_CURRENTNESS_NOT_CURRENT:{edge_id or i}:{edge.get('currentness')}")
    if len(edge_ids) != len(set(edge_ids)): errors.append("DUPLICATE_EDGE_ID")
    closure = graph.get("closure") if isinstance(graph.get("closure"), dict) else {}
    if not closure: errors.append("CLOSURE_MISSING")
    for key in ZERO_COUNTERS:
        value = closure.get(key)
        if not isinstance(value, int) or value < 0: errors.append(f"CLOSURE_COUNTER_INVALID:{key}")
        elif value != 0: errors.append(f"CLOSURE_COUNTER_NONZERO:{key}={value}")
    if closure.get("dependency_closure") != "PASS": errors.append("DEPENDENCY_CLOSURE_NOT_PASS")
    impact = graph.get("change_impact") if isinstance(graph.get("change_impact"), dict) else {}
    if not impact: errors.append("CHANGE_IMPACT_MISSING")
    elif impact.get("analysis_status") not in ("PASS","NOT_APPLICABLE"): errors.append("CHANGE_IMPACT_NOT_CLOSED")
    for dep_id in list(impact.get("changed_dependency_ids",[])) + list(impact.get("impacted_dependency_ids",[])):
        if dep_id not in known_nodes: errors.append(f"CHANGE_IMPACT_UNKNOWN_NODE:{dep_id}")
    return {"schema_id":"ECTOS_DEPENDENCY_GRAPH_VALIDATION_RESULT_V01","status":"PASS" if not errors else "FAIL","error_count":len(errors),"errors":errors,"package_id":package.get("package_id"),"node_count":len(nodes),"edge_count":len(edges)}

def aggregate_graphs(paths: list[Path], environment: str) -> dict[str, Any]:
    results=[]; packages=[]; nodes=[]; edges=[]
    for path in paths:
        graph=load_graph(path); result=validate_graph(graph); results.append({"path":str(path),**result})
        pkg=graph.get("package") if isinstance(graph.get("package"),dict) else {}
        if pkg:
            pkg_view=dict(pkg); pkg_view["dependency_graph_status"]=result["status"]; packages.append(pkg_view)
            prefix=(pkg.get("package_id") or path.stem)+"::"
            for node in graph.get("nodes",[]):
                if isinstance(node,dict) and node.get("dependency_id"):
                    n=dict(node); n["dependency_id"]=prefix+node["dependency_id"]; nodes.append(n)
            for edge in graph.get("edges",[]):
                if isinstance(edge,dict) and edge.get("edge_id"):
                    e=dict(edge); e["edge_id"]=prefix+edge["edge_id"]
                    if edge.get("from"): e["from"]=prefix+edge["from"]
                    if edge.get("to"): e["to"]=prefix+edge["to"]
                    edges.append(e)
    return {"schema_id":"ECTOS_ENVIRONMENT_DEPENDENCY_GRAPH_V01","environment":environment,"package_count":len(packages),"package_validation_results":results,"packages":packages,"nodes":nodes,"edges":edges,"status":"PASS" if results and all(x["status"]=="PASS" for x in results) else "FAIL"}

def main() -> int:
    p=argparse.ArgumentParser(); sub=p.add_subparsers(dest="cmd",required=True)
    v=sub.add_parser("validate"); v.add_argument("graph")
    a=sub.add_parser("aggregate"); a.add_argument("--environment",required=True); a.add_argument("--output",required=True); a.add_argument("graphs",nargs="+")
    args=p.parse_args()
    if args.cmd=="validate":
        result=validate_graph(load_graph(Path(args.graph))); print(json.dumps(result,indent=2,sort_keys=True)); return 0 if result["status"]=="PASS" else 40
    out=aggregate_graphs([Path(x) for x in args.graphs],args.environment); Path(args.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n",encoding="utf-8"); print(json.dumps({"status":out["status"],"package_count":out["package_count"],"output":args.output},indent=2)); return 0 if out["status"]=="PASS" else 40

if __name__ == "__main__": raise SystemExit(main())
