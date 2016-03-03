#!/bin/bash

# Fast fail the script on failures.
set -e

pub run test -p vm,content-shell,firefox

# Install dart_coveralls; gather and send coverage data.
if [ "$COVERALLS_TOKEN" ] && [ "$TRAVIS_DART_VERSION" = "stable" ]; then
  pub global activate dart_coveralls

  pub global run dart_coveralls report \
    --exclude-test-files \
    test/test_all.dart
fi
