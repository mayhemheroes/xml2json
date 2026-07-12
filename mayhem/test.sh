#!/usr/bin/env bash
#
# mayhem/test.sh — RUN xml2json's upstream test suite (test/test.cpp, built by mayhem/build.sh
# as /mayhem/xml2json_test) and assert its OUTPUT against upstream's committed golden files.
#
# Upstream's suite converts test/test_track_{1,2,3}.xml and writes test_track_N.js.txt
# (BOM + JSON). Upstream commits the expected outputs (test/test_track_N.js.txt), so each
# track is a known-answer test: the freshly generated file must be byte-identical to the
# committed golden. A neutered/exit(0) program produces no/empty output and FAILS.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

RUNNER="$SRC/xml2json_test"
if [ ! -x "$RUNNER" ]; then
  echo "FATAL: $RUNNER missing — mayhem/build.sh must build the test suite" >&2
  emit_ctrf "xml2json-upstream-suite" 0 1
  exit 1
fi

# The runner reads its fixtures from CWD and writes generated outputs to CWD — run it in a
# /tmp scratch dir (never write into the image tree) seeded with the upstream XML fixtures.
WORK="$(mktemp -d /tmp/xml2json-test.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cp "$SRC"/test/test_track_1.xml "$SRC"/test/test_track_2.xml "$SRC"/test/test_track_3.xml "$WORK"/
( cd "$WORK" && "$RUNNER" ); rc=$?

passed=0; failed=0
for i in 1 2 3; do
  if [ "$rc" -eq 0 ] && cmp -s "$WORK/test_track_$i.js.txt" "$SRC/test/test_track_$i.js.txt"; then
    echo "PASS track $i: generated output matches upstream golden test/test_track_$i.js.txt"
    passed=$((passed+1))
  else
    echo "FAIL track $i: generated output differs from upstream golden (or runner failed, rc=$rc)"
    failed=$((failed+1))
  fi
done

# test/windows_style_results/ are Windows-CRLF variants of the same goldens (informational,
# not runnable on Linux) — skipped, counted as such.
emit_ctrf "xml2json-upstream-suite" "$passed" "$failed" 3
