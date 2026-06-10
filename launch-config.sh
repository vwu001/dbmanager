#!/bin/bash
# Editable install paths for launching Studio. Update here if versions change.
# Every value is overridable via environment (used by tests).

IDEA_CE_HOME="${IDEA_CE_HOME:-/Applications/IntelliJ_2024_1_5.app/Contents}"
IDEA_UT_HOME="${IDEA_UT_HOME:-/Applications/IntelliJ_UT_2024_1_5.app/Contents}"
STUDIO_JAVA_HOME="${STUDIO_JAVA_HOME:-/Library/Java/JavaVirtualMachines/amazon-corretto-21.jdk/Contents/Home}"
BAMBOO_ROOT="${BAMBOO_ROOT:-${HOME}/dev/bamboo}"

# Snapshot-only roots that must NOT be launched (space-separated).
EXCLUDED_ROOTS="${EXCLUDED_ROOTS:-gw gw-r1-tx}"
