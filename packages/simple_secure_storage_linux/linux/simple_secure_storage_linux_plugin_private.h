#include <flutter_linux/flutter_linux.h>

#include <nlohmann/json.hpp>

#include "include/tl/optional.hpp"
#include "include/simple_secure_storage_linux/simple_secure_storage_linux_plugin.h"

const SecretSchema * get_schema (void) G_GNUC_CONST;

#define SECRET_SCHEMA  get_schema()

bool initialized;
std::string warmupKey = "SimpleSecureStorage Control";
std::string dataKey;

void initialize(std::string app);
std::tuple<std::string, bool> has(std::string key);
std::tuple<std::string, tl::optional<std::string>> read(std::string key);
std::tuple<std::string, nlohmann::json> list();
std::tuple<std::string, bool> write(std::string key, std::string value);
std::tuple<std::string, bool> del(std::string key);
std::tuple<std::string, bool> clear();
std::tuple<std::string, bool> warmupKeyring();
std::tuple<std::string, nlohmann::json> readFromKeyring();
std::tuple<std::string, bool> storeToKeyring(nlohmann::json value);
