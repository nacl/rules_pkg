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

import argparse
import os
import pathlib
import shutil
import sys


def main(argv):
    ###########################################################################
    # Arg parsing
    ###########################################################################
    parser = argparse.ArgumentParser()

    parser.add_argument("--strip-prefix", type=pathlib.Path, default=None,
                        help="directory prefix to strip from all incoming paths")
    parser.add_argument("--prefix", type=pathlib.Path, default=None,
                        help="prefix to add to all output paths")
    parser.add_argument("--rename", type=str, action='append', default=[],
                        help="SOURCE=DESTINATION mappings.  Only supports files.")
    parser.add_argument("--exclude", type=pathlib.Path, action='append',
                        default=[],
                        help="Input files to exclude from the output directory")

    parser.add_argument("input_dir", type=pathlib.Path,
                        help="input directory")
    parser.add_argument("output_dir", type=pathlib.Path,
                        help="output directory")

    args = parser.parse_args(argv)

    dir_in = args.input_dir
    dir_out = args.output_dir

    # TODO: various consistency checks, including:
    # - prefix must be relative and normalized (not contain any "..")
    # - strip_prefix must be relative and normalized
    # - renamed artifacts must not collide with each other and their paths must be normalized

    excludes_used_map = {e: False for e in args.exclude}

    renames_map = dict(
        [
            (
                pathlib.Path(p)
                for p in r.split('=', maxsplit=1)
            )
            for r in args.rename
        ]
    )

    renames_used_map = {src: False for src in renames_map.keys()}
    strip_prefix_dirs_invalid = []

    file_mappings = {}

    ###########################################################################
    # Assemble src -> dest map (file_mappings)
    ###########################################################################

    for root, dirs, files in os.walk(dir_in):
        root_path = pathlib.Path(root)

        rel_root = root_path.relative_to(dir_in)

        if args.prefix:
            dest_dir = dir_out / args.prefix
        else:
            dest_dir = dir_out

        # strip_prefix must apply to everything to reduce overall surprise.  If
        # this root contains files and is not under strip_prefix, quit now.
        #
        # This can probably be refined somewhat -- for example, if we descend
        # into a child directory, we don't need to mention it.
        dest_rel_root = rel_root
        if len(files) != 0 and args.strip_prefix is not None:
            try:
                dest_rel_root = rel_root.relative_to(args.strip_prefix)
            except ValueError:
                # Cannot proceed -- strip_prefix does not apply here.  Store
                # "invalid" directories in an output list, and then continue.
                strip_prefix_dirs_invalid.append(rel_root)

        dest_dir /= dest_rel_root

        for f in files:
            rel_src_path = rel_root / f
            if rel_src_path in excludes_used_map:
                excludes_used_map[rel_src_path] = True
                # Skip it
                continue

            print("src file:", rel_src_path)
            if rel_src_path in renames_map:
                # Calculate a new path based on the individual renames.  Include
                # the prefix too.
                dest = dir_out
                if args.prefix:
                    dest /= args.prefix
                dest /= renames_map[rel_src_path]
                renames_used_map[rel_src_path] = True
            else:
                # Use the paths we already calculated
                dest = dest_dir / f
            file_mappings[root_path / f] = dest

    # print (renames_map)

    ###########################################################################
    # Check for early failure
    ###########################################################################

    def value_unused(value_tuple):
        _, used = value_tuple
        return not used

    unused_exclusions = dict(filter(value_unused, excludes_used_map.items()))
    # TODO-NOW do something with this
    unused_renames = dict(filter(value_unused, renames_used_map.items()))

    # If there are any unused exclusions or renames, fail now.
    #
    # Empty iterables below are "falsy"
    fail_early = any([
        strip_prefix_dirs_invalid,
        unused_exclusions,
        unused_renames,
    ])

    if fail_early:
        print("Refusing to continue due to:")
        if strip_prefix_dirs_invalid:
            print("    strip_prefix does not apply to directories")
            for d in strip_prefix_dirs_invalid:
                print("       {}".format(d))
        if unused_exclusions:
            print("    Unused exclusions:")
            for p in unused_exclusions.keys():
                print("       {}".format(p))
        if unused_renames:
            print("    Unused renames:")
            for src in unused_renames.keys():
                # TODO: this could be formatted more prettily (namely, aligned)
                print("       {} -> {}".format(src, renames_map[src]))

        sys.exit(1)

    ###########################################################################
    # Do the thing
    ###########################################################################

    for src, dest in file_mappings.items():
        #print("MKDIR", dest.parent)
        dest.parent.mkdir(exist_ok=True)
        #print("CP", src, "->", dest)
        shutil.copy(
            src,
            dest,
        )



if __name__ == "__main__":
    exit(main(sys.argv[1:]))
