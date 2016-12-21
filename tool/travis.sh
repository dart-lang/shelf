#!/bin/bash

# Fast fail the script on failures.
set -e

THE_COMMAND="pub run test -p $TEST_PLATFORM"
if [ $TEST_PLATFORM == 'firefox' ] || [ $TEST_PLATFORM == 'content-shell' ]; then
    # browser tests don't run well on travis unless one-at-a-time
    THE_COMMAND="$THE_COMMAND -j 1"
fi

echo $THE_COMMAND
exec $THE_COMMAND

# Install dart_coveralls; gather and send coverage data.
if [ $TEST_PLATFORM == 'vm' ] && [ "$COVERALLS_TOKEN" ] && [ "$TRAVIS_DART_VERSION" = "stable" ]; then
  pub global activate dart_coveralls

  pub global run dart_coveralls report \
    --exclude-test-files \
    test/test_all.dart
fi
