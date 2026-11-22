import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/utils/hut_user_api.dart';

void main() {
  Map<String, dynamic> ok() => {
    'success': true,
    'result': '000000',
    'message': '无卡开阀成功',
  };

  Map<String, dynamic> busy(String code) => {
    'success': true,
    'result': code,
    'message': '当前设备忙,请稍候再试',
  };

  test('successful first attempt is not retried', () async {
    var attempts = 0;
    final delays = <Duration>[];

    final value = await runWaterValveOperation(
      () async {
        attempts++;
        return ok();
      },
      delay: (d) async => delays.add(d),
    );

    expect(attempts, 1);
    expect(delays, isEmpty);
    expect(value['result'], '000000');
  });

  test('busy business code retries then succeeds', () async {
    var attempts = 0;
    final delays = <Duration>[];

    final value = await runWaterValveOperation(
      () async {
        attempts++;
        return attempts == 1 ? busy('CORE35108') : ok();
      },
      delay: (d) async => delays.add(d),
    );

    expect(attempts, 2);
    expect(delays, const [Duration(seconds: 2)]);
    expect(value['result'], '000000');
  });

  test('CORE35106 is treated as retryable (close-valve busy)', () async {
    var attempts = 0;

    await runWaterValveOperation(
      () async {
        attempts++;
        return attempts == 1 ? busy('CORE35106') : ok();
      },
      delay: (_) async {},
    );

    expect(attempts, 2);
  });

  test('persistent busy failures stop after two retries with backoff', () async {
    var attempts = 0;
    final delays = <Duration>[];

    final value = await runWaterValveOperation(
      () async {
        attempts++;
        return busy('CORE35108');
      },
      delay: (d) async => delays.add(d),
    );

    expect(attempts, 3);
    expect(delays, const [Duration(seconds: 2), Duration(seconds: 4)]);
    expect(value['result'], 'CORE35108');
  });

  test('non-retryable business codes fail fast', () async {
    var attempts = 0;
    final delays = <Duration>[];

    final value = await runWaterValveOperation(
      () async {
        attempts++;
        return {
          'success': true,
          'result': 'WATER10003',
          'message': '设备状态异常',
        };
      },
      delay: (d) async => delays.add(d),
    );

    expect(attempts, 1);
    expect(delays, isEmpty);
    expect(value['result'], 'WATER10003');
  });

  test('transport timeout errors are retried, HTTP rejections are not', () async {
    var timeoutAttempts = 0;
    await runWaterValveOperation(
      () async {
        timeoutAttempts++;
        if (timeoutAttempts == 1) {
          throw DioException(
            requestOptions: RequestOptions(path: '/boiling/termcodeOpenValve'),
            type: DioExceptionType.receiveTimeout,
          );
        }
        return ok();
      },
      delay: (_) async {},
    );
    expect(timeoutAttempts, 2);

    var badResponseAttempts = 0;
    await expectLater(
      runWaterValveOperation(
        () async {
          badResponseAttempts++;
          throw DioException(
            requestOptions: RequestOptions(path: '/boiling/termcodeOpenValve'),
            type: DioExceptionType.badResponse,
          );
        },
        delay: (_) async {},
      ),
      throwsA(isA<DioException>()),
    );
    expect(badResponseAttempts, 1);
  });

  test('session-lost response invalidates the session and retries', () async {
    var attempts = 0;
    var sessionInvalidations = 0;
    final delays = <Duration>[];

    final value = await runWaterValveOperation(
      () async {
        attempts++;
        return attempts == 1
            ? {'success': false, 'message': '资源受限，页面丢失!'}
            : ok();
      },
      delay: (d) async => delays.add(d),
      onSessionLost: () => sessionInvalidations++,
    );

    expect(attempts, 2);
    expect(sessionInvalidations, 1);
    expect(delays, const [Duration(seconds: 2)]);
    expect(value['result'], '000000');
  });

  test('persistent session loss returns the last response', () async {
    var attempts = 0;

    final value = await runWaterValveOperation(
      () async {
        attempts++;
        return {'success': false, 'message': '资源受限，页面丢失!'};
      },
      delay: (_) async {},
      onSessionLost: () {},
    );

    expect(attempts, 3);
    expect(value['success'], isFalse);
  });

  test('waterResponseIndicatesSessionLost matches both server markers', () {
    expect(
      waterResponseIndicatesSessionLost({
        'success': false,
        'message': '资源受限，页面丢失!',
      }),
      isTrue,
    );
    expect(
      waterResponseIndicatesSessionLost({'success': false, 'message': '页面丢失'}),
      isTrue,
    );
    expect(
      waterResponseIndicatesSessionLost({
        'success': true,
        'result': '000000',
      }),
      isFalse,
    );
    expect(
      waterResponseIndicatesSessionLost({
        'success': false,
        'message': '无卡关阀失败,网络或设备通讯异常，请稍候再试',
      }),
      isFalse,
    );
  });

  test('isWaterValveTransientError covers timeout and connection errors', () {
    RequestOptions request([String path = '/boiling/endUse']) =>
        RequestOptions(path: path);

    expect(
      isWaterValveTransientError(
        DioException(
          requestOptions: request(),
          type: DioExceptionType.receiveTimeout,
        ),
      ),
      isTrue,
    );
    expect(
      isWaterValveTransientError(
        DioException(
          requestOptions: request(),
          type: DioExceptionType.connectionTimeout,
        ),
      ),
      isTrue,
    );
    expect(
      isWaterValveTransientError(
        DioException(
          requestOptions: request(),
          type: DioExceptionType.connectionError,
        ),
      ),
      isTrue,
    );
    expect(
      isWaterValveTransientError(
        DioException(requestOptions: request(), type: DioExceptionType.cancel),
      ),
      isFalse,
    );
    expect(isWaterValveTransientError(StateError('boom')), isFalse);
  });

  test('isWaterValveRetryableResult only accepts the two busy codes', () {
    expect(isWaterValveRetryableResult(busy('CORE35106')), isTrue);
    expect(isWaterValveRetryableResult(busy('CORE35108')), isTrue);
    expect(isWaterValveRetryableResult(ok()), isFalse);
    expect(
      isWaterValveRetryableResult({
        'success': true,
        'result': 'WATER10005',
        'message': '开阀记录不存在',
      }),
      isFalse,
    );
    expect(
      isWaterValveRetryableResult({'success': false, 'message': '页面丢失'}),
      isFalse,
    );
  });

  test('water valve timeouts match the measured-latency derivation', () {
    // docs/water_hot_reverse_findings.md §2.3: max observed 2.89s → 15s budget.
    expect(kWaterReceiveTimeout, const Duration(seconds: 15));
    expect(kWaterConnectTimeout, const Duration(seconds: 5));
  });
}
