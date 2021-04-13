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
        "test/a",
        "test/b",
        "c",
        "d",
    ],
)

############################################################################
# Remap_Paths
############################################################################

inspect_directory_test(
    name = "renames",
    directory = ":renames_in",
    expected_structure = [
        "test/b",
        "test/c",
        "a",
        "d",
    ],
)

filter_directory(
    name = "renames_in",
    src = ":test_directory",
    renames = {
        "test/a": "a",
        "c": "test/c",
    },
)

############################################################################
# Prefix stripping
############################################################################

inspect_directory_test(
    name = "strip_prefix",
    directory = ":strip_prefix_in",
    expected_structure = [
        "subdir/a",
        "subdir/b",
        "c",
        "d",
    ],
)

filter_directory(
    name = "strip_prefix_in",
    src = ":test_directory_same_root",
    strip_prefix = "test/",
)

############################################################################
# Exclusions
############################################################################

inspect_directory_test(
    name = "exclusions",
    directory = ":exclusions_in",
    expected_structure = [
        "test/a",
        "c",
    ],
)

filter_directory(
    name = "exclusions_in",
    src = ":test_directory",
    excludes = ["test/b", "d"],
)

############################################################################
# Combinations
############################################################################

inspect_directory_test(
    name = "combo_all",
    directory = ":combo_all_in",
    expected_structure = [
        "test/a",
        "c",
    ],
)

filter_directory(
    name = "combo_all_in",
    src = ":test_directory_same_root",
    excludes = ["test/b", "d"],
    strip_prefix = "test/",
    renames = {"test/subdir/a": "test/subdir/not_a"}
)

############################################################################
# Inputs
############################################################################

directory(
    name = "test_directory_same_root",
    filenames = [
        "test/subdir/a",
        "test/subdir/b",
        "test/c",
        "test/d",
    ]
)

directory(
    name = "test_directory",
    filenames = [
        "test/a",
        "test/b",
        "c",
        "d",
    ]
)

