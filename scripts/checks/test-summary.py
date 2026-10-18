"""Prints the pass and fail counts of an xcresult's tests, and exits 1 on a failure.

Usage: python3 -I scripts/checks/test-summary.py <path to .xcresult>
"""
import json
import subprocess
import sys

out = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", sys.argv[1]],
                     check=True, capture_output=True, text=True).stdout
d = json.loads(out)
print("%s: %d passed, %d failed, %d skipped" % (d["result"], d["passedTests"], d["failedTests"], d["skippedTests"]))
sys.exit(0 if d["failedTests"] == 0 else 1)
