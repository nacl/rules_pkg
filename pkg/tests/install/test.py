#!/usr/bin/env python3

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

import json
import os
import unittest

from rules_python.python.runfiles import runfiles
from private.manifest import ENTRY_IS_FILE, ENTRY_IS_LINK, ENTRY_IS_DIR, ENTRY_IS_TREE, ManifestEntry

class PkgInstallTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.runfiles = runfiles.Create()
        # Somewhat of an implementation detail, but it works.  I think.
        manifest_file = cls.runfiles.Rlocation("rules_pkg/tests/install/test_installer_install_script-install-manifest.json")

        with open(manifest_file, 'r') as fh:
            manifest_data_raw = json.load(fh)
            cls.manifest_data = {}
            for entry in manifest_data_raw:
                entry_struct = ManifestEntry(*entry)
                cls.manifest_data[entry_struct.dest] = entry_struct

    def test_manifest_matches(self):
        # TODO-NOW: check for file attributes (mode, user, group)
        dir_path = self.runfiles.Rlocation('rules_pkg/tests/install/installed_dir')

        found_entries = {dest : False for dest in self.manifest_data.keys()}
        for root, dirs, files in os.walk(dir_path):
            # TODO(nacl): check for treeartifacts here.  If so, prune `dirs`,
            # and set the rest aside for future processing.

            # TODO-NOW: check for directory ownership.  If it's empty, it can
            # only be owned (via a PackageDirsInfo).
            #
            # If it's not empty, it can be owned or unowned, depending on the
            # overall context.
            if len(files) == 0:
                # TODO-NOW: handle empty directories
                pass
            for f in files:
                fpath = "/".join(root, f)
                if fpath not in self.manifest_data:
                    # TODO: compare file types -- check for symlinks, files
                    self.fail("Entity {} not in manifest".format(fpath))
                    found_entries[fpath] = True

        # TODO(nacl): check for TreeArtifacts

        # TODO-NOW: verify we haven't missed anything


if __name__ == "__main__":
    unittest.main()
