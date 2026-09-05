// SPDX-License-Identifier: MIT
#pragma once

#include <cstdlib>
#include <dlfcn.h>
#include <glib.h>

namespace WebKit {

// Resolve from libWPEWebKit, not the executable, cwd, or an AppImage mount name.
// Internal linkage is intentional: dladdr must identify this DSO, rather than
// an interposed symbol in the application. Keep the result for process lifetime.
static const char* wpeRuntimeDirectory()
{
    static const char* directory = []() -> const char* {
        Dl_info info { };
        if (!dladdr(reinterpret_cast<void*>(&wpeRuntimeDirectory), &info) || !info.dli_fname)
            g_error("Cannot locate the WPE WebKit shared library");
        char* library = realpath(info.dli_fname, nullptr);
        if (!library)
            g_error("Cannot resolve the WPE WebKit shared library: %s", info.dli_fname);
        char* parent = g_path_get_dirname(library);
        free(library);
        char* runtime = g_build_filename(parent, "wpe-webkit-2.0", nullptr);
        g_free(parent);
        return runtime;
    }();
    return directory;
}

} // namespace WebKit
