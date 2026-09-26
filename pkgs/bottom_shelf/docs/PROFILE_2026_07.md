# Overnight profiling report — bottom_shelf performance investigation

**2026-07-07, machine idle. TL;DR: profile-guided prototypes yield +30% RPS
(53.2k → 69.0k) and 56% less garbage, with the five optimizations measured
independently and their effects almost perfectly additive. The two biggest
wins need the pkg:shelf additive API (Phase 8); two are pure bottom_shelf
changes landable now; one needs a backpressure design decision.**

Everything below ran on the idle machine (load < 1.2 verified before the
showdown), AOT binaries, server pinned CPUs 0–3, ab pinned CPUs 8–15,
50k-request warmups, 5 interleaved rounds, `ab -k -c 50 -n 200000`,
zero failed requests everywhere. Baseline was commit `e7e8621`; each
prototype is a patch in `docs/prototypes/` (apply from the repo root with
`git apply`).

## Phase 1: Where do the ~19µs/request actually go?

**CPU profile** (VM sampling profiler via vm_service, JIT, 12,390 samples
under load — JIT attribution is directionally right for AOT):

| Self time | What |
|---:|---|
| 38.7% | `_NativeSocket._nativeWrite` (the write syscall) |
| 14.4% | `_NativeSocket._nativeRead` |
| 4.7% | `_NativeSocket._nativeAvailable` (FIONREAD before each read) |
| ~2% | event-handler plumbing |
| 1.9% | `RawHttpParser.process` |
| ~3.5% | serializer: utf8 encode + string concat + interpolate |
| ~2.5% | Map operations (insert/init/set — TypedHeaders cache, context) |
| ~6% | async machinery self time (zones, futures, microtasks, scattered) |

**≈60% of all CPU is inside socket syscall natives.** Loopback writes do the
receiver-side work on the caller's thread, so this is real, mostly
irreducible per-write cost. The addressable budget is the other ~40%.

Inclusive view: `writeResponse` 49.8% (of which ~40% is the write itself);
the `await for`/Stream machinery around body delivery
(`_StreamIterator._onData` 41.3%, `_MultiStreamController.addSync` 41.7%,
`_Future._propagateToListeners` 44.7%) confirmed the body-stream hop tax as
the biggest addressable slab — which is what P5 then proved.

**Allocation census** (vm_service allocation profile; absolute counts are
sampled, ratios normalized per Response): ~76 `Context` + ~64 `_Closure`
per request dominate — async/closure churn, not domain objects. Also visible
per request: 3 `CaseInsensitiveMap` (shelf header copies), ~3 Uri objects,
2 `StringBuffer` + 2 `_Utf8Encoder` (serializer), 8 `HeaderByteSlice` +
4 `HeaderEntrySlices` (ab sends 4 headers; matches 2 slices+1 entry per
header exactly).

**Syscall census** (strace -c over 20k requests): 1.13 `write` + 1.13
`read` per request — **the "one write per response" coalescing claim is
verified**. Overhead: 2.0 `ioctl` (FIONREAD), 4.3 `rt_sigprocmask`,
1.13 `epoll_wait` per request — all dart:io/VM internals, not addressable
from package code.

## Phase 2+3: Five prototypes, measured independently

Each prototype was built as an isolated patch off HEAD (`e7e8621`),
analyzer clean, full test suite run, then reverted. Medians of 5
interleaved rounds:

| Binary | median RPS | Δ vs HEAD | tests |
|---|---:|---:|---|
| HEAD (`e7e8621`) | 53,154 | — | 124/124 |
| P2 fused header scan | 54,688 | **+2.9%** | 124/124 |
| P4 shelf Request tax removed | 55,491 | **+4.4%** | 123/124¹ |
| P3 no post-write flush | 56,126 | **+5.6%** | 124/124 |
| P1 byte-oriented serializer | 57,024 | **+7.3%** | 124/124 |
| P5 sync buffered-body path | 58,587 | **+10.2%** | 124/124 |
| **Combo (all five)** | **69,044** | **+29.9%** | 123/124¹ |

HEAD's own spread across the session was 52.8k–54.0k (±1.2%), so every
delta is well outside noise. Individual deltas sum to +30.4% vs the
measured +29.9% — the effects are essentially independent.

**GC receipt**: 152 → 67 scavenges per 300k identical requests
(HEAD vs combo), reproduced exactly on a second run: **56% less garbage.**

**Context**: combo at 69.0k RPS is **4.4× shelf_io** (15.6k) and
**3.8× raw dart:io** (18.0k) on this machine.

¹ The one failing test under P4 is real and informative — see below.

## What each prototype is, and its path to production

**P5 — synchronous buffered-body path (+10.2%)** `patches/p5_syncbody.patch`
Adds `Body.bufferedBytes` to shelf (String/List/null bodies keep their bytes
reachable synchronously; the wrapping Stream is only built if `read()` is
called) + a serializer fast path that writes headers+body in one
`socket.add` with no `await for`. This is exactly ROADMAP Phase 8's
"Body.bufferedBytes" candidate, now with receipts. **Ships additively in a
shelf minor.** The profile said the stream machinery was the biggest
addressable slab; the measurement agrees.

**P1 — byte-oriented serializer (+7.3%)** `patches/p1_serializer.patch`
Pure bottom_shelf. Const status-line bytes, static ASCII scratch buffer
(materialized to heap before any await — the scratch is shared across
interleaving connections), no `toLowerCase`/`join`/`StringBuffer`/utf8
round-trip, content-length captured during the existing headersAll
iteration so `Message.contentLength` (which hydrates shelf's entire
`singleValues` map per response) is never called. **Productionize together
with response-header CRLF validation (Phase 5 bug #2)** — the byte writer
is the right place for it, and validation-by-default may give back a
point or two of this win (worth measuring, not assuming). Note: prototype
writes header strings as Latin-1 with `?` for >0xFF code units; the old
code wrote UTF-8 (neither is validated today).

**P3 — drop `await socket.flush()` per response (+5.6%)**
`patches/p3_noflush.patch` (a 3-line change)
The flush didn't add syscalls; it added an event-loop round trip before the
connection would accept the next pipelined request. Removing it lets
request N+1 parse while N's bytes drain. **Needs a design decision before
landing**: without the flush await there is no per-response backpressure
between keep-alive requests, so a slow client + fast handler can grow the
socket's internal buffer unboundedly. Options: flush every N responses,
flush only when `socket.bufferedAmount`-equivalent is unavailable (dart:io
doesn't expose it), or accept and document the risk with a byte-count
guard in the connection.

**P4 — strip shelf Request constructor tax (+4.4%)** 
`patches/p4_shelf_request.patch`
Lazy `url`/`handlerPath` (`late final`), constructor validation removed,
context map retained by reference instead of defensively copied. This is
Phase 8 candidates 1+2+4+5 in one patch. **The one failing test is the
important finding**: "a bad HTTP URL request results in a 400 response"
times out, because malformed percent-encoding is currently rejected *by*
shelf's constructor validation (`requestedUri.pathSegments` throwing →
ArgumentError → 400). Same lesson as dart-lang/shelf#369: the validation is
load-bearing for exactly one input class. A production `Request.adapter`
needs the adapter to own that rejection — bottom_shelf can map
`FormatException` to 400 at dispatch (lazy, free on the happy path) instead
of paying eager validation per request.

**P2 — fused header scan (+2.9%)** `patches/p2_fusedscan.patch`
Pure bottom_shelf. One pass over the header slices in the TypedHeaders
constructor computes content-length count/validity/value, TE presence,
chunked-ness, host + duplicate-host, and the Connection token — replacing
~8 separate walks and the per-request `_cache` map inserts. Duplicate-
counting semantics preserved (verified by the smuggling/robustness tests).
Safe to land as-is.

## What this means for the roadmap

1. The 2026-07-06 "allocation micro-fixes don't matter" conclusion stands —
   but structural changes (fewer awaits, fewer string round-trips, fewer
   map copies) matter a lot. Phase 6's ranking should be: serializer
   rewrite ≫ fused scan ≫ parser work (parser is only 1.9% self — demote
   the line-scan rewrite).
2. **Phase 8 now has its receipts.** P4+P5 together are +14.6% measured,
   from shelf-side changes that ship additively (modulo the adapter owning
   bad-URL rejection). That's the number to put in the design issue.
3. Suggested landing order:
   a. P2 (safe, pure bottom_shelf) and P1 (with Phase 5 header validation
      built in — fixes a CRITICAL bug and gets +7% in the same change).
   b. P3 after the backpressure decision.
   c. File the shelf design issue with the P4/P5 numbers; prototype
      `Request.adapter` + `Body.bufferedBytes` properly against shelf's
      own test suite.
4. Even with all five, ~60%+ of remaining CPU is socket syscalls. The next
   big lever isn't in this package's code: it's multi-isolate
   (`shared: true`) for machine-level throughput, or kernel-level batching
   — worth stating in docs so nobody chases the last 10% in Dart.

## Reproduction

- Patches: `docs/prototypes/p{1..6}_*.patch` — apply ONE at a time from the
  repo root with `git apply pkgs/bottom_shelf/docs/prototypes/<p>.patch`,
  then `dart compile exe benchmark/raw_bench_server.dart`. See
  `docs/prototypes/README.md`.
- Benchmark harness: the pinned/interleaved recipe in `docs/BENCHMARKS.md`.
- CPU + allocation profiler client: `tool/vm_profile.dart`. Start the
  server with
  `dart --disable-service-auth-codes --enable-vm-service=8181 --profiler benchmark/raw_bench_server.dart`,
  then `dart tool/vm_profile.dart ws://127.0.0.1:8181/ws cpu-clear`, apply
  load, and `... cpu` / `... alloc-reset` / `... alloc-read`.
- Syscall census: `strace -c -f -p <server pid>` during a fixed-N ab run.

Caveats for honesty: same-machine loopback numbers, relative-only as always
(see docs/BENCHMARKS.md); CPU profile taken under JIT; P4/combo carry the
known bad-URL test failure; P1/P5 prototypes skip header validation that
production code must have.
