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

import pathlib
import os
import subprocess
import tempfile
import unittest
from rules_python.python.runfiles import runfiles


class FilterDirectoryInternalTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        rf = runfiles.Create()
        cls.filter_directory_script = rf.Rlocation(os.path.join(
            os.environ["TEST_WORKSPACE"],
            "filter_directory"
        ))

    def setUp(self):
        self.indir = tempfile.TemporaryDirectory(dir=os.environ["TEST_TMPDIR"])
        self.outdir = tempfile.TemporaryDirectory(dir=os.environ["TEST_TMPDIR"])
        indir_path = pathlib.Path(self.indir.name)

        (indir_path / "root").mkdir()
        (indir_path / "root" / "a").open(mode='w').close()
        (indir_path / "root" / "b").open(mode='w').close()
        (indir_path / "root" / "subdir").mkdir()
        (indir_path / "root" / "subdir" / "c").open(mode='w').close()
        (indir_path / "root" / "subdir" / "d").open(mode='w').close()

    def tearDown(self):
        self.indir.cleanup()
        self.outdir.cleanup()

    def callFilterDirectory(self,
                            prefix=None,        # str
                            strip_prefix=None,  # str
                            renames=None,       # list of tuple
                            exclusions=None,    # list
    ):
        args = [self.filter_directory_script]
        if prefix:
            args.append("--prefix={}".format(prefix))
        if strip_prefix:
            args.append("--strip-prefix={}".format(prefix))
        if renames:
            args.extend(["--rename={}={}".format(dest, src) for dest, src in renames])
        if exclusions:
            args.extend(["--exclude={}".format(e) for e in exclusions])

        args.append(self.indir.name)
        args.append(self.outdir.name)

        return subprocess.call(args)

    def assertFilterDirectoryFails(self, message=None, **kwargs):
        self.assertNotEqual(self.callFilterDirectory(**kwargs), 0, message)

    def assertFilterDirectorySucceeds(self, message=None, **kwargs):
        self.assertEqual(self.callFilterDirectory(**kwargs), 0, message)

    def test_base(self):
        # Simply verify that the "null" transformation works
        self.assertFilterDirectorySucceeds()

    def test_invalid_prefixes(self):
        self.assertFilterDirectoryFails(
            prefix="/absolute/path",
            message="--prefix with aboslute paths should be rejected",
        )

        self.assertFilterDirectoryFails(
            prefix="/absolute/path",
            message="--prefix with paths outside the destroot should be rejected",
        )

    def test_invalid_strip_prefixes(self):
        self.assertFilterDirectoryFails(
            strip_prefix="invalid",
            message="--strip-prefix that does not apply anywhere should be rejected",
        )

        self.assertFilterDirectoryFails(
            strip_prefix="subdir",
            message="--strip-prefix that does not apply everywhere should be rejected",
        )

    def test_invalid_excludes(self):
        self.assertFilterDirectoryFails(
            exclusions=["a", "foo"],
            message="--exclude's that are unused should be rejected",
        )

    def test_invalid_renames(self):
        # Can't rename files outside the package
        self.assertFilterDirectoryFails(
            renames=[("a", "../outside")],
            message="--rename's with paths outside the destroot should be rejected",
        )

        # Can't rename files to outputs that already exist
        self.assertFilterDirectoryFails(
            renames=[("a", "subdir/c")],
            message="--rename's that clobber other output files should be rejected",
        )

        # This is unreachable from the bazel rule, but it's worth double-checking.
        #
        # Can't rename multiple files to the same destination
        self.assertFilterDirectoryFails(
            renames=[("a", "subdir/c"), ("a", "subdir/d")],
            message="Multiple --rename's to the same destination should be rejected.",
        )

        # Can't rename files twice
        self.assertFilterDirectoryFails(
            renames=[("bar", "a"), ("foo", "a")],
            message="--rename's that attempt to rename the same source twice should be rejected",
        )

    def test_invalid_interactions(self):
        # Renames are supposed to occur after exclusions, the rename here should
        # thus be unused.
        self.assertFilterDirectoryFails(
            renames=[("foo", "a")],
            exclusions=["a"],
            message="--rename's of excluded files should be rejected",
        )

if __name__ == "__main__":
    unittest.main()
