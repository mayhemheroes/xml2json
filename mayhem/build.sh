#!/usr/bin/env bash
#
# mayhem/build.sh — build the xml2json fuzz harness + standalone reproducer + test suite.
#
# xml2json is a header-only C++11 library (include/xml2json.hpp, bundling rapidxml +
# rapidjson); the harness compiles the whole library, so instrumenting the harness TU
# with $SANITIZER_FLAGS instruments the fuzzed code itself.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — it must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
# DWARF must be < 4 (Mayhem triage can't read >=4); clang-19's plain -g emits DWARF-5.
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"
INCLUDES="-I$SRC/include"
CXXSTD="-std=c++11"
# The vendored rapidjson (include/rapidjson) uses the `nullptr + n` lazy-stack idiom
# (internal/stack.h:117) on EVERY conversion, so UBSan's pointer-overflow check aborts on
# every input and makes the target unfuzzable. Relax ONLY that check; ASan and the rest of
# UBSan stay on and halting.
UBSAN_RELAX="-fno-sanitize=pointer-overflow"

# 1+2) Fuzz harness (libFuzzer) — the header-only project is compiled inside the harness TU,
#      sanitized + DWARF-3. $DEBUG_FLAGS goes AFTER $SANITIZER_FLAGS so -gdwarf-3 wins over -g.
$CXX $CXXSTD $INCLUDES $SANITIZER_FLAGS $UBSAN_RELAX $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
    "$SRC/mayhem/fuzz_xml2json.cpp" -o "$SRC/fuzz_xml2json"

# Standalone run-once reproducer (no libFuzzer runtime). Compile the driver as C first so its
# LLVMFuzzerTestOneInput reference keeps C linkage.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o /tmp/standalone_main.o
$CXX $CXXSTD $INCLUDES $SANITIZER_FLAGS $UBSAN_RELAX $DEBUG_FLAGS \
    "$SRC/mayhem/fuzz_xml2json.cpp" /tmp/standalone_main.o -o "$SRC/fuzz_xml2json-standalone"

# 3) Upstream test suite (test/test.cpp — known-answer converter over test/test_track_*.xml),
#    built with the project's NORMAL flags (clean, unsanitized) exactly as upstream's
#    test/Makefile does; mayhem/test.sh only RUNS it.
$CXX $CXXSTD -O3 $INCLUDES $COVERAGE_FLAGS "$SRC/test/test.cpp" -o "$SRC/xml2json_test"

echo "build.sh: OK"
