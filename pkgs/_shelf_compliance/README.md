This package contains HTTP/1.1 compliance and hardening tests for `package:shelf` and future implementations.

It uses the [Http11Probe](https://github.com/MDA2AV/Http11Probe) tool (vendored as a git submodule) to validate the server's behavior against RFC requirements and common edge cases.

## Current Baseline

You can view the current compliance report for `package:shelf` here:
*   [Shelf Compliance Summary](shelf_summary.md)

## How it Works

The tests are defined in `test/compliance_test.dart`. For each test category (e.g., `Compliance`, `Smuggling`, `MalformedInput`):
1.  It starts an echo server (e.g., `bin/shelf_echo.dart`) on a dynamic port.
2.  It runs the .NET `Http11Probe` CLI tool against that port.
3.  It saves the raw JSON report to `reports/[name]/[category].json`.
4.  It compares the result with the established "golden" file in the same location.
5.  After all categories are run, it generates a combined summary file in the root (e.g., `shelf_summary.md`).

## Running the Tests

You need the **.NET 10 SDK** installed to run these tests.

To run the full suite:
```bash
dart test
```

### Updating Goldens

If you intentionally change behavior and need to update the baseline:
1.  Set `const _updateGoldens = true;` in `test/compliance_test.dart`.
2.  Run `dart test`. It will update the JSON and Markdown files and fail the test at the end to remind you to turn it off.
3.  Set `_updateGoldens = false` and commit the new goldens.

## Project Structure

*   `bin/`: Echo server implementations (the "dut" or device under test).
*   `reports/`: Golden JSON reports per category.
*   `test/`: The test runner harness.
*   `tool/`: Scripts to post-process JSON reports into Markdown.
