# Benchmarks

Measured results and the harness/methodology for reproducing them honestly.

## Stage 2–4 — 2026-09-24: Spec Compliance, Desync Fixes & Zero-Alloc Header Scan (`pkg:bench_press` Before vs. After)

Isolated `pkg:bench_press` microbenchmark comparison across all 21 benchmark
cells in both `aot` and `jit` targets (`pkgs/_bottom_shelf_benchmarks`),
comparing the pre-Stage-2 baseline against the post-Stage-2 implementation
(strict RFC 9110 `tchar` method & `HTTP/1.x` version grammar, leading/trailing
`SP`/`HTAB` OWS trimming, zero-allocation `HeaderByteSlice` byte methods
`parseContentLength` / `scanConnectionToken` / `containsTokenIgnoreCase`,
bodyless `1xx`/`204`/`304` framing without `Transfer-Encoding: chunked`,
multi-line `Set-Cookie` emission, stream cancellation on `204`/`content-length: 0`,
and response `Content-Length` mismatch detection).

### Unvarnished Regressions / Intentional Spec Trade-Offs First

- **`write_204_no_content_set_cookie` (`aot`: `1.26 µs` → `1.34 µs`, `+77.3 ns` / `+6.1%`, `0.94x`; `jit`: `1.29 µs` → `1.39 µs`, `+101.2 ns` / `+7.8%`, `0.93x`)**:
  Previously, `writeResponse` never called `response.read()` when
  `contentLength == 0` and `requestMethod != 'HEAD'`, leaking any active
  `StreamController` attached to a `204` or `content-length: 0` response, and
  concatenated multiple `Set-Cookie` values with `', '` into a single line.
  Calling `response.read().listen(null).cancel()` and emitting separate
  `Set-Cookie:` header lines (RFC 9110 §5.3 / RFC 6265) adds ~77–101 ns per
  `204` response with multiple cookies.
- **`raw_http_parser_process (browser_get_14_headers_650b)` (`aot`: `3.50 µs` → `3.61 µs`, `+111.3 ns` / `+3.2%`, `0.97x`)**:
  Adding trailing `SP`/`HTAB` OWS scanning (`while (end > start && ...)`) on
  every header value adds ~8 ns per header across 14 headers in raw parser-only
  AOT runs, though in `jit` (`3.87 µs` → `3.49 µs`, `-9.9%`, `1.11x`) and in
  combined `process_plus_typed_headers_scan` (`3.92 µs` → `3.85 µs` AOT,
  `4.04 µs` → `3.61 µs` JIT) the zero-allocation `HeaderByteSlice` scan
  more than offsets the parser loop.

### Isolated Before vs. After Delta Table (`pkg:bench_press`, 42 cells)

<!-- mdformat off -->
| Benchmark | Target | Pre-Change Latency | Post-Change Latency | Absolute Delta | Delta (%) | Speedup vs Pre-Change |
| :--- | :--- | ---: | ---: | ---: | ---: | ---: |
| `fresh_parser_process (compact_get_54b)` | `aot` | 5.85 µs | 4.62 µs | -1.23 µs | -21.0% | **1.27x** |
| `fresh_parser_process (post_cl_upgrade_284b)` | `aot` | 7.23 µs | 5.52 µs | -1.71 µs | -23.7% | **1.31x** |
| `fresh_parser_process (browser_get_14_headers_650b)` | `aot` | 9.24 µs | 7.38 µs | -1.86 µs | -20.2% | **1.25x** |
| `fresh_parser_process (compact_get_54b)` | `jit` | 6.05 µs | 4.89 µs | -1.17 µs | -19.3% | **1.24x** |
| `fresh_parser_process (post_cl_upgrade_284b)` | `jit` | 9.30 µs | 6.29 µs | -3.01 µs | -32.3% | **1.48x** |
| `fresh_parser_process (browser_get_14_headers_650b)` | `jit` | 10.00 µs | 7.62 µs | -2.38 µs | -23.8% | **1.31x** |
| `process_plus_typed_headers_scan (compact_get_54b)` | `aot` | 505.5 ns | 457.7 ns | -47.8 ns | -9.5% | **1.10x** |
| `process_plus_typed_headers_scan (post_cl_upgrade_284b)` | `aot` | 1.88 µs | 1.78 µs | -101.7 ns | -5.4% | **1.06x** |
| `process_plus_typed_headers_scan (browser_get_14_headers_650b)` | `aot` | 3.92 µs | 3.85 µs | -62.4 ns | -1.6% | **1.02x** |
| `process_plus_typed_headers_scan (compact_get_54b)` | `jit` | 504.9 ns | 448.4 ns | -56.5 ns | -11.2% | **1.13x** |
| `process_plus_typed_headers_scan (post_cl_upgrade_284b)` | `jit` | 1.94 µs | 1.71 µs | -231.8 ns | -12.0% | **1.14x** |
| `process_plus_typed_headers_scan (browser_get_14_headers_650b)` | `jit` | 4.04 µs | 3.61 µs | -435.8 ns | -10.8% | **1.12x** |
| `typed_headers_and_lazy_byte_zero_copy_lookup` | `aot` | 648.1 ns | 522.5 ns | -125.6 ns | -19.4% | **1.24x** |
| `typed_headers_and_lazy_byte_zero_copy_lookup` | `jit` | 531.9 ns | 364.0 ns | -167.9 ns | -31.6% | **1.46x** |
| `lazy_byte_header_map_single_values_lookup` | `aot` | 665.3 ns | 554.8 ns | -110.5 ns | -16.6% | **1.20x** |
| `lazy_byte_header_map_single_values_lookup` | `jit` | 563.0 ns | 401.2 ns | -161.8 ns | -28.7% | **1.40x** |
| `hydrate_case_insensitive_map` | `aot` | 2.34 µs | 2.06 µs | -286.8 ns | -12.2% | **1.14x** |
| `hydrate_case_insensitive_map` | `jit` | 2.52 µs | 2.35 µs | -168.0 ns | -6.7% | **1.07x** |
| `hydrate_lazy_single_values_all` | `aot` | 4.74 µs | 4.09 µs | -650.8 ns | -13.7% | **1.16x** |
| `hydrate_lazy_single_values_all` | `jit` | 5.11 µs | 4.60 µs | -512.9 ns | -10.0% | **1.11x** |
| `write_200_fixed_content_length` | `aot` | 2.33 µs | 2.10 µs | -231.0 ns | -9.9% | **1.11x** |
| `write_200_fixed_content_length` | `jit` | 2.36 µs | 2.07 µs | -286.6 ns | -12.1% | **1.14x** |
| `write_200_chunked` | `aot` | 2.96 µs | 2.75 µs | -214.9 ns | -7.3% | **1.08x** |
| `write_200_chunked` | `jit` | 2.94 µs | 2.65 µs | -287.9 ns | -9.8% | **1.11x** |
| `fresh_response_plus_write_200_fixed` | `aot` | 4.29 µs | 3.94 µs | -348.5 ns | -8.1% | **1.09x** |
| `fresh_response_plus_write_200_fixed` | `jit` | 4.26 µs | 3.78 µs | -485.0 ns | -11.4% | **1.13x** |
| `write_204_no_content_set_cookie` | `aot` | 1.26 µs | 1.34 µs | +77.3 ns | +6.1% | **0.94x** |
| `write_204_no_content_set_cookie` | `jit` | 1.29 µs | 1.39 µs | +101.2 ns | +7.8% | **0.93x** |
| `raw_http_parser_process (compact_get_54b)` | `aot` | 396.6 ns | 376.4 ns | -20.3 ns | -5.1% | **1.05x** |
| `raw_http_parser_process (post_cl_upgrade_284b)` | `aot` | 1.59 µs | 1.55 µs | -37.6 ns | -2.4% | **1.02x** |
| `raw_http_parser_process (browser_get_14_headers_650b)` | `aot` | 3.50 µs | 3.61 µs | +111.3 ns | +3.2% | **0.97x** |
| `raw_http_parser_process (compact_get_54b)` | `jit` | 408.1 ns | 390.2 ns | -17.9 ns | -4.4% | **1.05x** |
| `raw_http_parser_process (post_cl_upgrade_284b)` | `jit` | 1.58 µs | 1.57 µs | -13.1 ns | -0.8% | **1.01x** |
| `raw_http_parser_process (browser_get_14_headers_650b)` | `jit` | 3.87 µs | 3.49 µs | -383.6 ns | -9.9% | **1.11x** |
| `manual_path_dispatch_static_json` | `aot` | 10.9 ns | 10.2 ns | -0.7 ns | -6.4% | **1.07x** |
| `manual_path_dispatch_static_json` | `jit` | 12.0 ns | 11.7 ns | -0.3 ns | -2.9% | **1.03x** |
| `manual_path_dispatch_param_user_42` | `aot` | 34.9 ns | 31.5 ns | -3.5 ns | -10.0% | **1.11x** |
| `manual_path_dispatch_param_user_42` | `jit` | 44.8 ns | 42.0 ns | -2.7 ns | -6.1% | **1.07x** |
| `shelf_router_static_json` | `aot` | 4.54 µs | 4.20 µs | -338.5 ns | -7.5% | **1.08x** |
| `shelf_router_static_json` | `jit` | 4.65 µs | 3.98 µs | -671.1 ns | -14.4% | **1.17x** |
| `shelf_router_param_user_42` | `aot` | 6.27 µs | 6.07 µs | -200.3 ns | -3.2% | **1.03x** |
| `shelf_router_param_user_42` | `jit` | 6.67 µs | 6.06 µs | -615.4 ns | -9.2% | **1.10x** |
<!-- mdformat on -->

## Real-NIC Two-VM Benchmarks (`gcp-http-bench` Phases 3–7 & Dart SDK CL 524644)

Measured across two collocated GCP `c2d-standard-4` VMs over a real virtual NIC
(5 interleaved trials per cell, single-isolate and 4-isolate `shared: true`
configurations):

- **Phase 3 (Single-Isolate Three-Way over Real NIC)**:
  - `/plaintext` & `/json` at saturation (64–256 conns): `bottom_shelf`
    (**~22.4k–23.1k RPS**) ties raw `dart:io` `HttpServer` (~22.5k RPS) and
    beats `shelf_io` (~13.2k RPS) by **~1.7x**.
  - `/user/<id>` (with `shelf_router`): `bottom_shelf` (**~19.1k RPS**) vs raw
    `dart:io` (**~22.3k RPS**) vs `shelf_io` (**~11.2k RPS**). The ~15% gap vs
    raw `dart:io` was isolated entirely to `shelf_router`'s `RegExp.firstMatch`
    + `request.change(context: ...)` allocation (`6.07 µs` vs `31.5 ns` manual
    dispatch in `pkg:bench_press` above).
- **Phases 4–7 & Dart SDK Gerrit CL 524644 (`dart:io` `_HttpParser` & `_HttpHeaders` optimizations)**:
  - Upstream Dart SDK Gerrit CL 524644 ported key zero-allocation lessons from
    `bottom_shelf` into `dart:io`'s `_HttpParser` and `_HttpHeaders`, narrowing
    the gap between stock `dart:io` `HttpServer` and `bottom_shelf` on raw
    `HttpServer` workloads while `bottom_shelf` continues to bypass `dart:io`
    `_HttpRequest`/`_HttpResponse` stream wrapper and `shelf_io` conversion
    overhead.

## Landed — 2026-07-07: pure-bottom_shelf perf items (+16%)

Three of the profiled optimizations landed on `bottom_shelf_perf` as
independent commits (no pkg:shelf changes), alongside two CRITICAL security
fixes. Cumulative vs the branch start `e7e8621` (5 interleaved trials):

| | median RPS | GC scavenges/300k |
|---|---:|---:|
| branch start (`e7e8621`) | 52,881 | 157 |
| + fused scan + byte serializer + flush guard | 61,454 | 103 |

**+16.2% RPS, −34% GC**, with response header-injection validation and the
cross-request buffer-reuse leak fixed (both previously CRITICAL). The
remaining prototype wins (P4/P5) require pkg:shelf changes and stay on the
Phase 8 upstream track.

## Results — 2026-07-07: profile-guided prototypes (+30%)

Full investigation in `PROFILE_2026_07.md`; prototype patches in
`prototypes/`. Same harness as below; baseline commit `e7e8621`; medians of
5 interleaved rounds; zero failed requests:

| Variant | median RPS | Δ vs HEAD |
|---|---:|---:|
| HEAD (`e7e8621`) | 53,154 | — |
| P2 fused header scan | 54,688 | +2.9% |
| P4 shelf Request tax removed | 55,491 | +4.4% |
| P3 no post-write flush | 56,126 | +5.6% |
| P1 byte-oriented serializer | 57,024 | +7.3% |
| P5 sync buffered-body path | 58,587 | +10.2% |
| **Combo (all five)** | **69,044** | **+29.9%** |

Individual deltas sum to +30.4% vs measured +29.9% — effects essentially
independent. GC: 152 → 67 scavenges per 300k requests (−56%), reproduced
exactly. Combo = 4.4x shelf_io, 3.8x raw dart:io.

## Results — 2026-07-06

Setup: AMD Ryzen 9 PRO 8945HS (8c/16t), Linux, `performance` governor,
Dart 3.13.0-266.0.dev, all servers AOT-compiled (`dart compile exe`).
Servers pinned to CPUs 0–3, load generator (ApacheBench 2.3,
`ab -k -c 50 -n 200000`, HTTP/1.1 keep-alive) pinned to CPUs 8–15.
50k-request warmup per server, then 3 trials **interleaved**
(A,B,C,A,B,C,…) to avoid thermal drift biasing later runs.
Identical hello-world `Pipeline` handlers (the dart:io ceiling has no shelf).

| Server | trial 1 | trial 2 | trial 3 | median RPS | vs shelf_io |
|---|---:|---:|---:|---:|---:|
| **bottom_shelf** | 52,261 | 53,602 | 52,975 | **52,975** | **3.4x** |
| dart:io `HttpServer` (no shelf) | 17,959 | 18,042 | 17,977 | 17,977 | 1.15x |
| shelf_io | 15,781 | 15,336 | 15,647 | 15,647 | 1.0x |

Zero failed / non-2xx responses in all runs. Closed-loop latency (indicative
only — see "coordinated omission" below): bottom_shelf p50=1ms p99=2ms;
dart:io p50=3ms p99=4ms; shelf_io p50=3ms p99=5ms.

Sanity checks performed:

- **Load generator not the bottleneck**: two parallel `ab` instances against
  bottom_shelf summed to ~52.9k RPS — the same as one instance (~53.6k). The
  single server isolate is saturated, not the client.
- **`stress_tester.dart` cross-check**: the repo's own stress tester reports
  ~47.6k RPS against the same pinned AOT server. Earlier documented figures
  (~12.3k RPS) reflected an unpinned JIT measurement setup, not server
  capability. The stress tester also counts socket `data` events rather than
  parsed responses and divides by integer seconds — see the Phase 6 roadmap
  item to fix or delete it.

The headline: bottom_shelf is ~2.9x faster than a *raw dart:io* hello-world
server. The dart:io HTTP stack itself is the dominant cost it eliminates;
shelf's object model only costs ~13% on top of dart:io (17,977 → 15,647).

## Reproduction

```sh
cd pkgs/bottom_shelf
dart compile exe benchmark/raw_bench_server.dart -o /tmp/bottom_shelf_server
dart compile exe benchmark/shelf_io_bench_server.dart -o /tmp/shelf_io_server
dart compile exe benchmark/dart_io_bench_server.dart -o /tmp/dart_io_server

# per server (ports: bottom_shelf 8081, shelf_io 8082, dart:io 8083):
taskset -c 0-3 /tmp/bottom_shelf_server &
taskset -c 8-15 ab -k -q -c 50 -n 50000  http://127.0.0.1:8081/  # warmup
taskset -c 8-15 ab -k -q -c 50 -n 200000 http://127.0.0.1:8081/  # measure
```

Interleave the measured trials across servers rather than running each
server's trials back to back.

## Methodology rules

- **Same-machine numbers are relative-only.** Pinned, governor-fixed,
  interleaved A/B runs are honest for *comparisons*; they are not publishable
  absolute figures (loopback skips the NIC; contention is load-dependent).
- **For publishable numbers**: two GCP compute-optimized VMs
  (`c2d-standard-8` or `c4-standard-8` — never e2/burstable), same zone,
  compact placement policy, internal IPs; roughly $1/hour total.
- **Coordinated omission**: closed-loop tools (ab, wrk) stop sampling during
  server stalls, so their tail-latency numbers lie. Quote throughput from
  closed-loop runs; quote latency only from a fixed-rate run at ~60–70% of
  max throughput with a latency-correcting tool (e.g. `oha -q <rate>
  --latency-correction`).
- **AOT vs JIT**: benchmark what people deploy (AOT); AOT is also flat from
  the first request, which makes comparisons reproducible. JIT needs 30–60s
  of warmup under load and can differ by ~10% either direction.
- **Disclose isolate count**: these numbers are a single isolate. Multi-
  isolate (`shared: true`) changes rankings more than most framework
  differences.
- Run ≥3 (ideally 5) interleaved trials; report the median, never a single
  run; report failed/non-2xx counts alongside RPS.

Key sources: mnot's "On HTTP Load Testing", Gil Tene's wrk2/coordinated-
omission work, TechEmpower FrameworkBenchmarks methodology, pyperf system
tuning docs.
