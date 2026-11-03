import pathlib,sys,hashlib,json
ROOT=pathlib.Path(r"C:\dev\METAMORPHOSE_G00_EXACT_OFFLINE_20261102")
ZIP=ROOT/"METAMORPHOSE_G00_SYSTEMIC_SUCCESSOR_V01.zip"
TARGET="27e816c70d428fd2feec2e1fc71cd77d9cb1731b4a454fb9abd4f0a3b45c57cf"
OUT=pathlib.Path(__file__).resolve().parents[2]/"evidence-v48"/"windows"/"native-controls"
OUT.mkdir(parents=True,exist_ok=True)
assert hashlib.sha256(ZIP.read_bytes()).hexdigest()==TARGET
sys.path.insert(0,str(ROOT/"source"/"backend"))
from fastapi.testclient import TestClient
from app import main
from app.engines.routing import TargetResolution
from app.adapters.gemini_file_search import GroundedFileSearchResult,RetrievedChunk
class Resolver:
 def __init__(self, ids):self.ids=ids
 def resolve(self,*,question,registered_targets):return TargetResolution("RESOLVED",target_ids=tuple(self.ids))
class Adapter:
 def __init__(self,mode):self.mode=mode;self.calls=[]
 def retrieve_roles(self,*,logical_roles,query):
  self.calls.append(list(logical_roles))
  chunks=[]
  for role in logical_roles:
   ident=main.identity.resolve(main.registry,role)
   md={"source_id":ident["source_id"],"canonical_drive_id":ident["canonical_drive_id"],"physical_register_id":ident["physical_register_id"],"source_domain_sha256":"0"*64 if self.mode=="wrong_sha" else ident["combined_sha256"]}
   chunks.append(RetrievedChunk(logical_role=role,text="Synthetic local evidence "+role,title="Fixture "+role,uri="fileSearchStores/test/documents/test",file_search_store="fileSearchStores/test",metadata=md,provider_citation={"source":"fixture"} if self.mode!="missing_citation" else {}))
  return GroundedFileSearchResult(answer="Synthetic grounded response",chunks=chunks,provider_request_count=1,queried_roles=list(logical_roles))
client=TestClient(main.app)
ids=[x["target_id"] for x in main.registry.active_targets()]
assert len(ids)==9,ids
cases=[]
def run(cid, targetids, mode, http_expected, code_expected, group):
 main.routing.target_resolver=Resolver(targetids)
 a=Adapter(mode)
 main.retrieval.content_adapter=a
 resp=client.post("/execute",json={"query":"controlled windows qualification question","intent":"not-routing","ux_context":"visual-only"})
 body=resp.json()
 code=body.get("status") if resp.status_code==200 else body.get("detail",{}).get("code")
 ok=resp.status_code==http_expected and code==code_expected and len(a.calls)>0
 if resp.status_code==200:
  ev=body.get("evidence_descriptors",[])
  ok=ok and len(body.get("route_plans",[]))==len(targetids) and len(ev)>0 and all(e.get("provider_citation") and e.get("passage") for e in ev)
 cases.append({"control_id":cid,"group":group,"http":resp.status_code,"code":code,"expected_http":http_expected,"expected_code":code_expected,"adapter_called":len(a.calls)>0,"pass":bool(ok)})
# V41 controlled single-control entrypoint, never route approval.
requested=sys.argv[1] if len(sys.argv)>1 else ""
planned=[]
for tid in ids:planned.append(("HTTP_SYNTHETIC_POSITIVE_"+tid,[tid],"valid",200,"PASS_RELEASE","positive_group"))
planned.append(("HTTP_SYNTHETIC_MISSING_PROVIDER_CITATION",[ids[0]],"missing_citation",503,"RUNTIME_ERROR","positive_group"))
planned.append(("HTTP_SYNTHETIC_WRONG_SOURCE_SHA",[ids[0]],"wrong_sha",503,"FILE_SEARCH_LINEAGE_ERROR","positive_group"))
for i,tid in enumerate(ids):
 mode="wrong_sha" if i%2==0 else "missing_citation"
 planned.append(("NEG_"+tid,[tid],mode,503,"FILE_SEARCH_LINEAGE_ERROR" if mode=="wrong_sha" else "RUNTIME_ERROR","negative_group"))
for mode in ("wrong_sha","missing_citation"):
 planned.append(("NEG_MULTI_"+mode,ids,mode,503,"FILE_SEARCH_LINEAGE_ERROR" if mode=="wrong_sha" else "RUNTIME_ERROR","negative_group"))
selected=[p for p in planned if p[0]==requested]
if len(selected)!=1:
 print("V41_UNKNOWN_CONTROL|"+requested)
 sys.exit(50)
run(*selected[0])
after=hashlib.sha256(ZIP.read_bytes()).hexdigest()
record={"schema":"OMNIGATE_V48_NATIVE_SINGLE_CONTROL_PRODUCER","control_id":requested,"g00_sha256":TARGET,"g00_unchanged":after==TARGET,"python_version":sys.version,"test_count":len(cases),"pass_count":sum(int(x["pass"]) for x in cases),"live_gemini":False,"document_adapter":"SYNTHETIC","native_powershell_qc03_admission":"NOT_PROVEN","independent_qualification":"NOT_PERFORMED","controls":cases}
(OUT/("V41_"+requested+".json")).write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding="utf-8")
if record["pass_count"]!=1 or not record["g00_unchanged"]:
 print("V41_ORACLE_FAILED|"+requested)
 sys.exit(60)
if requested.startswith("NEG_"):
 print("QC03_NEGATIVE_EXPECTED|"+requested+"|HTTP=503|"+cases[0]["code"])
 sys.exit(40)
print("QC03_POSITIVE_EXPECTED|"+requested+"|HTTP="+str(cases[0]["http"])+"|"+cases[0]["code"])
sys.exit(0)