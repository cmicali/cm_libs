"""Prints the pass and fail counts of an xcresult's tests, then each failure's
messages, and exits 1 on a failure. make test passes -quiet to xcodebuild, so
CI's log has a failure's messages only from here.

Usage: python3 -I scripts/checks/test-summary.py <path to .xcresult>
"""
import json
import subprocess
import sys

out = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", sys.argv[1]],
                     check=True, capture_output=True, text=True).stdout
d = json.loads(out)
print("%s: %d passed, %d failed, %d skipped" % (d["result"], d["passedTests"], d["failedTests"], d["skippedTests"]))
for failure in d.get("testFailures", []):
    print("\n%s/%s:\n%s" % (failure["targetName"], failure.get("testIdentifierString") or failure["testName"],
                            failure.get("failureText") or "no message"))
sys.exit(0 if d["failedTests"] == 0 else 1)
