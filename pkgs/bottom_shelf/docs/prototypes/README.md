# Performance prototypes — 2026-07-07

Measurement-only prototypes from the profiling investigation documented in
`../PROFILE_2026_07.md`. Each patch applies cleanly to commit `e7e8621`
(branch `bottom_shelf_perf`) from the **repo root**:

```sh
git apply pkgs/bottom_shelf/docs/prototypes/p1_serializer.patch
```

Apply one at a time (`p6_combo.patch` is the merged version of all five —
it does NOT compose with the others).

| Patch | Δ RPS | Scope | Status |
|---|---:|---|---|
| `p1_serializer.patch` | +7.3% | bottom_shelf only | productionize WITH response-header validation (ROADMAP Phase 5) |
| `p2_fusedscan.patch` | +2.9% | bottom_shelf only | safe to land as-is |
| `p3_noflush.patch` | +5.6% | bottom_shelf only | needs backpressure decision first |
| `p4_shelf_request.patch` | +4.4% | **edits pkgs/shelf** | Phase 8 upstream track; known bad-URL test failure (see report) |
| `p5_syncbody.patch` | +10.2% | **edits pkgs/shelf** | Phase 8 upstream track (`Body.bufferedBytes`) |
| `p6_combo.patch` | +29.9% | both | all five merged; carries the P4 caveat |

These are NOT production-ready: P1/P5 skip header validation, P3 removes
write backpressure, P4 removes load-bearing URL validation. They exist to
preserve the measured experiments; production versions should be
re-implemented per the report's notes and deleted from here once landed.
