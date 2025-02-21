load("//bazel_utils/python:defs.bzl", "requirement")

package(default_visibility = ["//visibility:public"])

exports_files(["general_config.yml"])

py_library(
    name = "starknet_definitions_lib",
    srcs = [
        "constants.py",
        "error_codes.py",
        "fields.py",
        "transaction_type.py",
    ],
    visibility = ["//visibility:public"],
    deps = [
        "//src/services/everest/api/gateway:everest_transaction_type_lib",
        "//src/services/everest/definitions:everest_definitions_lib",
        "//src/starkware/cairo/lang/tracer:cairo_tracer_lib",
        "//src/starkware/cairo/lang/vm:cairo_vm_crypto_lib",
        "//src/starkware/crypto:starkware_crypto_lib",
        "//src/starkware/python:starkware_python_utils_lib",
        "//src/starkware/starkware_utils:starkware_dataclasses_field_utils_lib",
        "//src/starkware/starkware_utils:starkware_dataclasses_utils_lib",
        "//src/starkware/starkware_utils:starkware_error_handling_lib",
        "//src/starkware/storage:starkware_abstract_storage_lib",
        "//src/starkware/storage:starkware_storage_lib",
        requirement("marshmallow"),
    ],
)

py_library(
    name = "starknet_general_config_lib",
    srcs = [
        "chain_ids.py",
        "general_config.py",
    ],
    data = [
        "general_config.yml",
    ],
    visibility = ["//visibility:public"],
    deps = [
        "starknet_definitions_lib",
        "//src/services/everest/definitions:everest_general_config_lib",
        "//src/starkware/cairo/lang:cairo_instances_lib",
        "//src/starkware/cairo/lang/builtins:cairo_all_builtins_lib",
        "//src/starkware/cairo/lang/builtins:cairo_run_builtins_lib",
        "//src/starkware/python:starkware_python_utils_lib",
        "//src/starkware/starkware_utils:starkware_config_utils_lib",
        "//src/starkware/starkware_utils:starkware_dataclasses_field_utils_lib",
        "//src/starkware/starkware_utils:starkware_dataclasses_utils_lib",
        requirement("marshmallow"),
        requirement("marshmallow_dataclass"),
        requirement("marshmallow_enum"),
    ],
)
