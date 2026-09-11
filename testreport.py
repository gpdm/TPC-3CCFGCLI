#!/usr/bin/env python3
#
# JUnit test report generator
#
# converts the test logs as as created by test.sh, and the various .MK fils
# into a JUnit XML. Nothing fancy here, straight and simple.
# And yes, it's built around my ugly test output to make it usable
# for GH to do some beautified rendindering.

import argparse
import re
import sys
from pathlib import Path


# a bunch of regexes to match the line format
# emitted by test.sh and the .MK files
#
# TEST.MK defines symbolic test groups, optional group headers,
# and the individual test cases:
#
# (Group)    IRQ_CHANGE: t02xx t0201 t0202 t0203
#
# (Header)   t02xx:
#                @echo [t02xx] IRQ_CHANGE: Verify IRQ change behaviour ... >> $(TESTLOG)
#
# (testcase)  t0201:
#                @echo [t0201] Testing CONFIGURE /INT transition ... >> $(TESTLOG)
#
# possible formats currelty used for test cases:
#
# FIXME: the HWCs are missing.
#
# t0000 (main tests in TEST.MK)
# HWL00 (hardware limit test in test.sh)*
# SC0000 (script output test in test.sh)*
#
# *) these are defined as dummy targets in TEST.MK, but only to keep the parser below happy.
#
TARGET_RE = re.compile(
    r"^([A-Za-z0-9_.%/+@\x2D]+)\s*:(?!=)\s*(.*)$"
)

TEST_HEADER_RE = re.compile(
    r"^[A-Za-z]{1,3}[0-9]{2}xx$",
    re.IGNORECASE,
)

TEST_CASE_RE = re.compile(
    r"^[A-Za-z]{1,3}[0-9]{2,4}$",
    re.IGNORECASE,
)

MAKE_TESTLOG_ECHO_RE = re.compile(
    r"^\s*@?echo\s+\[([A-Za-z]{1,3}(?:[0-9]{2,4}|[0-9]{2}xx))\]\s*:?\s*"
    r"(.+?)(?:\s*>>\s*\$\(TESTLOG\))?\s*$",
    re.IGNORECASE,
)

LOG_PASS_RE = re.compile(
    r"^\[([A-Za-z]{1,3}[0-9]{2,4})\]\s+PASSED\s*$",
    re.IGNORECASE,
)

LOG_TEST_RE = re.compile(
    r"^\[([A-Za-z]{1,3}[0-9]{2,4})\]\s*:?\s*(?!PASSED\s*$)(.+?)\s*$",
    re.IGNORECASE,
)


class ReportError(Exception):
    pass


# sanitize the input args
def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Generate a JUnit report from test output."
    )

    parser.add_argument(
        "-f",
        dest="logfile",
        type=Path,
        required=True,
        metavar="LOGFILE.LOG",
        help="The logfile to analyze, e.g. ./LOGS/TEST/TEST.LOG",
    )

    parser.add_argument(
        "-m",
        dest="makefile",
        type=Path,
        required=True,
        metavar="FILE.MK",
        help="The .MK file containing the test definitions, e.g. ./TEST.MK",
    )

    parser.add_argument(
        "-verbose",
        dest="verbose",
        action="store_true",
        help="Enable verbose output"
    )

    return parser.parse_args()


# sanitize the input paths and return the
# JUnit file path
def validate_paths(logfile, makefile):
    if not logfile.is_file():
        raise ValueError(
            f"Log file is not a regular file: {logfile}"
        )

    if not makefile.is_file():
        raise ValueError(
            f"Makefile is not a regular file: {makefile}"
        )

    log_dir = logfile.parent
    artifact_dir = log_dir / "ARTIFACT"

    if not artifact_dir.is_dir():
        raise ValueError(
            f"ARTIFACT is not a directory: {artifact_dir}"
        )

    junit_file = log_dir / f"{logfile.stem}.JUNIT.XML"

    return log_dir, artifact_dir, junit_file


# get source of truth from the .MK file
# Parse the .MK file and extract the test targets and their metadata.
#
# It's a bit ugly, as I have to deal with the .MK format which puts
# the description in the echo line after the target declaration.
# Maybe I should use a proper comment format in the .MK file.
#
# But then again, I'd blow up TEST.MK for duplicated stuff? Nah!
#
# So this is what's parses here:
#
#   HWL00xx:
#      @echo [HWL00xx] Verify 3CCFGCLI startup with RAM and CPU ARCH constraints
#
#   HWL64:
#      @echo [HWL64] 8086/8088 with 64 KB memory limit
#
#
def load_makefile(makefile):
    targets = {}
    lines = makefile.read_text(
        encoding="utf-8",
        errors="replace",
    ).splitlines()

    for line in lines:
        match = TARGET_RE.match(line)

        if not match:
            continue

        label = match.group(1)
        prerequisites = match.group(2)
        prerequisites = prerequisites.split("#", 1)[0].split()

        targets[label] = {
            "prerequisites": prerequisites,
            "description": None,
        }

    current_target = None

    for line in lines:
        target_match = TARGET_RE.match(line)

        if target_match:
            current_target = target_match.group(1)
            continue

        if current_target is None:
            continue

        echo_match = MAKE_TESTLOG_ECHO_RE.search(line)

        if echo_match:
            message_id = echo_match.group(1).lower()
            message = echo_match.group(2).strip()

            if (
                message_id == current_target.lower()
                and message.upper() != "PASSED"
                and targets[current_target]["description"] is None
            ):
                targets[current_target]["description"] = message

    return targets


# build test groups from the parsed targets.
def build_test_groups(targets):
    groups = []

    for label, target in targets.items():
        header = None
        tests = []

        for prerequisite in target["prerequisites"]:
            if TEST_HEADER_RE.match(prerequisite):
                header = prerequisite

            elif TEST_CASE_RE.match(prerequisite):
                tests.append(prerequisite)

        #
        # A symbolic test group is any target which references
        # at least one test case.
        #
        if not tests:
            continue

        groups.append({
            "name": label,
            "header": header,
            "tests": tests,
        })

    return groups


# read the log file to get the test results
def parse_logfile(logfile):
    started = {}
    passed = set()

    with logfile.open(
        "r",
        encoding="utf-8",
        errors="replace",
    ) as file:
        for line_number, line in enumerate(file, start=1):
            line = line.rstrip("\r\n")

            pass_match = LOG_PASS_RE.match(line)

            if pass_match:
                passed.add(pass_match.group(1).lower())
                continue

            test_match = LOG_TEST_RE.match(line)

            if test_match:
                test_id = test_match.group(1).lower()
                message = test_match.group(2).strip()

                if message.upper() != "PASSED":
                    started.setdefault(
                        test_id,
                        {
                            "line": line_number,
                            "description": message,
                        },
                    )

    return started, passed


# classiy the results retrieved from the log
#
# Mind fail-fast behavior when interpreting the log, error during a testcase
# won't yield a FAILED marker, but just abort the entire MAKE run.
#
# Example:
#
#   [t0201]: Testing ...
#   [t0201] PASSED
#   [t0202]: Testing ...
#                 <execution stops here>
#.  ( no FAILED marker - T0202 FAIL is implicit by absence of MARKER )
#
# In this case:
#
#   t0201 = PASS
#   t0202 = FAIL
#   everything that follows = SKIPPED
#
def classify_results(groups, started, passed):
    planned = [
        test_id.lower()
        for group in groups
        for test_id in group["tests"]
    ]

    planned_set = set(planned)
    unknown_passed = sorted(passed - planned_set)

    if unknown_passed:
        raise ReportError(
            "Log contains PASS results for tests not present in the "
            "active Makefile test groups: "
            + ", ".join(unknown_passed)
        )

    first_missing_index = None

    for index, test_id in enumerate(planned):
        if test_id not in passed:
            first_missing_index = index
            break

    results = {}
    failed_test = None

    if first_missing_index is None:
        for test_id in planned:
            results[test_id] = "PASS"

        return results, failed_test

    failed_test = planned[first_missing_index]

    later_passed = [
        test_id
        for test_id in planned[first_missing_index + 1:]
        if test_id in passed
    ]

    # gah .... basically should never happen
    # but I had some - prefixed calls from earlier trials,
    # maybe good to leep in as safeguard anyway.
    if later_passed:
        raise ReportError(
            f"Fail fast log is inconsistent: {failed_test} has no PASSED "
            "marker, but later tests passed: "
            + ", ".join(later_passed)
        )

    for index, test_id in enumerate(planned):
        if index < first_missing_index:
            results[test_id] = "PASS"
        elif index == first_missing_index:
            results[test_id] = "FAIL"
        else:
            results[test_id] = "SKIPPED"

    return results, failed_test


# helper: add group description
def clean_group_description(group_name, description):
    if not description:
        return None

    prefix = f"{group_name}:"

    if description.lower().startswith(prefix.lower()):
        return description[len(prefix):].strip()

    return description

# helper: add test property
def add_testcase_property(case, Properties, Property, name, value):
    properties = case.child(Properties)

    if properties is None:
        properties = Properties()
        case.append(properties)

    properties.add_property(Property(name, value))


# This is the report builder for JUnit XML
#
# after normaling definitions form the .MK file
# and reading actual results from the logs,
# it now builds the XML file.
#
def build_junit_report(
    junit_file,
    artifact_dir,
    targets,
    groups,
    started,
    results,
    failed_test,
):
    # FIXME: I should move this up to init so it catches right at the start
    try:
        from junitparser import (
            Failure,
            JUnitXml,
            Properties,
            Property,
            Skipped,
            TestCase,
            TestSuite,
        )
    except ImportError as error:
        raise ReportError(
            "Python package 'junitparser' is required. "
            "Install it with: python3 -m pip install junitparser"
        ) from error

    xml = JUnitXml("3CCFGCLI Regression Tests")

    for group in groups:
        group_name = group["name"]
        header_id = group["header"]
        header_target = targets.get(header_id, {})

        suite = TestSuite(group_name)
        suite.add_property("header_id", header_id)

        group_description = clean_group_description(
            group_name,
            header_target.get("description"),
        )

        if group_description:
            suite.add_property(
                "description",
                group_description,
            )

        for raw_test_id in group["tests"]:
            test_id = raw_test_id.lower()
            target = targets.get(raw_test_id)

            if target is None:
                target = targets.get(test_id)

            if target is None:
                raise ReportError(
                    f"Test target is missing from Makefile: {raw_test_id}"
                )

            description = target.get("description")

            if not description and test_id in started:
                description = started[test_id]["description"]

            if not description:
                description = "No test description available"

            case = TestCase(
                test_id,
                classname=group_name,
            )

            add_testcase_property(
                case,
                Properties,
                Property,
                "description",
                description,
            )

            #
            # Per-test artefacts follow the case ID by convention:
            #
            #   t0707  -> ARTIFACT/T0707.LOG
            #   HWL64  -> ARTIFACT/HWL64.LOG
            #
            # Artefact files do usually exist, but not every test produces one.
            # Also it may be missing due to test-case failure.
            #
            # Either way, I'll only add it the file exists.
            #
            artifact_file = artifact_dir / f"{test_id.upper()}.LOG"

            if artifact_file.is_file():
                add_testcase_property(
                    case,
                    Properties,
                    Property,
                    "artifact",
                    f"ARTIFACT/{artifact_file.name}",
                )

            status = results[test_id]

            if status == "FAIL":
                failure = Failure(
                    "PASSED marker missing",
                    "assertion",
                )

                if test_id in started:
                    failure.text = (
                        f"{test_id} started at line "
                        f"{started[test_id]['line']} of the test log, "
                        "but no PASSED marker was emitted."
                    )
                else:
                    failure.text = (
                        f"{test_id} is the first planned test without "
                        "a PASSED marker."
                    )

                case.result = [failure]

            elif status == "SKIPPED":
                case.result = [
                    Skipped(
                        f"Not executed because {failed_test} failed"
                    )
                ]

            suite.add_testcase(case)

        suite.update_statistics()
        xml.add_testsuite(suite)

    xml.update_statistics()
    xml.write(junit_file, pretty=True)


# some debug header when parsing the makefile
def print_makefile_debug(targets, groups):
    print()
    print("MAKE test groups")
    print("================")
    print()

    for group in groups:
        header = group["header"]
        description = clean_group_description(
            group["name"],
            targets[header].get("description"),
        )

        print(f"{group['name']}:")
        print(f"  header      : {header}")
        print(f"  description : {description}")
        print(f"  tests       : {' '.join(group['tests'])}")
        print()

# and some debug header for the results
def print_result_debug(groups, targets, results):
    print("Test results")
    print("============")
    print()

    for group in groups:
        print(group["name"])

        for test_id in group["tests"]:
            description = targets[test_id].get("description") or ""
            print(
                f"  {test_id}: {results[test_id.lower()]}: "
                f"{description}"
            )

        print()


# ###################################
# main()
# ###################################
#
def main():
    args = parse_arguments()

    try:
        log_dir, artifact_dir, junit_file = validate_paths(
            args.logfile,
            args.makefile,
        )

        targets = load_makefile(args.makefile)
        groups = build_test_groups(targets)
        started, passed = parse_logfile(args.logfile)
        results, failed_test = classify_results(
            groups,
            started,
            passed,
        )

        build_junit_report(
            junit_file,
            artifact_dir,
            targets,
            groups,
            started,
            results,
            failed_test,
        )

    except (
        FileNotFoundError,
        ValueError,
        ReportError,
    ) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    passed_count = sum(
        status == "PASS"
        for status in results.values()
    )
    failed_count = sum(
        status == "FAIL"
        for status in results.values()
    )
    skipped_count = sum(
        status == "SKIPPED"
        for status in results.values()
    )

    # let's see what was going on when parsing ...
    if args.verbose:
        print(f"Log file       : {args.logfile}")
        print(f"Log directory  : {log_dir}")
        print(f"Artifact dir   : {artifact_dir}")
        print(f"Makefile       : {args.makefile}")
        print(f"JUnit file     : {junit_file}")
        print(f"Test groups    : {len(groups)}")
        print(f"Tests defined  : {len(results)}")
        print(f"Tests passed   : {passed_count}")
        print(f"Tests failed   : {failed_count}")
        print(f"Tests skipped  : {skipped_count}")

        print_makefile_debug(targets, groups)
        print_result_debug(groups, targets, results)

    print(f"JUnit report written: {junit_file}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
