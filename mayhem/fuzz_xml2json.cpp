// libFuzzer harness for xml2json (include/xml2json.hpp).
//
// In-process conversion of the old raw file-input CLI target (`/xml2json @@`):
// the CLI's main() has no exception handling, so under halting sanitizers every
// malformed input aborts via std::terminate before reaching the parser — the
// same xml2json(const char*) code path is driven here directly instead.
//
// rapidxml parses IN-SITU (parse<0> mutates the buffer through a const_cast),
// so the input is copied into a writable, NUL-terminated buffer first.
#include <cstdint>
#include <cstddef>
#include <exception>
#include <string>
#include <vector>

#include "xml2json.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  std::vector<char> buf(data, data + size);
  buf.push_back('\0');
  try {
    std::string json = xml2json(buf.data());
    (void)json;
  } catch (const std::exception &) {
    // rapidxml::parse_error on malformed XML — expected, not a defect.
  }
  return 0;
}
