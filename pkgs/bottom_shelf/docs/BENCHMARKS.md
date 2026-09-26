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

## Bare-Metal W1–W8 HTTP Matrix (`Bluefin-DX`, `e405cae` → `b1f8998`)

Measured on bare-metal Linux (`AMD Ryzen 9 PRO 8945HS`, 16 cores, `performance`
CPU frequency governor, `0.00%` hypervisor steal time, `Dart 3.14.0-265.0.dev`
AOT). Servers pinned to `CPU 0` (`1` isolate) or `CPU 0-3` (`4` isolates,
`shared: true`), `wrk` (`-t 4 -c 64`) pinned to `CPU 4-7`, `3` interleaved
trials × `3s` per cell (`shelf_io` → `bottom_shelf` → `dart:io`), reporting
median RPS:

| ID | Endpoint | Iso | Pre `bottom_shelf` RPS (`e405cae`) | Post `bottom_shelf` RPS (`b1f8998`) | `bottom_shelf` After vs. Before | Post `shelf_io` RPS | Post `dart:io` RPS | Post `bs` vs `shelf_io` | Post `bs` vs `dart:io` | Post `bottom_shelf` p50 / p99 (ms) |
| :--- | :--- | ---: | ---: | ---: | :--- | ---: | ---: | ---: | ---: | ---: |
| **W1** | `GET /plaintext` | 1 | 43,187 | **48,772** | **1.13x (`+12.9%`)** | 23,417 | 38,610 | **2.08x** | **1.26x** | 1.28 / 2.07 |
| **W2** | `GET /json` | 1 | 41,703 | **47,139** | **1.13x (`+13.0%`)** | 23,016 | 37,175 | **2.05x** | **1.27x** | 1.33 / 1.70 |
| **W3** | `GET /user/42` | 1 | 37,438 | **43,199** | **1.15x (`+15.4%`)** | 21,226 | 36,706 | **2.04x** | **1.18x** | 1.45 / 1.79 |
| **W4** | `GET /headers-auth` | 1 | 26,358 | **34,826** | **1.32x (`+32.1%`)** | 16,692 | 26,533 | **2.09x** | **1.31x** | 1.79 / 3.37 |
| **W5** | `POST /echo-json` | 1 | 26,807 | **31,734** | **1.18x (`+18.4%`)** | 15,908 | 24,763 | **1.99x** | **1.28x** | 1.97 / 2.78 |
| **W6** | `POST /upload-chunked` | 1 | 17,693 | **18,632** | **1.05x (`+5.3%`)** | 12,671 | 18,093 | **1.47x** | **1.03x** | 3.60 / 5.20 |
| **W7a** | `GET /large-256k` | 1 | 3,858 | **13,019** | **3.37x (`+237.5%`)** | 10,468 | 11,310 | **1.24x** | **1.15x** | 4.83 / 6.52 |
| **W7b** | `GET /large-1m` | 1 | 1,275 | **4,976** | **3.90x (`+290.3%`)** | 4,503 | 4,674 | **1.11x** | **1.06x** | 12.71 / **17.95** |
| **W8-W1** | `GET /plaintext` | 4 | 184,996 | **208,601** | **1.13x (`+12.8%`)** | 99,994 | 159,529 | **2.09x** | **1.31x** | 0.29 / 2.54 |
| **W8-W2** | `GET /json` | 4 | 181,616 | **202,661** | **1.12x (`+11.6%`)** | 97,234 | 153,294 | **2.08x** | **1.32x** | 0.29 / 1.65 |
| **W8-W4** | `GET /headers-auth` | 4 | 107,756 | **144,073** | **1.34x (`+33.7%`)** | 68,705 | 104,901 | **2.10x** | **1.37x** | 0.39 / 1.88 |
| **W8-W5** | `POST /echo-json` | 4 | 112,384 | **132,327** | **1.18x (`+17.7%`)** | 66,544 | 97,140 | **1.99x** | **1.36x** | 0.45 / 2.01 |

- **`12 / 12` Rows Ahead**: `bottom_shelf` (`b1f8998`) beats **both `shelf_io`
  (`1.11x–2.10x`, geomean `1.79x`) and raw `dart:io` (`1.03x–1.37x`)** across
  every workload quadrant. On `W6` (`POST /upload-chunked`), `shelf_io` spans
  `9,942–12,671` RPS across the three plain non-capture runs (vs `bottom_shelf`
  `17,693–18,936` RPS), yielding a within-run ratio of `1.47x–1.82x` (`1.47x`
  in `bluefin_post_fix_matrix`).
- **`W7a` (`256 KB`, `3.37x`) & `W7b` (`1 MB`, `3.90x`) — Large-Payload Memory,
  Bandwidth & Syscall Attribution**:
  - **Capped `isFirst` Coalescing (`<= 16 KB`)**: Eliminates old-space
    `Uint8List` allocation and user-space `memcpy` for large bodies, cutting
    in-process `_WireSocket` serialization latency by **`40.5x`** on `256 KB`
    (`200.0 µs` → `4.94 µs`, `49.4 GB/s`) and **`39.6x`** on `1 MB`
    (`733.1 µs` → `18.52 µs`, `52.7 GB/s` — ~60% of single-threaded DRAM copy
    bandwidth) and cutting kernel-tracked peak RSS (`VmHWM`) by **`-68%`
    (`~130 MB`)** (`190.2 MB` → `60.5 MB` on `W7a`; `189.5 MB` → `61.5 MB` on
    `W7b`).
  - **Synchronous `Body.takeBufferedBytes()`**: Eliminates `Stream`/`Future`
    allocation on buffered responses (`1.10x` / `-0.11 µs` on `13 B` payloads in
    microbenchmarks; noise on `>= 256 KB` payloads dominated by memory copy).
  - **Pipelined `socket.flush()` Hysteresis**: Gating `await socket.flush()` on
    pipelined depth (`>= 16` responses) drops `1 MB` `p99` tail latency by
    **11.3x** (`202.27 ms` → `17.95 ms`).
  - **Flat ~60 MB RSS Arena & Syscall Profile**: Under load, `bottom_shelf`
    holds a flat `58.0–61.5 MB` `VmHWM` across all 1-isolate `GET` and
    single-packet `POST` workloads (`13 B` through `1 MB`), rising to `76.1 MB`
    on `W6` (`64 KB` chunked upload stream, where all three servers rise
    together; `58.0–76.1 MB` overall). On `W7b` (`1 MB`), total syscalls/req
    drop from `22.47` → `12.74` as `mmap`/`munmap`/`futex` GC churn disappears,
    even though socket syscalls increase slightly (`3.47` → `4.40` from writing
    header and body buffers separately). On `/plaintext` (`W1`), `bottom_shelf`
    issues **`9.68` total syscalls/req** (**`3.39` socket-only**: `1.13 write`,
    `0.01 getpeername`) vs `shelf_io`'s **`14.79` total syscalls/req**
    (**`4.39` socket-only**: `2.13 write`, `2.00 getpeername`).
- **`W4` (`Request.change` Middleware, `1.32x` End-to-End / `3.34x` Context-Only
  In-Process)**: Implementing `Headers` on `LazyByteHeaderMap` and adding
  `Request._fastChange` eliminates the 3-map allocation cascade (`CoV` in
  `pkg:bench_press` collapsed from `±18.0%` to `±1.5%`).

## Real-NIC Two-VM Benchmarks (`gcp-http-bench`)

Measured across two collocated GCP `c2d-standard-4` VMs over a real virtual NIC
(5 interleaved trials per cell, single-isolate and 4-isolate `shared: true`
configurations):

- **Single-Isolate Three-Way over Real NIC**:
  - `/plaintext` & `/json` at saturation (64–256 conns): `bottom_shelf`
    (**~22.4k–23.1k RPS**) ties raw `dart:io` `HttpServer` (~22.5k RPS) and
    beats `shelf_io` (~13.2k RPS) by **~1.7x–2.0x** (`p50 = 0.141ms`, `1.00`
    `write()` syscall/req vs `2.13` `write()` syscalls/req for `shelf_io`).
  - `/user/<id>` (with `shelf_router`): `bottom_shelf` (**~19.1k RPS**) vs raw
    `dart:io` (**~22.3k RPS**) vs `shelf_io` (**~11.2k RPS**).

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
