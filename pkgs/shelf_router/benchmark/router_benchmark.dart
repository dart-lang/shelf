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

    router.populate();

    // Creating request for the LAST route in the VERY LAST controller to
    // trigger worst-case matching
    request = Request(
        'GET',
        Uri.parse(
            'http://localhost/api/controller_${_controllers - 1}/resource/${_routesPerController - 1}/details'));
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
    router.populate();

    // Creating request that does not match ANY of the routes
    request = Request(
        'GET',
        Uri.parse(
            'http://localhost/api/controller_${_controllers - 1}/foo/bar'));
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

const _controllers = 100;
const _routesPerController = 100;

extension on Router {
  void populate() {
    for (var c = 0; c < _controllers; c++) {
      for (var i = 0; i < _routesPerController; i++) {
        get('/api/controller_$c/resource/$i/details', (Request request) {
          return Response.ok('match $c $i');
        });
      }
    }
  }
}
