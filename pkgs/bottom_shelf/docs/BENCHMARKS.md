# Benchmarks

Measured results, architectural attribution, and methodology for reproducing
them honestly. Full raw telemetry JSON and automated harnesses live in
`kevmoo/gcp-http-bench`.

## 1. Bare-Metal W1–W8 HTTP Matrix (`Bluefin-DX`)

Measured on idle bare-metal Linux (`AMD Ryzen 9 PRO 8945HS`, 16 cores,
`performance` CPU frequency governor, `0.00%` hypervisor steal time,
`Dart 3.14.0-265.0.dev` AOT). All three targets (`shelf_io`, `bottom_shelf`,
`dart:io`) are pinned to the same `dart-lang/shelf@bottom_shelf` revision
(`cbc127f`, including `shelf` `1.4.3-wip` and `shelf_router`). Servers are
pinned via `taskset` to `CPU 0` (`1` isolate) or `CPU 0-3` (`4` isolates,
`shared: true`), with `wrk` (`-t 4 -c 64`) pinned to `CPU 4-7` across `3`
interleaved trials × `3s` per cell (`36/36` cells `is_stable`, worst `CoV`
`2.85%`; source: `results/bluefin_deps_aligned_matrix.json` in
`kevmoo/gcp-http-bench`):

| Workload | Endpoint | Isolates | `shelf_io` RPS | `bottom_shelf` RPS | `dart:io` RPS | `bottom_shelf` vs `shelf_io` | `bottom_shelf` vs `dart:io` | Worst CoV | `shelf_io` p50 / p99 (ms) | `bottom_shelf` p50 / p99 (ms) | `dart:io` p50 / p99 (ms) |
| :--- | :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **W1** | `GET /plaintext` | 1 | 24,139 | **47,715** | 39,585 | **1.98x** (+97.7%) | **1.21x** (+20.5%) | 2.4% | 2.62 / 3.01 | **1.32 / 1.61** | 1.58 / 1.93 |
| **W2** | `GET /json` | 1 | 23,497 | **45,879** | 38,483 | **1.95x** (+95.3%) | **1.19x** (+19.2%) | 0.8% | 2.70 / 3.16 | **1.38 / 1.67** | 1.64 / 1.88 |
| **W3** | `GET /user/42` | 1 | 21,882 | **42,027** | 37,595 | **1.92x** (+92.1%) | **1.12x** (+11.8%) | 0.9% | 2.90 / 3.36 | **1.50 / 1.83** | 1.68 / 2.00 |
| **W4** | `GET /headers-auth` | 1 | 17,406 | **34,620** | 27,188 | **1.99x** (+98.9%) | **1.27x** (+27.3%) | 0.6% | 3.65 / 4.21 | **1.82 / 2.18** | 2.33 / 2.67 |
| **W5** | `POST /echo-json` | 1 | 16,429 | **30,644** | 25,515 | **1.87x** (+86.5%) | **1.20x** (+20.1%) | 0.6% | 3.88 / 4.38 | **2.06 / 2.70** | 2.48 / 2.81 |
| **W6** | `POST /upload-chunked` | 1 | 13,442 | **19,386** | 18,713 | **1.44x** (+44.2%) | **1.04x** (+3.6%) | 1.7% | 5.81 / 6.80 | **3.61 / 4.91** | 3.99 / 5.07 |
| **W7a** | `GET /large-256k` | 1 | 10,836 | **13,142** | 11,489 | **1.21x** (+21.3%) | **1.14x** (+14.4%) | 1.2% | 5.84 / 6.70 | **4.82 / 5.45** | 5.53 / 6.11 |
| **W7b** | `GET /large-1m` | 1 | 4,605 | **4,981** | 4,763 | **1.08x** (+8.2%) | **1.05x** (+4.6%) | 0.9% | 13.87 / 15.14 | **12.77 / 16.89** | 13.36 / 15.09 |
| **W8-W1** | `GET /plaintext` | 4 | 99,743 | **209,667** | 158,235 | **2.10x** (+110.2%) | **1.33x** (+32.5%) | 2.4% | 0.61 / 1.26 | **0.30 / 1.71** | 0.38 / 0.95 |
| **W8-W2** | `GET /json` | 4 | 97,343 | **201,037** | 151,724 | **2.07x** (+106.5%) | **1.33x** (+32.5%) | 2.5% | 0.59 / 1.78 | **0.31 / 2.16** | 0.41 / 1.04 |
| **W8-W4** | `GET /headers-auth` | 4 | 70,099 | **145,903** | 104,381 | **2.08x** (+108.1%) | **1.40x** (+39.8%) | 2.9% | 0.92 / 1.36 | **0.40 / 1.69** | 0.60 / 1.08 |
| **W8-W5** | `POST /echo-json` | 4 | 67,970 | **132,125** | 97,513 | **1.94x** (+94.4%) | **1.35x** (+35.5%) | 0.8% | 0.94 / 1.55 | **0.44 / 1.01** | 0.65 / 1.17 |

- **`12 / 12` Rows Ahead**: `bottom_shelf` beats **both `shelf_io`
  (`1.08x–2.10x` in `results/bluefin_deps_aligned_matrix.json`; `1.11x–2.10x`,
  geomean `1.82x` in `results/bluefin_post_fix_matrix.json`) and raw `dart:io`
  (`1.04x–1.40x`)** across every workload quadrant.

## 2. Real-NIC Two-VM Benchmarks (`gcp-http-bench`)

Measured across two collocated GCP `c2d-standard-4` VMs (`COLLOCATED` compact
placement policy) over a real virtual NIC (5 interleaved trials per cell,
single-isolate and 4-isolate `shared: true` configurations):

- **Single-Isolate Three-Way over Real NIC**:
  - `/plaintext` & `/json` at saturation (`64–256` connections): `bottom_shelf`
    (**~22.4k–23.1k RPS**) ties raw `dart:io` `HttpServer` (~22.5k–23.7k RPS)
    and beats `shelf_io` (~11.8k–13.2k RPS) by **~1.7x–2.0x** (`p50 = 0.141ms`,
    `1.00` `write()` syscall/req vs `2.13` `write()` syscalls/req for
    `shelf_io`).
  - `/user/<id>` (with `shelf_router`): `bottom_shelf` (**~19.1k RPS**) vs raw
    `dart:io` (**~22.3k RPS**) vs `shelf_io` (**~11.2k RPS**).

## 3. Where the Speedup Comes From (Ablation & `pkg:shelf` Hook Attribution)

In-process microbenchmarks (`targets/bench_press/benchmark/bottom_shelf_bench_press.dart`
and `results/bluefin_deps_aligned_matrix_bench_press.json` in
`kevmoo/gcp-http-bench`, `66/66` cells stable across `aot` and `jit`), CPU
profiles (`perf` / `vm_service`), and kernel `strace -c` / `/proc/smaps_rollup`
captures isolate the exact contribution of each mechanism and `pkg:shelf` hook:

- **CPU, GC & Syscall Baseline (`strace -c` & `vm_service` / `perf`)**:
  - Under single-isolate loopback load, **~60% of CPU is inside socket syscall
    natives** (`_NativeSocket._nativeWrite` `38.7%`, `_nativeRead` `14.4%`,
    `_nativeAvailable` `4.7%`), while `RawHttpParser.process` accounts for only
    **`1.9%` self-time**.
  - On `/plaintext` (`W1`), `bottom_shelf` issues **`9.68` total syscalls/req**
    (**`3.39` socket-only**: `1.13 write`, `0.01 getpeername`) vs `shelf_io`'s
    **`14.79` total syscalls/req** (**`4.39` socket-only**: `2.13 write`,
    `2.00 getpeername`), reducing young-space GC scavenges by **`-56%`**
    (`152` → `67` scavenges per 300k requests).
- **`pkg:shelf` Hook 1 — Synchronous `Body.takeBufferedBytes()` (`+10.2%`
  isolated RPS; `1.10x` / `-0.11 µs` on `13 B` in-process)**:
  - Retains the backing `Uint8List` on `Body` for buffered responses (`String`,
    `Uint8List`, `List<int>`, `null`), only allocating a `Stream` if `read()`
    is called.
  - Lets `RawShelfResponseSerializer.writeResponse` extract buffered body bytes
    synchronously and coalesce status line, headers, and body into a single
    `socket.add` call without `async`/`await` or `_StreamIterator` churn.
- **`pkg:shelf` Hook 2 — `Headers`, `Headers.adopt`, `findHeader`, and
  `Request._fastChange` (`W4`: `1.32x` / `+32.1%` end-to-end RPS from `26,358`
  → `34,826` RPS; `3.34x` context-only in-process; `+4.4%` on bare `GET /`)**:
  - Exporting `Headers` so `LazyByteHeaderMap` implements `Headers`, updating
    `findHeader` to use zero-copy `headers[name]` lookup, and adding
    `Request._fastChange` + `Headers.adopt` eliminates the 3-map allocation
    cascade and redundant `requestedUri.pathSegments` re-validation on
    `Request.change()` (collapsing in-process `CoV` from `±18.0%` to `±1.5%`).
  - Combined with `Body.takeBufferedBytes()`, the additive `pkg:shelf` hooks
    contribute **`+14.6%`** on bare `GET /` and **`+32.1%`** on middleware-heavy
    routes (`W4`).
- **Capped `isFirst` Coalescing (`<= 16 KB`) & Pipelined `socket.flush()`
  Hysteresis (`W7a` `256 KB`: `3.37x` RPS from `3,858` → `13,019`; `W7b` `1 MB`:
  `3.90x` RPS from `1,275` → `4,976`)**:
  - **Capped Coalescing (`<= 16 KB`)**: Eliminates old-space `Uint8List`
    allocation and user-space `memcpy` for large bodies (`> 16 KB`), cutting
    in-process `_WireSocket` serialization latency by **`40.5x`** on `256 KB`
    (`200.0 µs` → `4.94 µs`, `53.1 GB/s`) and **`39.6x`** on `1 MB`
    (`733.1 µs` → `18.52 µs`, `56.6 GB/s`), cutting kernel-tracked peak RSS
    (`VmHWM`) by **`-68%` (`~130 MB`)** (`190.2 MB` → `60.5 MB` on `W7a`;
    `189.5 MB` → `61.5 MB` on `W7b`), and dropping `W7b` total syscalls/req
    from `22.47` → `12.74` as `mmap`/`munmap`/`futex` GC churn disappears.
  - **Pipelined `socket.flush()` Hysteresis**: Gating `await socket.flush()` on
    pipelined depth (`>= 16` responses and `>= 256 KB` queued; `+5.6%` RPS on
    small responses) drops `1 MB` `p99` tail latency by **`11.3x`**
    (`202.27 ms` → `17.95 ms`).
  - **Flat ~60 MB RSS Arena**: Across all 1-isolate `GET` and single-packet
    `POST` workloads (`13 B` through `1 MB`), `bottom_shelf` holds a flat
    `58.0–61.5 MB` `VmHWM` (rising to `76.1 MB` on `W6` `64 KB` chunked upload
    streams, where all three servers rise together).
- **Single-Packet `POST` Fast-Path (`W5`: `1.18x` / `+18.4%` end-to-end RPS
  from `26,807` → `31,734`)**:
  - When a fixed-length request body arrives in the initial TCP read alongside
    the request headers, `_HttpConnection` passes a `Uint8List.sublistView`
    directly to `Request(..., body: bodyBytes)`, skipping
    `FixedLengthBodyController` and `StreamController` allocation.
- **Byte-Oriented Serializer & Zero-Allocation `TypedHeaders` Fused Scan
  (`+7.3%` and `+2.9%` isolated RPS; `1.10x–1.46x` in-process)**:
  - `RawShelfResponseSerializer` formats status lines, cached `Date` bytes, and
    validated headers directly into a shared ASCII scratch buffer without
    `StringBuffer` or `utf8.encode` round-trips.
  - `TypedHeaders` performs a single pass over `HeaderByteSlice` entries using
    zero-allocation byte methods (`parseContentLength`, `scanConnectionToken`,
    `containsTokenIgnoreCase`).
- **Intentional RFC 9110 Compliance Trade-Offs (Do Not Regress)**:
  - **`write_204_no_content_set_cookie` (`1.26 µs` → `1.34 µs` AOT, `+77.3 ns`;
    `1.29 µs` → `1.39 µs` JIT, `+101.2 ns`)**: Canceling unread
    `response.read()` streams on `204` / `content-length: 0`
    (`response.read().listen(null).cancel()`) prevents `StreamController`
    leaks, and emitting separate `Set-Cookie:` header lines (RFC 9110 §5.3 /
    RFC 6265) replaces invalid comma-joined `Set-Cookie` headers.
  - **`raw_http_parser_process` trailing OWS scan (`3.50 µs` → `3.61 µs` AOT,
    `+111.3 ns` across 14 headers, `~8 ns`/header)**: Trimming trailing
    `SP`/`HTAB` OWS on header values (RFC 9110 §5.5) adds ~8 ns/header in
    parser-only AOT runs, which is more than offset in combined
    `process_plus_typed_headers_scan` (`3.92 µs` → `3.85 µs` AOT, `4.04 µs` →
    `3.61 µs` JIT) by zero-allocation `HeaderByteSlice` scanning.

## 4. Reproduction & Methodology Rules

### Full W1–W8 Matrix & `pkg:bench_press` Microbenchmark Suite

In `kevmoo/gcp-http-bench`:

```sh
# End-to-end W1-W8 HTTP matrix (AOT, CPU-pinned, interleaved trials, JSON + Markdown output):
./tool/run_local_matrix.sh

# In-process 66-cell (jit + aot) bench_press microbenchmark suite:
cd targets/bench_press
dart run bench_press run --target jit,aot
```

### Standalone Smoke Reproduction (`pkgs/bottom_shelf/benchmark/`)

```sh
cd pkgs/bottom_shelf
dart compile exe benchmark/raw_bench_server.dart -o /tmp/bottom_shelf_server
dart compile exe benchmark/shelf_io_bench_server.dart -o /tmp/shelf_io_server
dart compile exe benchmark/dart_io_bench_server.dart -o /tmp/dart_io_server

# Per server (ports: bottom_shelf 8081, shelf_io 8082, dart:io 8083):
taskset -c 0 /tmp/bottom_shelf_server &
taskset -c 4-7 wrk -t 4 -c 64 -d 3s http://127.0.0.1:8081/plaintext
```

### Methodology Rules

- **Same-machine numbers are relative-only.** Pinned, governor-fixed,
  interleaved A/B runs are honest for *comparisons*; they are not publishable
  absolute network figures (loopback skips the NIC; contention is
  load-dependent).
- **For network-bound numbers**: two GCP compute-optimized VMs
  (`c2d-standard-4` / `c2d-standard-8` or `c4-standard-8` — never
  `e2`/burstable), same zone, `COLLOCATED` compact placement policy, internal
  IPs.
- **Coordinated omission**: closed-loop tools (`ab`, `wrk`) stop sampling
  during server stalls, so their tail-latency numbers under saturation are
  lower bounds. Quote throughput from closed-loop runs; quote open-loop tail
  latency from a fixed-rate run at ~60–70% of max throughput with a
  latency-correcting tool (e.g. `oha -q <rate> --latency-correction`).
- **AOT vs JIT**: benchmark what people deploy (AOT); AOT is flat from the
  first request, which makes comparisons reproducible.
- **Disclose isolate count**: always report single-isolate (`1` isolate) and
  multi-isolate (`shared: true`) rows separately.
- **Interleave trials**: run ≥3 interleaved trials (`A, B, C, A, B, C, ...`)
  and report the median alongside `CoV` and failed/non-2xx counts.
