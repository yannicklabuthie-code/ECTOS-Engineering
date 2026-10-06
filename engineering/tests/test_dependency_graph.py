import json, tempfile, unittest, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "engineering"))
from dependency_graph import validate_graph, aggregate_graphs

def valid_graph():
    return {
        "schema_id":"ECTOS_PACKAGE_DEPENDENCY_GRAPH_V01",
        "package":{"package_id":"PKG","package_name":"pkg.zip","version":"V01","package_sha256":None,"environment":"ECTOS_DEV","producer":"TEST","source_repository":None,"source_commit":None},
        "nodes":[
            {"dependency_id":"PKG","type":"PACKAGE","name":"pkg.zip","locator":None,"currentness":"CURRENT","physical_evidence":"fixture","test_coverage":"validator","fail_closed_behavior":"deny","impact_if_changed":"full revalidation","external_ref":None},
            {"dependency_id":"RUNTIME","type":"OS_RUNTIME","name":"Windows PowerShell 5.1","locator":None,"currentness":"CURRENT","physical_evidence":"runtime contract","test_coverage":"native gate","fail_closed_behavior":"deny","impact_if_changed":"native qualification","external_ref":None}
        ],
        "edges":[{"edge_id":"E1","from":"PKG","to":"RUNTIME","type":"EXECUTES_ON","direct_or_transitive":"DIRECT","required_by":"entrypoint","contract":"native runtime","currentness":"CURRENT","physical_evidence":"manifest","test_coverage":"native gate","fail_closed_behavior":"deny","status":"RESOLVED"}],
        "closure":{"dependency_closure":"PASS","undeclared_dependency_count":0,"unresolved_transitive_dependency_count":0,"untested_dependency_count":0,"implicit_environment_assumption_count":0,"unknown_blast_radius_edge_count":0},
        "change_impact":{"predecessor_package_sha256":None,"changed_dependency_ids":[],"impacted_dependency_ids":[],"analysis_status":"NOT_APPLICABLE"}
    }

class DependencyGraphTests(unittest.TestCase):
    def test_valid_graph_passes(self): self.assertEqual(validate_graph(valid_graph())["status"], "PASS")
    def test_nonzero_closure_counter_fails(self):
        g=valid_graph(); g["closure"]["implicit_environment_assumption_count"]=1
        self.assertEqual(validate_graph(g)["status"], "FAIL")
    def test_dangling_edge_fails(self):
        g=valid_graph(); g["edges"][0]["to"]="UNKNOWN"
        self.assertEqual(validate_graph(g)["status"], "FAIL")
    def test_not_proven_node_fails(self):
        g=valid_graph(); g["nodes"][1]["currentness"]="NOT_PROVEN"
        self.assertEqual(validate_graph(g)["status"], "FAIL")
    def test_superseded_node_fails(self):
        g=valid_graph(); g["nodes"][1]["currentness"]="SUPERSEDED"
        self.assertEqual(validate_graph(g)["status"], "FAIL")
    def test_superseded_edge_fails(self):
        g=valid_graph(); g["edges"][0]["currentness"]="SUPERSEDED"
        self.assertEqual(validate_graph(g)["status"], "FAIL")
    def test_invalid_node_type_fails(self):
        g=valid_graph(); g["nodes"][1]["type"]="FREE_FORM_TYPE"
        self.assertEqual(validate_graph(g)["status"], "FAIL")
    def test_invalid_edge_type_fails(self):
        g=valid_graph(); g["edges"][0]["type"]="FREE_FORM_EDGE"
        self.assertEqual(validate_graph(g)["status"], "FAIL")
    def test_aggregate_preserves_packages(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/"g.json"; p.write_text(json.dumps(valid_graph()),encoding="utf-8")
            out=aggregate_graphs([p],"ECTOS_DEV")
            self.assertEqual(out["status"],"PASS"); self.assertEqual(out["package_count"],1)


    def test_aggregate_keeps_failed_package_visible(self):
        g=valid_graph(); g["closure"]["undeclared_dependency_count"]=1
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/"failed.json"; p.write_text(json.dumps(g),encoding="utf-8")
            out=aggregate_graphs([p],"ECTOS_DEV")
        self.assertEqual(out["status"],"FAIL")
        self.assertEqual(out["package_count"],1)
        self.assertEqual(out["packages"][0]["dependency_graph_status"],"FAIL")
        self.assertGreater(len(out["nodes"]),0)

if __name__ == "__main__": unittest.main()
