# Benchmarks

Measured results and the harness/methodology for reproducing them honestly.

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
