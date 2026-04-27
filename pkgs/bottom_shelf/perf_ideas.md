# Brainstorming: Hyper-Optimizing `bottom_shelf`

This document outlines ideas for pushing the performance of `bottom_shelf` even further, targeting zero-allocation paths and minimizing CPU cycles.

## 1. Allocation Reduction (The "Zero-Garbage" Goal)

Even in the trivial "Hello World" scenario, we are still generating some allocations per request. We should aim to reduce these to absolute zero for the hot path.

### 1.1. Target `_Type` and `TypeArguments`
- **Issue**: We saw ~0.17 `_Type` and ~0.09 `TypeArguments` allocations per request.
- **Ideas**:
    - Audit the use of generics in `Request` and `Response` creation.
    - Check if `LazyByteHeaderMap` or `TypedHeaders` are causing type checks or generic map instantiations.
    - Avoid passing generic functions or closures that capture types on the hot path.

### 1.2. Target `_List` and `_Closure`
- **Issue**: Small but present allocations for lists and closures.
- **Ideas**:
    - In `static_handler.dart` (and similar handlers), avoid spread operators or list literals in path processing. Use custom iterables or `p.join` with multiple arguments instead of `p.joinAll(list)`.
    - Replace `.map().contains()` chains (like in ETag handling) with manual `for` loops to avoid closure allocations.

## 2. I/O and Buffer Optimization

We already won big by buffering headers. We can push this further.

### 2.1. Buffer Coalescing for Body
- **Idea**: If the response body is a small string or a small `Uint8List` (like in "Hello World"), buffer it **together** with the status line and headers.
- **Benefit**: Reduces the number of `socket.add` calls (and thus `_nativeWrite` syscalls) to exactly **one** per response for small payloads!

### 2.2. Zero-Copy Reading
- **Idea**: Use `Uint8List.sublistView` when parsing incoming data chunks to avoid copying bytes when passing slices to the parser or request body controller.

## 3. Parser Optimization (`RawHttpParser`)

The CPU profile showed `_doParse` taking some time.

### 3.1. Fast Path for Common Methods
- **Idea**: Hardcode checks for `GET` and `POST` using integer comparisons of the first few bytes rather than string parsing.
- **Benefit**: Saves CPU cycles on method parsing.

### 3.2. Header Parsing
- **Idea**: Use a lookup table (array of booleans or bytes) for valid header name characters instead of complex regex or switch statements, if applicable.

## 4. Architecture

### 4.1. Fast Path for `shelf` Core
- **Idea**: Investigate if `shelf.Request` and `shelf.Response` can be bypassed or specialized for `bottom_shelf` to avoid the overhead of the immutable wrappers if we know they aren't needed for simple handlers. (This is risky but might yield the ultimate speed).
