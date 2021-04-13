#!/usr/bin/env python3

import argparse
import os
import pathlib
import shutil
import sys

def main(argv):
    parser = argparse.ArgumentParser()

    parser.add_argument("--strip-prefix", type=pathlib.Path, default=None,
                        help="directory prefix to strip from all incoming paths")
    parser.add_argument("--prefix", type=pathlib.Path, default=None,
                        help="prefix to add to all output paths")
    parser.add_argument("--rename", type=str, action='append',
                        help="SOURCE=DESTINATION mappings.  Only supports files.")
    parser.add_argument("--exclude", type=pathlib.Path, action='append',
                        help="Input files to exclude from the output directory")

    parser.add_argument("input_dir", type=pathlib.Path,
                        help="input directory")
    parser.add_argument("output_dir", type=pathlib.Path,
                        help="output directory")

    args = parser.parse_args(argv)

    dir_in = args.input_dir
    dir_out = args.output_dir

    # TODO: various consistency checks, including:
    # - prefix must be relative and must be normalized (not contain any "..")
    # - strip_prefix must be relative


    excludes_map = {} if args.exclude is None else {e: False for e in args.exclude}
    renames_map = {} # TODO-NOW
    file_mappings = {}

    strip_prefix_dirs_invalid = []
    for root, dirs, files in os.walk(dir_in):
        root_path = pathlib.Path(root)

        rel_root = root_path.relative_to(dir_in)

        if args.prefix:
            dest_dir = dir_out / args.prefix
        else:
            dest_dir = dir_out

        # strip_prefix must apply to everything to reduce overall surprise.  If
        # this root contains files and is not under strip_prefix, quit now.
        dest_rel_root = rel_root
        if len(files) != 0 and args.strip_prefix is not None:
            try:
                dest_rel_root = rel_root.relative_to(args.strip_prefix)
                print("STRIP_PREFIX dest_rel_root", dest_rel_root)
            except ValueError:
                # Cannot proceed -- strip_prefix does not apply here.  Store
                # "invalid" directories in the right location,
                strip_prefix_dirs_invalid.append(rel_root)

        dest_dir /= dest_rel_root

        for f in files:
            rel_src_path = rel_root / f
            if rel_src_path in excludes_map:
                excludes_map[rel_src_path] = True
                # Skip it
                continue

            dest = dest_dir / f
            file_mappings[root_path / f] = dest

    ###########################################################################
    # Check for early failure
    ###########################################################################

    def value_unused(value_tuple):
        _, used = value_tuple
        return not used

    unused_exclusions = dict(filter(value_unused, excludes_map.items()))
    # TODO-NOW do something with this
    unused_renames = {}

    # If there are any unused exclusions or renames, fail now.
    #
    # Empty dictionaries are "falsy"
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
                print("       " + str(d))
        if unused_exclusions:
            print("    Unused exclusions:")
            for p in unused_exclusions.keys():
                print("       " + str(p))
        if unused_renames:
            print("    Unused renames:")
            for p in unused_renames.keys():
                print("       " + str(p))

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
