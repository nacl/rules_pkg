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

import collections

# These must be kept in sync with the declarations in private/build_*.py
ENTRY_IS_FILE = 0  # Entry is a file: take content from <src>
ENTRY_IS_LINK = 1  # Entry is a symlink: dest -> <src>
ENTRY_IS_DIR = 2  # Entry is an empty dir
ENTRY_IS_TREE = 3  # Entry is a tree artifact: take tree from <src>

ManifestEntry = collections.namedtuple("ManifestEntry",
                                       ['entry_type', 'dest', 'src', 'mode', 'user', 'group'])
