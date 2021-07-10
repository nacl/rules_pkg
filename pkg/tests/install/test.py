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

import pwd
import grp

from rules_python.python.runfiles import runfiles
from private.manifest import ENTRY_IS_FILE, ENTRY_IS_LINK, ENTRY_IS_DIR, ENTRY_IS_TREE, ManifestEntry, entry_type_to_string

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

    def entity_type_at_path(self, path):
        if os.path.islink(path):
            return ENTRY_IS_LINK
        elif os.path.isfile(path):
            return ENTRY_IS_FILE
        elif os.path.isdir(path):
            return ENTRY_IS_DIR
        else:
            # We can't infer what TreeArtifacts are by looking at them -- the
            # build system is not aware of their contents.
            raise ValueError("Entity {} is not a link, file, or directory")

    def test_manifest_matches(self):
        # TODO-NOW: check for file attributes (mode, user, group)
        dir_path = self.runfiles.Rlocation('rules_pkg/tests/install/installed_dir')
        print(dir_path)

        found_entries = {dest : False for dest in self.manifest_data.keys()}
        for root, dirs, files in os.walk(dir_path):
            # TODO(nacl): check for treeartifacts here.  If so, prune `dirs`,
            # and set the rest aside for future processing.

            # TODO-NOW: check for directory ownership.  If it's empty, it can
            # only be owned (via a PackageDirsInfo).
            #
            # If it's not empty, it can be owned or unowned, depending on the
            # overall context.
            print(files)
            if len(files) == 0:
                # TODO-NOW: handle empty directories
                pass
            rel_root_path = os.path.relpath(root, dir_path)

            for f in files:
                # The path on the filesystem in which the file actually exists.
                fpath = os.path.normpath("/".join([root, f]))
                # The path inside the manifest (relative to the install
                # destdir).
                rel_fpath = os.path.normpath("/".join([rel_root_path, f]))
                if rel_fpath not in self.manifest_data:
                    print(self.manifest_data)
                    self.fail("Entity {} not in manifest".format(rel_fpath))

                entry = self.manifest_data[rel_fpath]
                real_etype = self.entity_type_at_path(fpath)

                if entry.entry_type != real_etype:
                    self.fail("Entity {} should be a {}, but was actually {}".format(
                        fpath,
                        entry_type_to_string(entry.entry_type),
                        entry_type_to_string(real_etype),
                    ))
                found_entries[rel_fpath] = True


                # TODO: permissions in windows are... tricky.  Don't bother
                # testing for them if we're in it for the time being
                if os.name == 'nt':
                    continue

        # TODO(nacl): check for TreeArtifacts

        num_missing = 0
        for dest, present in found_entries.items():
            if present is False:
                print("Entity {} is missing from the tree".format(dest))
                num_missing += 1
        self.assertEqual(num_missing, 0)


if __name__ == "__main__":
    unittest.main()
