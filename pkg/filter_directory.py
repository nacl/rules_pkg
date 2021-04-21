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
import textwrap


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
                        help="DESTINATION=SOURCE mappings.  Only supports files.  "
                             "DESTINATION=SOURCE must be one-to-one.")
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
    dir_out_abs = pathlib.Path.cwd() / dir_out

    excludes_used_map = {e: False for e in args.exclude}

    # src -> dest
    renames_map = {}
    # dest -> src, used for diagnostics
    renames_map_reversed = {}

    for r in args.rename:
        dest, src = (pathlib.Path(p) for p in r.split('=', maxsplit=1))
        if src in renames_map:
            sys.exit(textwrap.dedent("""In --renames, sources used multiple times:
                {s1} -> {d1}
                {s2} -> {d2}

            Each destination must be unique.
            """.format(
                s1=src, d1=dest,
                s2=src, d2=renames_map[src],
            )))

        if dest in renames_map_reversed:
            sys.exit(textwrap.dedent("""--renames destination collision:
                {d1} <- {s1}
                {d2} <- {s2}

            Each destination must be unique.
            """.format(
                d1=dest, s1=src,
                d2=dest, s2=renames_map_reversed[dest],
            )))
        renames_map[src] = dest
        renames_map_reversed[dest] = src

    renames_used_map = {src: False for src in renames_map.keys()}
    invalid_strip_prefix_dirs = []

    files_installed_outside_destdir = []

    file_mappings = {}

    ###########################################################################
    # Assemble src -> dest map (file_mappings)
    ###########################################################################

    for root, dirs, files in os.walk(dir_in):
        root_path = pathlib.Path(root)

        rel_root = root_path.relative_to(dir_in)

        # Prepend the prefix
        if args.prefix:
            dest_dir = dir_out / args.prefix
        else:
            dest_dir = dir_out

        # strip_prefix must apply to everything to reduce overall surprise.  If
        # this root contains files and is not under strip_prefix, record it and
        # fail after this preprocessing stage.
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
                invalid_strip_prefix_dirs.append(rel_root)

        dest_dir /= dest_rel_root

        for f in files:
            rel_src_path = rel_root / f

            # Handle exclusions
            if rel_src_path in excludes_used_map:
                excludes_used_map[rel_src_path] = True
                # Skip it
                continue

            if rel_src_path in renames_map:
                # Calculate a new path based on the individual renames.  Renames
                # override "strip_prefix". Include the prefix too.
                dest = dir_out
                if args.prefix:
                    dest /= args.prefix
                dest /= renames_map[rel_src_path]
                renames_used_map[rel_src_path] = True
            else:
                # Use the paths we already calculated.
                dest = dest_dir / f

            # Verify that files are not going to be installed outside the output
            # directory, and include them in error lists if this is the case.

            # We can't use pathlib here since non-strict checks are only
            # available as of python 3.6.  Target environments may still be
            # running earlier versions.
            common_pfx = os.path.commonprefix([
                os.path.abspath(str(dest)),
                str(dir_out_abs)
            ])
            if common_pfx != str(dir_out_abs):
                files_installed_outside_destdir.append(f)

            file_mappings[root_path / f] = dest

    ###########################################################################
    # Check for early failure
    ###########################################################################

    # Figure out if anything is being installed to multiple places in case we
    # missed something above.  Interactions between strip_prefix and renames
    # come to mind, as well as renames to outputs already in the tarball.
    #
    # These are converted to strings here because they aren't used again
    # afterward.
    dest_src_str_map = {}
    duplicate_mappings = {}
    for src, dest in file_mappings.items():
        rel_srcs_str = str(src.relative_to(dir_in))
        rel_dest_str = str(dest.relative_to(dir_out))

        if rel_dest_str in dest_src_str_map:
            dest_src_str_map[rel_dest_str].append(rel_srcs_str)
        else:
            dest_src_str_map[rel_dest_str] = [rel_srcs_str]

    duplicate_mappings = {
        dest: srcs
        for dest, srcs in dest_src_str_map.items()
        if len(srcs) > 1
    }

    def value_unused(value_tuple):
        _, used = value_tuple
        return not used

    unused_exclusions = dict(filter(value_unused, excludes_used_map.items()))
    unused_renames = dict(filter(value_unused, renames_used_map.items()))

    # If there is anything that might result in confusing or unexpected output,
    # fail now.
    #
    # Empty iterables below are "falsy"
    fail_early = any([
        invalid_strip_prefix_dirs,
        unused_exclusions,
        unused_renames,
        files_installed_outside_destdir,
        duplicate_mappings,
    ])

    if fail_early:
        print("Refusing to continue due to:")
        if invalid_strip_prefix_dirs:
            print("    strip_prefix does not apply to directories")
            for d in invalid_strip_prefix_dirs:
                print("       {}".format(d))
        if unused_exclusions:
            print("    Unused exclusions:")
            for p in unused_exclusions.keys():
                print("       {}".format(p))
        if unused_renames:
            print("    Unused renames:")
            for src in unused_renames.keys():
                # TODO: this could be formatted more prettily, specifically, aligned
                print("       {} -> {}".format(src, renames_map[src]))
        if files_installed_outside_destdir:
            print("    Files would be installed outside DESTDIR:")
            for src in files_installed_outside_destdir:
                print("       {}".format(src))
        if duplicate_mappings:
            print("    Duplicate destination mappings:")
            for dest, srcs in duplicate_mappings.items():
                print("       {} <- {}".format(dest, ', '.join(srcs)))
        print("")
        print("Sources relative to      {}".format(dir_in))
        print("Destinations relative to {}".format(dir_out))

        sys.exit(1)

    ###########################################################################
    # Do the thing
    ###########################################################################

    for src, dest in file_mappings.items():
        dest.parent.mkdir(exist_ok=True, parents=True)
        shutil.copy(
            src,
            dest,
        )


if __name__ == "__main__":
    exit(main(sys.argv[1:]))
