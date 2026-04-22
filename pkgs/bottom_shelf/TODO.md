- [ ] figure out the library exports
  - should we just have a `serve` api and hide the instance of the RawServer?
- [ ] Update the compliance exception bits to be explicit about HOW we expect to fail
  - So we document how we are deciding to fail, not just that we fail

- [ ] prune the skipped results out of the compliance results - too much noise!

- [ ] Revisit `COMP-POST-CL-UNDERSEND` test failure and body timeout behavior.
  - Currently skipped because resolving it to pass compliance breaks robustness tests (which expect silent socket closure on timeout).
