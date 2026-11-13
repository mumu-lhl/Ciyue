#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// The icon sizes handed to the window manager.
//
// A single 512x512 image is not an option: `_NET_WM_ICON` carries raw ARGB, so
// that one bitmap is a ~1 MB X property request, which the server rejects. GTK
// reports success either way, so the window simply ends up with no icon and the
// task switcher shows a placeholder. A small ladder also lets the panel pick a
// crisp size instead of downscaling one bitmap.
static const int kWindowIconSizes[] = {16, 24, 32, 48, 64};

// Builds the icon ladder from the PNG next to the executable, which is the only
// source that exists when running straight out of a build tree or a bundle.
static GList* my_application_load_icon_file(const gchar* icon_path) {
  GList* icons = nullptr;
  for (const int size : kWindowIconSizes) {
    g_autoptr(GError) error = nullptr;
    GdkPixbuf* pixbuf =
        gdk_pixbuf_new_from_file_at_scale(icon_path, size, size, TRUE, &error);
    if (pixbuf == nullptr) {
      g_warning("Failed to scale the window icon to %dpx: %s", size,
                error != nullptr ? error->message : "unknown error");
      continue;
    }
    icons = g_list_append(icons, pixbuf);
  }
  return icons;
}

// Builds the same ladder from the icon theme, which is what packaging installs.
static GList* my_application_load_icon_theme(void) {
  GtkIconTheme* theme = gtk_icon_theme_get_default();
  if (theme == nullptr) {
    return nullptr;
  }

  GList* icons = nullptr;
  for (const int size : kWindowIconSizes) {
    g_autoptr(GError) error = nullptr;
    GdkPixbuf* pixbuf = gtk_icon_theme_load_icon(
        theme, "ciyue", size, static_cast<GtkIconLookupFlags>(0), &error);
    if (pixbuf != nullptr) {
      icons = g_list_append(icons, pixbuf);
    }
  }
  return icons;
}

// Sets the icon shown in the title bar and the task switcher.
//
// The window property is `_NET_WM_ICON`, and only the icon *list* fills it:
// gtk_window_set_icon_name() leaves it unset, and the XFCE panel then falls back
// to a placeholder even though its .desktop entry points at the same icon. So
// both sources are resolved into a list, the bundled PNG first and the theme
// entry second.
static void my_application_set_window_icon(GtkWindow* window) {
  GList* icons = nullptr;

  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", nullptr);
  if (executable != nullptr) {
    g_autofree gchar* directory = g_path_get_dirname(executable);
    g_autofree gchar* icon_path = g_build_filename(
        directory, "data", "flutter_assets", "assets", "icon.png", nullptr);
    if (g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
      icons = my_application_load_icon_file(icon_path);
    }
  }

  if (icons == nullptr) {
    icons = my_application_load_icon_theme();
  }

  if (icons != nullptr) {
    gtk_window_set_icon_list(window, icons);
    g_list_free_full(icons, g_object_unref);
  }
}

// Selects the WebView rendering mode from CIYUE_RENDER_MODE.
//
// The frame transport itself is decided in exactly one place, the plugin's
// ResolveRenderingMode(). This function only expresses a preference by setting
// the inputs that decision reads, so there is still a single place where the
// answer is produced and the texture type, the WPE exportable type and the
// WebProcess's buffer type cannot disagree.
//
//   auto (default)  let the plugin detect: a virtual machine or an unusable
//                   driver falls back to software, a known good GPU uses the
//                   hardware zero-copy path
//   software        force the software pixel-buffer path
//   hardware        force the hardware EGL zero-copy path
//
// Explicit FLUTTER_INAPPWEBVIEW_LINUX_DISABLE_GL or
// FLUTTER_INAPPWEBVIEW_SKIP_DMABUF_CHECK always win, so the low-level escape
// hatches keep working unchanged.
//
// An unknown value falls back to software with a warning: a typo must not
// silently select the hardware path on a GPU where it has never been verified.
static void my_application_select_render_mode() {
  if (g_getenv("FLUTTER_INAPPWEBVIEW_LINUX_DISABLE_GL") != nullptr ||
      g_getenv("FLUTTER_INAPPWEBVIEW_SKIP_DMABUF_CHECK") != nullptr) {
    return;
  }

  const gchar* mode = g_getenv("CIYUE_RENDER_MODE");
  if (mode == nullptr || *mode == '\0' || g_ascii_strcasecmp(mode, "auto") == 0) {
    // Leave both signals unset and let ResolveRenderingMode() run detection.
    return;
  }
  if (g_ascii_strcasecmp(mode, "software") == 0) {
    g_setenv("FLUTTER_INAPPWEBVIEW_LINUX_DISABLE_GL", "1", TRUE);
    return;
  }
  if (g_ascii_strcasecmp(mode, "hardware") == 0) {
    g_setenv("FLUTTER_INAPPWEBVIEW_SKIP_DMABUF_CHECK", "1", TRUE);
    return;
  }

  g_warning("Ignoring unknown CIYUE_RENDER_MODE '%s'; expected auto, software "
            "or hardware. Falling back to software rendering.",
            mode);
  g_setenv("FLUTTER_INAPPWEBVIEW_LINUX_DISABLE_GL", "1", TRUE);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "ciyue");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "ciyue");
  }

  gtk_window_set_default_size(window, 1280, 720);
  // Before the window is shown, so the icon is part of the initial state the
  // window manager sees (it reads _NET_WM_ICON for the task switcher).
  my_application_set_window_icon(window);
  gtk_widget_show(GTK_WIDGET(window));

  // Must run before the plugin is registered: ResolveRenderingMode() pins the
  // decision on first use and the WebProcess inherits the environment at spawn
  // time, so a later change would not reach it.
  my_application_select_render_mode();

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  // Impeller is left at the SDK default (on for Linux since Flutter 3.47).
  // It was ruled out as the cause of a blank dictionary entry: with the
  // software pixel buffer path, Impeller and Skia both render correctly in
  // A/B runs on the same machine. Android still disables it for a separate
  // Mali black-screen bug (flutter/flutter#195424).
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
