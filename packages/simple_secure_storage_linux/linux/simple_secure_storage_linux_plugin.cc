#include "include/simple_secure_storage_linux/simple_secure_storage_linux_plugin.h"
#include "include/tl/optional.hpp"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <libsecret/secret.h>
#include <sys/utsname.h>
#include <iostream>
#include <map>
#include <regex>
#include <string>
#include <cstring>

#include "simple_secure_storage_linux_plugin_private.h"

#define simple_secure_storage_linux_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), simple_secure_storage_linux_plugin_get_type(), SimpleSecureStorageLinuxPlugin))

struct _SimpleSecureStorageLinuxPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(SimpleSecureStorageLinuxPlugin, simple_secure_storage_linux_plugin, g_object_get_type())

// Builds and returns a secret schema.
const SecretSchema* get_schema (void){
    static const SecretSchema schema = {
      "fr.skyost.SimpleSecureStorage",
      SECRET_SCHEMA_NONE,
      {
        {"data", SECRET_SCHEMA_ATTRIBUTE_STRING},
        {"NULL", SECRET_SCHEMA_ATTRIBUTE_STRING},
      }
    };
    return &schema;
}

// Called when a method call is received from Flutter.
static void simple_secure_storage_linux_plugin_handle_method_call(
  SimpleSecureStorageLinuxPlugin* self,
  FlMethodCall* methodCall
) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(methodCall);
  FlValue* arguments = fl_method_call_get_args(methodCall);

  if (strcmp(method, "initialize") == 0) {
    std::string app = "Simple Secure Storage";
    FlValue* name = fl_value_lookup_string(arguments, "appName");
    if (name != nullptr) {
      app = fl_value_get_string(name);
    }

    FlValue* namespace_ = fl_value_lookup_string(arguments, "namespace");
    if (namespace_ != nullptr) {
      app = fl_value_get_string(namespace_) + std::string(".") + app;
    }

    app = std::regex_replace(app, std::regex(" "), "");

    initialize(app);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));
  } else if (strcmp(method, "has") == 0) {
    if (initialized) {
      FlValue* key = fl_value_lookup_string(arguments, "key");
      std::string keyString (fl_value_get_string(key));
      auto callResult = has(keyString);
      if (std::get<0>(callResult).empty()) {
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(std::get<1>(callResult))));
      } else {
        response = FL_METHOD_RESPONSE(fl_method_error_response_new("has_error", std::get<0>(callResult).c_str(), nullptr));
      }
    } else {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new("not_initialized", "Plugin is not initialized.", nullptr));
    }
  } else if (strcmp(method, "read") == 0) {
    if (initialized) {
      FlValue* key = fl_value_lookup_string(arguments, "key");
      std::string keyString (fl_value_get_string(key));
      auto callResult = read(keyString);
      if (std::get<0>(callResult).empty()) {
        auto value = std::get<1>(callResult);
        if (value.has_value()) {
          response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string(value.value().c_str())));
        } else {
          response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
        }
      } else {
        response = FL_METHOD_RESPONSE(fl_method_error_response_new("read_error", std::get<0>(callResult).c_str(), nullptr));
      }
    } else {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new("not_initialized", "Plugin is not initialized.", nullptr));
    }
  } else if (strcmp(method, "list") == 0) {
    if (initialized) {
      auto callResult = list();
      if (std::get<0>(callResult).empty()) {
        auto items = std::get<1>(callResult);
        auto map = fl_value_new_map();
        for (auto& element : items.items()) {
          fl_value_set_string_take(map, std::string(element.key()).c_str(), fl_value_new_string(std::string(element.value()).c_str()));
        }
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(map));
      } else {
        response = FL_METHOD_RESPONSE(fl_method_error_response_new("list_error", std::get<0>(callResult).c_str(), nullptr));
      }
    } else {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new("not_initialized", "Plugin is not initialized.", nullptr));
    }
  } else if (strcmp(method, "write") == 0) {
    if (initialized) {
      FlValue* key = fl_value_lookup_string(arguments, "key");
      std::string keyString (fl_value_get_string(key));
      FlValue* value = fl_value_lookup_string(arguments, "value");
      std::string valueString (fl_value_get_string(value));
      auto callResult = write(keyString, valueString);
      if (std::get<0>(callResult).empty()) {
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(std::get<1>(callResult))));
      } else {
        response = FL_METHOD_RESPONSE(fl_method_error_response_new("write_error", std::get<0>(callResult).c_str(), nullptr));
      }
    } else {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new("not_initialized", "Plugin is not initialized.", nullptr));
    }
  } else if (strcmp(method, "delete") == 0) {
    if (initialized) {
      FlValue* key = fl_value_lookup_string(arguments, "key");
      std::string keyString (fl_value_get_string(key));
      auto callResult = del(keyString);
      if (std::get<0>(callResult).empty()) {
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(std::get<1>(callResult))));
      } else {
        response = FL_METHOD_RESPONSE(fl_method_error_response_new("delete_error", std::get<0>(callResult).c_str(), nullptr));
      }
    } else {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new("not_initialized", "Plugin is not initialized.", nullptr));
    }
  } else if (strcmp(method, "clear") == 0) {
    if (initialized) {
      auto callResult = clear();
      if (std::get<0>(callResult).empty()) {
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(std::get<1>(callResult))));
      } else {
        response = FL_METHOD_RESPONSE(fl_method_error_response_new("clear_error", std::get<0>(callResult).c_str(), nullptr));
      }
    } else {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new("not_initialized", "Plugin is not initialized.", nullptr));
    }
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(methodCall, response, nullptr);
}

// Initializes the plugin and load the encrypted file content.
void initialize(std::string app) {
  dataKey = app;
  initialized = true;
}

// Check if a key exists in the secure storage.
std::tuple<std::string, bool> has(std::string key) {
  std::tuple<std::string, tl::optional<std::string>> readResult = read(key);
  if (!std::get<0>(readResult).empty()) {
    return std::tuple<std::string, bool>(std::get<0>(readResult), false);
  }
  return std::tuple<std::string, bool>("", std::get<1>(readResult).has_value());
}

// Retrieve the value associated with a key from the secure storage.
std::tuple<std::string, tl::optional<std::string>> read(std::string key) {
  std::tuple<std::string, nlohmann::json> readResult = readFromKeyring();

  if (!std::get<0>(readResult).empty()) {
    return std::tuple<std::string, tl::optional<std::string>>(std::get<0>(readResult), tl::optional<std::string>());
  }
  nlohmann::json data = std::get<1>(readResult);
  tl::optional<std::string> result = data.contains(key) ? tl::optional<std::string>(data[key]) : tl::optional<std::string>();
  return std::tuple<std::string, tl::optional<std::string>>("", result);
}

// Retrieve the value associated with a key from the secure storage.
std::tuple<std::string, nlohmann::json> list() {
  return readFromKeyring();
}

// Store a key-value pair in the secure storage.
std::tuple<std::string, bool> write(std::string key, std::string value) {
  std::tuple<std::string, nlohmann::json> readResult = readFromKeyring();
  if (!std::get<0>(readResult).empty()) {
    return std::tuple<std::string, bool>(std::get<0>(readResult), false);
  }

  nlohmann::json data = std::get<1>(readResult);
  data[key] = value;
  return storeToKeyring(data);
}

// Remove a key-value pair from the secure storage.
std::tuple<std::string, bool> del(std::string key) {
  std::tuple<std::string, nlohmann::json> readResult = readFromKeyring();
  if (!std::get<0>(readResult).empty()) {
    return std::tuple<std::string, bool>(std::get<0>(readResult), false);
  }

  nlohmann::json data = std::get<1>(readResult);
  data.erase(key);
  return storeToKeyring(data);
}

// Clear all data from the secure storage.
std::tuple<std::string, bool> clear() {
  return storeToKeyring(nlohmann::json());
}

// Search with schemas fails in cold keyrings.
// https://gitlab.gnome.org/GNOME/gnome-keyring/-/issues/89
//
// Note that we're not using the workaround mentioned in the above issue. Instead, we're using
// a workaround as implemented in http://crbug.com/660005. Reason being that with the lookup
// approach we can't distinguish whether the keyring was actually unlocked or whether the user
// cancelled the password prompt.
//
// Kudos to FlutterSecureStorage for this one.
std::tuple<std::string, bool> warmupKeyring() {
  g_autoptr(GError) error = nullptr;

  // Store a dummy entry without `schema`.
  GHashTable *hash_table = g_hash_table_new_full(g_str_hash, nullptr, g_free, g_free);
  g_hash_table_insert(hash_table, (void *)g_strdup("explanation"), (void *)g_strdup("Because of quirks in the gnome libsecret API, SimpleSecureStorage needs to store a dummy entry to guarantee that this keyring was properly unlocked. More details at http://crbug.com/660005."));
  secret_password_storev_sync(
    NULL,
    hash_table,
    nullptr,
    warmupKey.c_str(),
    "The meaning of life",
    nullptr,
    &error
  );
  g_hash_table_destroy(hash_table);

  if (error) {
    return std::tuple<std::string, bool>(error->message, false);
  }
  return std::tuple<std::string, bool>("", true);
}

// Reads the map from the keyring.
std::tuple<std::string, nlohmann::json> readFromKeyring() {
  nlohmann::json value;
  g_autoptr(GError) error = nullptr;

  warmupKeyring();

  gchar* result = secret_password_lookup_sync(SECRET_SCHEMA, NULL, &error, "data", dataKey.c_str(), NULL);
  if (error) {
    return std::tuple<std::string, nlohmann::json>(error->message, value);
  }
  if (result != NULL && strcmp(result, "") != 0) {
    value = nlohmann::json::parse(result);
  }
  secret_password_free(result);
  return std::tuple<std::string, nlohmann::json>("", value);
}

/// Stores the map to the keyring.
std::tuple<std::string, bool> storeToKeyring(nlohmann::json value) {
  const std::string output = value.dump(0);
  g_autoptr(GError) error = nullptr;
  bool result = secret_password_store_sync(SECRET_SCHEMA, SECRET_COLLECTION_DEFAULT, dataKey.c_str(), output.c_str(), NULL, &error, "data", dataKey.c_str(), NULL);

  if (error) {
    return std::tuple<std::string, bool>(error->message, result);
  }

  return std::tuple<std::string, bool>("", result);
}

static void simple_secure_storage_linux_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(simple_secure_storage_linux_plugin_parent_class)->dispose(object);
}

static void simple_secure_storage_linux_plugin_class_init(SimpleSecureStorageLinuxPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = simple_secure_storage_linux_plugin_dispose;
}

static void simple_secure_storage_linux_plugin_init(SimpleSecureStorageLinuxPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  SimpleSecureStorageLinuxPlugin* plugin = simple_secure_storage_linux_PLUGIN(user_data);
  simple_secure_storage_linux_plugin_handle_method_call(plugin, method_call);
}

void simple_secure_storage_linux_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  SimpleSecureStorageLinuxPlugin* plugin = simple_secure_storage_linux_PLUGIN(
    g_object_new(simple_secure_storage_linux_plugin_get_type(), nullptr)
  );

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
    fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar), "fr.skyost.simple_secure_storage", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
