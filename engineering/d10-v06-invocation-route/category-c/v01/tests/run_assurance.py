import json,unittest
from pathlib import Path
HERE=Path(__file__).resolve().parent
suite=unittest.defaultTestLoader.discover(str(HERE),pattern='test_*.py')
r=unittest.TextTestRunner(verbosity=2).run(suite)
report={'schema_id':'ECTOS_D10_V06_CATEGORY_C_ENGINEERING_TEST_REPORT_V01','tests_run':r.testsRun,'pass_count':r.testsRun-len(r.failures)-len(r.errors)-len(r.skipped),'failure_count':len(r.failures),'error_count':len(r.errors),'skipped_count':len(r.skipped),'status':'PASS' if r.wasSuccessful() else 'FAIL'}
(HERE.parent/'engineering_test_report.json').write_text(json.dumps(report,indent=2,sort_keys=True)+'\n',encoding='utf-8')
print(json.dumps(report,sort_keys=True)); raise SystemExit(0 if r.wasSuccessful() else 1)
