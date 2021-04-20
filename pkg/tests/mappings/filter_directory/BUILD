# Copyright 2021 The Bazel Authors. All rights reserved.
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

load("@rules_python//python:defs.bzl", "py_test")
load(":defs.bzl", "inspect_directory_test")
load("//tests/util:defs.bzl", "directory")
load("//:mappings.bzl", "filter_directory")

############################################################################
# Base case
############################################################################

inspect_directory_test(
    name = "base",
    directory = ":test_directory",
    expected_structure = [
        "a",
        "b",
        "subdir/c",
        "subdir/d",
    ],
)

############################################################################
# Renames
############################################################################

inspect_directory_test(
    name = "renames",
    directory = ":renames_in",
    expected_structure = [
        "b",
        "c",
        "subdir/a",
        "subdir/d",
    ],
)

filter_directory(
    name = "renames_in",
    src = ":test_directory",
    renames = {
        "subdir/a": "a",
        "c": "subdir/c",
    },
)

inspect_directory_test(
    name = "renames_loop",
    directory = ":renames_loop_in",
    expected_structure = [
        "a",
        "b",
        "subdir/c",
        "subdir/d",
    ],
)

filter_directory(
    name = "renames_loop_in",
    src = ":test_directory",
    renames = {
        "subdir/c": "a",
        "a": "subdir/c",
    },
)

############################################################################
# Prefix stripping
############################################################################

inspect_directory_test(
    name = "strip_prefix",
    directory = ":strip_prefix_in",
    expected_structure = [
        "a",
        "b",
        "subdir/c",
        "subdir/d",
    ],
)

filter_directory(
    name = "strip_prefix_in",
    src = ":test_directory_same_root",
    strip_prefix = "root/",
)

############################################################################
# Prefixing
############################################################################

inspect_directory_test(
    name = "prefix",
    directory = ":prefix_in",
    expected_structure = [
        "extra/a",
        "extra/b",
        "extra/subdir/c",
        "extra/subdir/d",
    ]
)

filter_directory(
    name = "prefix_in",
    src = ":test_directory",
    prefix = "extra/",
)

############################################################################
# Exclusions
############################################################################

inspect_directory_test(
    name = "exclusions",
    directory = ":exclusions_in",
    expected_structure = [
        "a",
        "subdir/c",
    ],
)

filter_directory(
    name = "exclusions_in",
    src = ":test_directory",
    excludes = [
        "b",
        "subdir/d",
    ],
)

############################################################################
# Combinations
############################################################################

inspect_directory_test(
    name = "combo_all",
    directory = ":combo_all_in",
    expected_structure = [
        "foo/root/not_a",
        "foo/subdir/c",
    ],
)

filter_directory(
    name = "combo_all_in",
    src = ":test_directory_same_root",
    excludes = [
        "root/b",
        "root/subdir/d",
    ],
    prefix = "foo",
    renames = {"root/not_a": "root/a"},
    strip_prefix = "root/",
)

inspect_directory_test(
    name = "combo_rename_to_exclude",
    directory = ":combo_rename_to_exclude_in",
    expected_structure = [
        "a",
        "subdir/c",
        "subdir/d",
    ],
)

filter_directory(
    name = "combo_rename_to_exclude_in",
    src = ":test_directory",
    renames = {"a": "b"},
    excludes = ["a"],
)

############################################################################
# Inputs
############################################################################

directory(
    name = "test_directory_same_root",
    filenames = [
        "root/a",
        "root/b",
        "root/subdir/c",
        "root/subdir/d",
    ],
)

directory(
    name = "test_directory",
    filenames = [
        "a",
        "b",
        "subdir/c",
        "subdir/d",
    ],
)

############################################################################
# Negative tests
############################################################################

py_test(
    name = "negative_tests",
    srcs = ["test_filter_directory.py"],
    main = "test_filter_directory.py",
    deps = ["@rules_python//python/runfiles"],
    data = ["//:filter_directory"],
)
