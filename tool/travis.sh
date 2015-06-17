#!/bin/bash

# Fast fail the script on failures.
set -e

pub run test

# Install dart_coveralls; gather and send coverage data.
if [ "$COVERALLS_TOKEN" ] && [ "$TRAVIS_DART_VERSION" = "stable" ]; then
  echo "Skipping coverage until https://github.com/dart-lang/scheduled_test/issues/20 is fixed"
#
#  pub global run dart_coveralls report \
#    --exclude-test-files \
#    test/test_all.dart
fi
