#ifndef CIYUE_HUNSPELL_BRIDGE_H_
#define CIYUE_HUNSPELL_BRIDGE_H_

#include <stdint.h>

#if defined(_WIN32)
#define CIYUE_HUNSPELL_EXPORT __declspec(dllexport)
#else
#define CIYUE_HUNSPELL_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void* CiyueHunspellHandle;

CIYUE_HUNSPELL_EXPORT CiyueHunspellHandle ciyue_hunspell_create(
    const char* aff_path,
    const char* dic_path);

CIYUE_HUNSPELL_EXPORT void ciyue_hunspell_destroy(
    CiyueHunspellHandle handle);

// Returns the number of bytes required for the NUL-separated result. The
// result has one NUL terminator after every word and one additional NUL at the
// end. Returns 0 when Hunspell produced no results, or -1 on invalid input or
// an internal error.
CIYUE_HUNSPELL_EXPORT int32_t ciyue_hunspell_stem(
    CiyueHunspellHandle handle,
    const char* word,
    uint8_t* output,
    int32_t output_capacity);

CIYUE_HUNSPELL_EXPORT int32_t ciyue_hunspell_suggest(
    CiyueHunspellHandle handle,
    const char* word,
    uint8_t* output,
    int32_t output_capacity);

#ifdef __cplusplus
}
#endif

#endif
