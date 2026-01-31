#!/bin/bash

set -e  # Exit on any error

ERRORS=0

run_command() {
		if [ "$LINT_MODE" == "STRICT" ]; then
				"$@" || ERRORS=$((ERRORS + 1))
		else
				"$@"
		fi
}

if [ "$ACTION" == "install" ]; then 
	if [ -n "$SRCROOT" ]; then
		exit
	fi
fi

LINT_RUNNER="mise exec"

SWIFT_FORMAT_RUNNER="$LINT_RUNNER spm:swiftlang/swift-format -- swift-format"
SWIFTLINT_RUNNER="$LINT_RUNNER aqua:realm/SwiftLint -- swiftlint"
STRINGSLINT_RUNNER="$LINT_RUNNER spm:dral3x/StringsLint -- stringslint"

function lint_swift_package() {
    pushd "$1"
    if [ -z "$CI" ]; then
        run_command $SWIFT_FORMAT_RUNNER format $SWIFTFORMAT_OPTIONS --recursive --parallel --in-place Sources Tests Package
        run_command $SWIFTLINT_RUNNER --fix
    else
        set -e
    fi
    if test -f .stringslint.yml; then
        run_command $STRINGSLINT_RUNNER lint $STRINGSLINT_OPTIONS
    fi

    run_command $SWIFTLINT_RUNNER lint $SWIFTLINT_OPTIONS
    run_command $SWIFT_FORMAT_RUNNER lint --recursive --parallel $SWIFTFORMAT_OPTIONS Sources Tests Package
    popd
}

echo "LintMode: $LINT_MODE"
echo "Lint runner: $LINT_RUNNER"

if [ "$LINT_MODE" == "NONE" ]; then
		exit
elif [ "$LINT_MODE" == "STRICT" ]; then
		SWIFTFORMAT_OPTIONS=""
		SWIFTLINT_OPTIONS="--strict"
		STRINGSLINT_OPTIONS="--config .strict.stringslint.yml"
else
		SWIFTFORMAT_OPTIONS=""
		SWIFTLINT_OPTIONS=""
		STRINGSLINT_OPTIONS="--config .stringslint.yml"
fi

if [ -z "$SRCROOT" ]; then
		SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
		PACKAGE_PARENT_DIR="${SCRIPT_DIR}/../Packages"
else
		PACKAGE_PARENT_DIR="${SRCROOT}/Packages"
fi

pushd $PACKAGE_PARENT_DIR

for packageDirectory in $PACKAGE_PARENT_DIR/*; do
		DIR_NAME=$(basename "$packageDirectory")
		if [ "$DIR_NAME" != "HarvestBinKit" ]; then
				continue
		fi
		lint_swift_package "$packageDirectory"
done

if [ "$LINT_MODE" == "STRICT" ] && [ $ERRORS -gt 0 ]; then
		echo "Linting failed with $ERRORS error(s)"
		exit 1
fi