// Utility to detect if software rendering should be used
// This checks for VM environments where DMA-BUF/GPU acceleration may not work properly

#include "software_rendering.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <glob.h>
#include <mutex>
#include <string>
#include <unistd.h>

#include "log.h"

namespace flutter_inappwebview_plugin {

namespace {

// Check if we're running in a virtual machine by reading system files.
// This is a standard approach used by systemd-detect-virt, virt-what, etc.
// These files are readable by any process and contain only hardware ID info.
bool IsRunningInVirtualMachine() {
  // Known VM product name indicators
  const char* vm_indicators[] = {
    "QEMU", "KVM", "VMware", "VirtualBox", "Parallels", "Xen",
    "Microsoft Virtual", "Hyper-V", "UTM", "Virtual Machine",
    "Bochs", "innotek", "Oracle", nullptr
  };
  
  // Check /sys/class/dmi/id/product_name
  FILE* f = fopen("/sys/class/dmi/id/product_name", "r");
  if (f) {
    char buf[256] = {0};
    if (fgets(buf, sizeof(buf), f)) {
      fclose(f);
      for (const char** indicator = vm_indicators; *indicator; indicator++) {
        if (strcasestr(buf, *indicator)) {
          debugLog("VM detected via product_name: " + std::string(buf));
          return true;
        }
      }
    } else {
      fclose(f);
    }
  }
  
  // Check /sys/class/dmi/id/sys_vendor
  f = fopen("/sys/class/dmi/id/sys_vendor", "r");
  if (f) {
    char buf[256] = {0};
    if (fgets(buf, sizeof(buf), f)) {
      fclose(f);
      for (const char** indicator = vm_indicators; *indicator; indicator++) {
        if (strcasestr(buf, *indicator)) {
          debugLog("VM detected via sys_vendor: " + std::string(buf));
          return true;
        }
      }
    } else {
      fclose(f);
    }
  }
  
  // Check /proc/cpuinfo for hypervisor flag (x86/x64)
  f = fopen("/proc/cpuinfo", "r");
  if (f) {
    char line[512];
    while (fgets(line, sizeof(line), f)) {
      if (strstr(line, "flags") && strstr(line, "hypervisor")) {
        fclose(f);
        debugLog("VM detected via hypervisor CPU flag");
        return true;
      }
    }
    fclose(f);
  }
  
  return false;
}

// Check if we have a known good GPU driver that works well with DMA-BUF
bool HasKnownGoodGpuDriver() {
  const char* dri_paths[] = {
    "/sys/class/drm/card0/device/driver",
    "/sys/class/drm/renderD128/device/driver",
    nullptr
  };
  
  // Known good drivers that work well with DMA-BUF
  const char* good_drivers[] = {
    "nvidia",   // Nvidia proprietary driver
    "nouveau",  // Nvidia open-source driver
    "amdgpu",   // AMD GPU driver
    "radeon",   // Older AMD driver
    "i915",     // Intel integrated graphics
    "xe",       // Intel Xe graphics (newer)
    nullptr
  };
  
  for (const char** path = dri_paths; *path; path++) {
    char link_target[256] = {0};
    ssize_t len = readlink(*path, link_target, sizeof(link_target) - 1);
    if (len > 0) {
      link_target[len] = '\0';
      for (const char** driver = good_drivers; *driver; driver++) {
        if (strstr(link_target, *driver)) {
          debugLog("Known good GPU driver detected: " + std::string(link_target));
          return true;
        }
      }
    }
  }
  
  return false;
}

// Check if the GPU driver is known to have DMA-BUF issues
bool HasProblematicGpuDriver() {
  // If we have a known good driver, it's not problematic
  if (HasKnownGoodGpuDriver()) {
    return false;
  }
  
  const char* dri_paths[] = {
    "/sys/class/drm/card0/device/driver",
    "/sys/class/drm/renderD128/device/driver",
    nullptr
  };
  
  for (const char** path = dri_paths; *path; path++) {
    char link_target[256] = {0};
    ssize_t len = readlink(*path, link_target, sizeof(link_target) - 1);
    if (len > 0) {
      link_target[len] = '\0';
      // virtio-gpu and vmwgfx have known issues in VMs
      if (strstr(link_target, "virtio") || strstr(link_target, "vmwgfx")) {
        debugLog("Problematic GPU driver detected: " + std::string(link_target));
        return true;
      }
    }
  }
  
  return false;
}

// Check if an accessible DRM render or card device exists
bool HasAccessibleDrmNode() {
  glob_t glob_res;
  bool found = false;
  if (glob("/dev/dri/renderD*", 0, nullptr, &glob_res) == 0) {
    for (size_t i = 0; i < glob_res.gl_pathc; ++i) {
      if (access(glob_res.gl_pathv[i], R_OK | W_OK) == 0) {
        found = true;
        break;
      }
    }
    globfree(&glob_res);
  }
  if (!found && glob("/dev/dri/card*", 0, nullptr, &glob_res) == 0) {
    for (size_t i = 0; i < glob_res.gl_pathc; ++i) {
      if (access(glob_res.gl_pathv[i], R_OK | W_OK) == 0) {
        found = true;
        break;
      }
    }
    globfree(&glob_res);
  }
  return found;
}

}  // namespace

namespace {

RenderingMode DetectRenderingMode() {
  // Explicit escape hatch: try the hardware EGL zero-copy path and skip every
  // heuristic below.
  const char* skip_check = getenv("FLUTTER_INAPPWEBVIEW_SKIP_DMABUF_CHECK");
  if (skip_check != nullptr &&
      (strcmp(skip_check, "1") == 0 || strcasecmp(skip_check, "true") == 0)) {
    debugLog("SKIP_DMABUF_CHECK set, forcing hardware EGL rendering");
    return RenderingMode::kHardwareEgl;
  }

  // The host application asked for the software pixel-buffer texture. Its
  // texture type and the WebProcess buffer type are chosen independently, so
  // this is also a request to make the WebProcess export SHM. Ignoring it
  // leaves the host dropping every DMA-BUF frame: a blank WebView whose DOM is
  // still alive.
  if (getenv("FLUTTER_INAPPWEBVIEW_LINUX_DISABLE_GL") != nullptr) {
    debugLog("DISABLE_GL set, using SHM rendering");
    return RenderingMode::kSoftwareShm;
  }

  // The launcher sets this when no DRM device is accessible. The WebProcess
  // will export SHM frames, so the host has to use the pixel-buffer texture.
  // Honouring it here is what keeps the launcher and the plugin from
  // disagreeing about the mode.
  if (getenv("WEBKIT_DISABLE_DMABUF_RENDERER") != nullptr) {
    debugLog("WEBKIT_DISABLE_DMABUF_RENDERER already set, using SHM rendering");
    return RenderingMode::kSoftwareShm;
  }

  // Honour an explicit user override, but never set this ourselves: it is a
  // process-wide Mesa switch that also affects Flutter's own GL renderer.
  const char* already_sw = getenv("LIBGL_ALWAYS_SOFTWARE");
  if (already_sw != nullptr &&
      (strcmp(already_sw, "1") == 0 || strcasecmp(already_sw, "true") == 0)) {
    debugLog("LIBGL_ALWAYS_SOFTWARE was set by the user; using SHM rendering");
    return RenderingMode::kSoftwareShm;
  }

  // If no accessible DRM device exists, hardware acceleration is impossible.
  if (!HasAccessibleDrmNode()) {
    debugLog("No accessible DRM node found in /dev/dri, using SHM rendering");
    return RenderingMode::kSoftwareShm;
  }

  // If we have a known good GPU driver, use hardware rendering.
  if (HasKnownGoodGpuDriver()) {
    debugLog("Known good GPU driver found, using hardware rendering");
    return RenderingMode::kHardwareEgl;
  }

  // Detect VM environment.
  if (IsRunningInVirtualMachine()) {
    debugLog("Virtual machine detected, using SHM rendering");
    return RenderingMode::kSoftwareShm;
  }

  // Some VMs hide the hypervisor from DMI and cpuinfo (e.g. VirGL with a
  // custom SMBIOS), but their virtio-gpu/vmwgfx driver still cannot produce
  // usable DMA-BUF frames. This used to be gated on in_vm as well, which made
  // the check unreachable: the branch above already returned for every VM.
  if (HasProblematicGpuDriver()) {
    debugLog("Problematic GPU driver detected, using SHM rendering");
    return RenderingMode::kSoftwareShm;
  }

  return RenderingMode::kHardwareEgl;
}

void ApplyRenderingModeEnvironment(RenderingMode mode) {
  if (mode == RenderingMode::kSoftwareShm) {
    // Both switches have to be set, and before the WebProcess starts: it
    // inherits the environment at spawn time.
    //
    // DISABLE_GL selects the host's pixel-buffer texture and discards DMA-BUF
    // frames; WEBKIT_DISABLE_DMABUF_RENDERER makes the WebProcess emit SHM
    // frames instead. Both are scoped to WebKit.
    //
    // LIBGL_ALWAYS_SOFTWARE is deliberately not set here; see the header.
    setenv("WEBKIT_DISABLE_DMABUF_RENDERER", "1", 1);
    setenv("FLUTTER_INAPPWEBVIEW_LINUX_DISABLE_GL", "1", 1);
  }

  // debugLog is compiled out in shipped builds, so the decision has to go
  // through infoLog: without it, a field log cannot tell which rendering mode
  // ran.
  infoLog(std::string("rendering mode=") +
          (mode == RenderingMode::kSoftwareShm ? "softwareSHM" : "hardwareEGL") +
          " DISABLE_GL=" +
          (getenv("FLUTTER_INAPPWEBVIEW_LINUX_DISABLE_GL") != nullptr ? "1" : "0") +
          " WEBKIT_DISABLE_DMABUF_RENDERER=" +
          (getenv("WEBKIT_DISABLE_DMABUF_RENDERER") != nullptr ? "1" : "0") +
          " LIBGL_ALWAYS_SOFTWARE=" +
          (getenv("LIBGL_ALWAYS_SOFTWARE") != nullptr ? "1" : "0"));
}

}  // namespace

RenderingMode ResolveRenderingMode() {
  static std::once_flag once;
  static RenderingMode mode = RenderingMode::kHardwareEgl;
  std::call_once(once, []() {
    mode = DetectRenderingMode();
    ApplyRenderingModeEnvironment(mode);
  });
  return mode;
}

bool ApplySoftwareRenderingIfNeeded() {
  return ResolveRenderingMode() == RenderingMode::kSoftwareShm;
}

}  // namespace flutter_inappwebview_plugin
