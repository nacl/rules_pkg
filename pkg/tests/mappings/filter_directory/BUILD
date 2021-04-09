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

# TODO: populate

load(":defs.bzl", "inspect_directory_test")
load("//tests/util:defs.bzl", "directory")

inspect_directory_test(
    name = "basic_af",
    directory = ":test_directory",
    expected_structure = [
        "test/a",
        "test/b",
        "c",
        "d",
    ],
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

