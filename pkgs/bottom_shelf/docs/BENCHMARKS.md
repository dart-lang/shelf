# Benchmarks

Measured results and the harness/methodology for reproducing them honestly.

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
