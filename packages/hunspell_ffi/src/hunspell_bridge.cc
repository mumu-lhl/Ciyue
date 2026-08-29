#include "hunspell_bridge.h"

#include <cstring>
#include <limits>
#include <vector>

#include "hunspell.h"

namespace {

using ResultFunction = int (*)(Hunhandle*, char***, const char*);

int32_t copyResults(
    Hunhandle* handle,
    const char* word,
    uint8_t* output,
    int32_t outputCapacity,
    ResultFunction function) {
  if (handle == nullptr || word == nullptr || outputCapacity < 0) {
    return -1;
  }

  char** results = nullptr;
  int count = 0;
  try {
    count = function(handle, &results, word);
  } catch (...) {
    return -1;
  }

  if (count <= 0 || results == nullptr) {
    if (results != nullptr) {
      Hunspell_free_list(handle, &results, count);
    }
    return 0;
  }

  size_t required = 1;  // The extra final NUL terminator.
  for (int i = 0; i < count; ++i) {
    if (results[i] == nullptr) {
      continue;
    }
    required += std::strlen(results[i]) + 1;
  }

  const bool sizeFitsInt32 =
      required <= static_cast<size_t>(std::numeric_limits<int32_t>::max());
  if (!sizeFitsInt32) {
    Hunspell_free_list(handle, &results, count);
    return -1;
  }

  const int32_t requiredBytes = static_cast<int32_t>(required);
  if (output != nullptr && outputCapacity >= requiredBytes) {
    size_t offset = 0;
    for (int i = 0; i < count; ++i) {
      if (results[i] == nullptr) {
        continue;
      }
      const size_t length = std::strlen(results[i]);
      std::memcpy(output + offset, results[i], length);
      offset += length;
      output[offset++] = 0;
    }
    output[offset] = 0;
  }

  Hunspell_free_list(handle, &results, count);
  return requiredBytes;
}

}  // namespace

CIYUE_HUNSPELL_EXPORT CiyueHunspellHandle ciyue_hunspell_create(
    const char* affPath,
    const char* dicPath) {
  if (affPath == nullptr || dicPath == nullptr) {
    return nullptr;
  }

  try {
    return Hunspell_create(affPath, dicPath);
  } catch (...) {
    return nullptr;
  }
}

CIYUE_HUNSPELL_EXPORT void ciyue_hunspell_destroy(
    CiyueHunspellHandle handle) {
  if (handle == nullptr) {
    return;
  }

  try {
    Hunspell_destroy(static_cast<Hunhandle*>(handle));
  } catch (...) {
    // Destruction must not allow an exception to cross the C ABI.
  }
}

CIYUE_HUNSPELL_EXPORT int32_t ciyue_hunspell_stem(
    CiyueHunspellHandle handle,
    const char* word,
    uint8_t* output,
    int32_t outputCapacity) {
  return copyResults(
      static_cast<Hunhandle*>(handle),
      word,
      output,
      outputCapacity,
      Hunspell_stem);
}

CIYUE_HUNSPELL_EXPORT int32_t ciyue_hunspell_suggest(
    CiyueHunspellHandle handle,
    const char* word,
    uint8_t* output,
    int32_t outputCapacity) {
  return copyResults(
      static_cast<Hunhandle*>(handle),
      word,
      output,
      outputCapacity,
      Hunspell_suggest);
}
