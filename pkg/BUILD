# Copyright 2019 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# -*- coding: utf-8 -*-
load("@rules_python//python:defs.bzl", "py_binary", "py_library")

licenses(["notice"])

exports_files(
    glob([
        "*.bzl",
        "private/**",
    ]),
    visibility = ["//visibility:public"],
)

constraint_setting(name = "not_compatible_setting")

constraint_value(
    name = "not_compatible",
    constraint_setting = ":not_compatible_setting",
)

filegroup(
    name = "standard_package",
    srcs = glob([
        "*.bzl",
        "*.py",
        "*.md",
        "private/**",
    ]) + [
        "BUILD",
        "LICENSE",
        "//legacy:standard_package",
        "//rpm:standard_package",
    ],
    visibility = ["//distro:__pkg__"],
)

exports_files(
    ["WORKSPACE"],
    visibility = ["//visibility:public"],
)

py_library(
    name = "archive",
    srcs = [
        "__init__.py",
        "archive.py",
    ],
    srcs_version = "PY3",
    visibility = [
        "//experimental:__pkg__",
        "//tests:__pkg__",
    ],
)

py_library(
    name = "helpers",
    srcs = [
        "__init__.py",
        "helpers.py",
    ],
    srcs_version = "PY3",
    visibility = [
        "//experimental:__pkg__",
        "//tests:__pkg__",
    ],
)

py_binary(
    name = "build_tar",
    srcs = ["build_tar.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = ["//visibility:public"],
    deps = [
        ":archive",
        ":helpers",
    ],
)

py_binary(
    name = "build_zip",
    srcs = ["build_zip.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = ["//visibility:public"],
    deps = [
        ":archive",
        ":helpers",
    ],
)

py_binary(
    name = "make_deb",
    srcs = ["make_deb.py"],
    python_version = "PY3",
    visibility = ["//visibility:public"],
    deps = [
        ":helpers",
    ],
)

# Used by pkg_rpm in rpm.bzl.
py_binary(
    name = "make_rpm",
    srcs = ["make_rpm.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    # TODO(aiuto): Enable this for bazel 4.x
    #target_compatible_with = select({
    #    "//toolchains:have_rpmbuild": [],
    #    "//conditions:default": [":not_compatible"],
    #}),
    visibility = ["//visibility:public"],
    deps = [
        ":archive",
        ":make_rpm_lib",
    ],
)

py_library(
    name = "make_rpm_lib",
    srcs = ["make_rpm.py"],
    srcs_version = "PY3",
    visibility = [
        "//experimental:__subpackages__",
        "//tests:__subpackages__",
    ],
    deps = [
        ":archive",
        ":helpers",
    ],
)

py_binary(
    name = "filter_directory",
    srcs = ["filter_directory.py"],
    visibility = ["//visibility:public"],
    python_version = "PY3",
)
