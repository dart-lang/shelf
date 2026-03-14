import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class RouterWorstCaseBenchmark extends AsyncBenchmarkBase {
  RouterWorstCaseBenchmark() : super('Router Worst Case Match (10k routes)');

  late Router router;
  late Request request;

  @override
  Future<void> setup() async {
    router = Router();

    // Generate 10,000 routes across 100 different controllers/prefixes
    for (var c = 0; c < 100; c++) {
      for (var i = 0; i < 100; i++) {
        router.get('/api/controller_$c/resource/$i/details', (Request request) {
          return Response.ok('match $c $i');
        });
      }
    }

    // Creating request for the LAST route in the VERY LAST controller to
    // trigger worst-case matching
    request = Request('GET',
        Uri.parse('http://localhost/api/controller_99/resource/99/details'));
  }

  @override
  Future<void> run() async {
    await router.call(request);
  }
}

class RouterNotFoundBenchmark extends AsyncBenchmarkBase {
  RouterNotFoundBenchmark() : super('Router 404 (10k routes)');

  late Router router;
  late Request request;

  @override
  Future<void> setup() async {
    router = Router();

    // Generate 10,000 routes across 100 different controllers/prefixes
    for (var c = 0; c < 100; c++) {
      for (var i = 0; i < 100; i++) {
        router.get('/api/controller_$c/resource/$i/details', (Request request) {
          return Response.ok('match $c $i');
        });
      }
    }

    // Creating request that does not match ANY of the routes
    request =
        Request('GET', Uri.parse('http://localhost/api/controller_99/foo/bar'));
  }

  @override
  Future<void> run() async {
    await router.call(request);
  }
}

Future<void> main() async {
  print('Running routing benchmarks...');
  await RouterWorstCaseBenchmark().report();
  await RouterNotFoundBenchmark().report();
}
