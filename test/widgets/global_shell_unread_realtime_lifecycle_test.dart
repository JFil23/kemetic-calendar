import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/share_repo.dart';
import 'package:mobile/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userA = '11111111-1111-4111-8111-111111111111';
const _userB = '22222222-2222-4222-8222-222222222222';
const _trackerTopicPrefix = 'realtime:inbox_unread_state_';
const _probeTopic = 'realtime:deterministic_transport_probe';

class _RealtimeFrame {
  const _RealtimeFrame({
    required this.sequence,
    required this.event,
    required this.topic,
  });

  final int sequence;
  final String event;
  final String topic;
}

class _DeterministicRealtimeEndpoint {
  late final HttpServer _server;
  StreamSubscription<HttpRequest>? _requests;
  final Set<WebSocket> _sockets = <WebSocket>{};
  final Set<StreamSubscription<dynamic>> _socketSubscriptions =
      <StreamSubscription<dynamic>>{};
  final List<_RealtimeFrame> frames = <_RealtimeFrame>[];
  int _frameSequence = 0;

  String get origin => 'http://${_server.address.address}:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _requests = _server.listen(_handleRequest);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    late final StreamSubscription<dynamic> subscription;
    subscription = socket.listen(
      (dynamic raw) {
        final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
        final event = decoded['event']?.toString() ?? '';
        final topic = decoded['topic']?.toString() ?? '';
        final ref = decoded['ref']?.toString();
        frames.add(
          _RealtimeFrame(
            sequence: ++_frameSequence,
            event: event,
            topic: topic,
          ),
        );
        if (event == 'phx_join' ||
            event == 'phx_leave' ||
            event == 'heartbeat') {
          socket.add(
            jsonEncode(<String, Object?>{
              'topic': topic,
              'event': 'phx_reply',
              'payload': <String, Object?>{
                'status': 'ok',
                'response': <String, Object?>{},
              },
              'ref': ref,
            }),
          );
        }
      },
      onDone: () {
        _sockets.remove(socket);
        _socketSubscriptions.remove(subscription);
      },
    );
    _socketSubscriptions.add(subscription);
  }

  int count(String event, String topic) => frames
      .where((frame) => frame.event == event && frame.topic == topic)
      .length;

  int? lastSequence(String event, String topic) {
    int? sequence;
    for (final frame in frames) {
      if (frame.event == event && frame.topic == topic) {
        sequence = frame.sequence;
      }
    }
    return sequence;
  }

  String get frameSummary => frames
      .map((frame) => '${frame.sequence}:${frame.event}:${frame.topic}')
      .join('|');

  void resetFrames() {
    frames.clear();
    _frameSequence = 0;
  }

  Future<void> stop() async {
    for (final socket in _sockets.toList(growable: false)) {
      await socket.close();
    }
    for (final subscription in _socketSubscriptions.toList(growable: false)) {
      await subscription.cancel();
    }
    await _requests?.cancel();
    await _server.close(force: true);
  }
}

void _mockAppLinksChannels() {
  const messages = MethodChannel('com.llfbandit.app_links/messages');
  const events = MethodChannel('com.llfbandit.app_links/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(messages, (_) async => null);
  messenger.setMockMethodCallHandler(events, (methodCall) async {
    if (methodCall.method == 'listen') {
      messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(null),
        (_) {},
      );
    }
    return null;
  });
}

void _resetAppLinksChannels() {
  const messages = MethodChannel('com.llfbandit.app_links/messages');
  const events = MethodChannel('com.llfbandit.app_links/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(messages, null);
  messenger.setMockMethodCallHandler(events, null);
}

http.Response _mockResponse(http.BaseRequest request) {
  if (request.url.path.endsWith('/functions/v1/fetch_maat_guidance_pending')) {
    return http.Response(
      jsonEncode(<String, Object?>{'delivery': null}),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
      request: request,
    );
  }
  if (request.url.path.endsWith('/auth/v1/logout')) {
    return http.Response('', 204, request: request);
  }
  return http.Response(
    '[]',
    200,
    headers: const <String, String>{'content-type': 'application/json'},
    request: request,
  );
}

Future<void> _recoverSession(String userId, {String token = 'one'}) async {
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  await Supabase.instance.client.auth.recoverSession(
    jsonEncode(<String, Object?>{
      'access_token': 'test-access-token-$userId-$token-$expiresAt',
      'expires_in': 31536000,
      'refresh_token': 'test-refresh-token-$userId-$token',
      'token_type': 'bearer',
      'user': <String, Object?>{
        'id': userId,
        'app_metadata': <String, Object?>{
          'provider': 'email',
          'providers': <String>['email'],
        },
        'user_metadata': <String, Object?>{},
        'aud': 'authenticated',
        'email': '$userId@example.com',
        'phone': '',
        'created_at': '2026-01-01T00:00:00.000000Z',
        'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
        'role': 'authenticated',
        'updated_at': '2026-01-01T00:00:00.000000Z',
      },
      'expiresAt': expiresAt,
    }),
  );
}

Future<bool> _waitFor(
  bool Function() predicate, {
  int maxObservations = 10000,
}) async {
  for (var observation = 0; observation < maxObservations; observation += 1) {
    if (predicate()) return true;
    await Future<void>.delayed(Duration.zero);
  }
  return false;
}

String _trackerTopic(String userId) => '$_trackerTopicPrefix$userId';

T? _onlyOrNull<T>(Iterable<T> values) {
  final iterator = values.iterator;
  if (!iterator.moveNext()) return null;
  final value = iterator.current;
  if (iterator.moveNext()) return null;
  return value;
}

Future<void> _ensureDeterministicConnection(
  WidgetTester tester,
  _DeterministicRealtimeEndpoint endpoint,
) async {
  final client = Supabase.instance.client;
  if (client.realtime.connectionState == 'open') return;
  await tester.runAsync(() async {
    RealtimeSubscribeStatus? status;
    final probe = client.channel('deterministic_transport_probe');
    probe.subscribe((value, error) {
      status = value;
    });
    final joined = await _waitFor(
      () =>
          status == RealtimeSubscribeStatus.subscribed &&
          endpoint.count('phx_join', _probeTopic) == 1,
    );
    expect(joined, isTrue, reason: 'Loopback transport probe must join.');
    await probe.unsubscribe();
    final left = await _waitFor(() => !client.getChannels().contains(probe));
    expect(left, isTrue, reason: 'Loopback transport probe must leave.');
  });
  expect(client.realtime.connectionState, 'open');
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Text('Realtime lifecycle surface')),
      ),
    ],
  );
}

Future<RealtimeChannel> _mountSharedTrackerShell(
  WidgetTester tester,
  _DeterministicRealtimeEndpoint endpoint,
  String userId,
) async {
  final client = Supabase.instance.client;
  final joinCountBefore = endpoint.count('phx_join', _trackerTopic(userId));
  final channelsBefore = Set<RealtimeChannel>.identity()
    ..addAll(client.getChannels());
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => app.buildGlobalFloatingMenuShellForTesting(
        router: router,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pump();
  final channel = _onlyOrNull(
    client.getChannels().where((value) => !channelsBefore.contains(value)),
  );
  expect(channel, isNotNull);
  final joined = await tester.runAsync(
    () => _waitFor(
      () =>
          endpoint.count('phx_join', _trackerTopic(userId)) ==
          joinCountBefore + 1,
    ),
  );
  expect(joined, isTrue);
  return channel!;
}

Future<void> _cleanup(
  WidgetTester tester,
  _DeterministicRealtimeEndpoint endpoint,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  final client = Supabase.instance.client;
  await tester.runAsync(() async {
    if (client.auth.currentSession != null) {
      await client.auth.signOut(scope: SignOutScope.local);
    }
    await ShareRepo.synchronizeUnreadTrackerPrincipal(
      client: client,
      activePrincipalId: null,
    );
    await client.removeAllChannels();
    await client.realtime.disconnect();
    endpoint.resetFrames();
  });
  app.resetGlobalFloatingMenuShellForTesting();
  expect(client.getChannels(), isEmpty);
  expect(client.realtime.connectionState, anyOf('closed', 'disconnected'));
}

Future<void> _runRootAuthOwner(
  WidgetTester tester,
  AuthChangeEvent event,
) async {
  final session = event == AuthChangeEvent.signedOut
      ? null
      : Supabase.instance.client.auth.currentSession;
  await tester.runAsync(
    () => app.handleRootPrincipalUnreadAuthTransitionForTesting(
      AuthState(event, session),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final endpoint = _DeterministicRealtimeEndpoint();

  setUpAll(() async {
    _mockAppLinksChannels();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await endpoint.start();
    await Supabase.initialize(
      url: endpoint.origin,
      anonKey: 'anon-key-0123456789012345678901234567890123456789',
      httpClient: MockClient((request) async => _mockResponse(request)),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    app.resetGlobalFloatingMenuShellForTesting();
    final client = Supabase.instance.client;
    if (client.auth.currentSession != null) {
      await client.auth.signOut(scope: SignOutScope.local);
    }
    await ShareRepo.synchronizeUnreadTrackerPrincipal(
      client: client,
      activePrincipalId: null,
    );
    await client.removeAllChannels();
    await client.realtime.disconnect();
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
    await endpoint.stop();
    _resetAppLinksChannels();
  });

  testWidgets(
    'GLOBAL-SHELL-UNREAD-REALTIME-001 shell unmount retains shared principal tracker',
    (tester) async {
      try {
        await tester.runAsync(() => _recoverSession(_userA));
        await _ensureDeterministicConnection(tester, endpoint);
        final channel = await _mountSharedTrackerShell(
          tester,
          endpoint,
          _userA,
        );
        final leaveCountBefore = endpoint.count(
          'phx_leave',
          _trackerTopic(_userA),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        expect(Supabase.instance.client.getChannels(), contains(channel));
        expect(
          endpoint.count('phx_leave', _trackerTopic(_userA)),
          leaveCountBefore,
        );
      } finally {
        await _cleanup(tester, endpoint);
      }
    },
  );

  testWidgets(
    'GLOBAL-SHELL-UNREAD-REALTIME-002 signed-out root auth handling awaits exactly one tracker leave',
    (tester) async {
      try {
        await tester.runAsync(() => _recoverSession(_userA));
        await _ensureDeterministicConnection(tester, endpoint);
        final channel = await _mountSharedTrackerShell(
          tester,
          endpoint,
          _userA,
        );
        final leaveCountBefore = endpoint.count(
          'phx_leave',
          _trackerTopic(_userA),
        );

        await tester.runAsync(
          () =>
              Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
        );
        expect(
          Supabase.instance.client.realtime.connectionState,
          'open',
          reason: 'Sign-out must not replace transport ownership.',
        );
        expect(Supabase.instance.client.getChannels(), contains(channel));
        await _runRootAuthOwner(tester, AuthChangeEvent.signedOut);
        final disposed = !Supabase.instance.client.getChannels().contains(
          channel,
        );

        expect(
          disposed,
          isTrue,
          reason:
              'The root auth owner must await principal tracker disposal as '
              'part of signed-out handling.',
        );
        final leaveObserved = await tester.runAsync(
          () => _waitFor(
            () =>
                endpoint.count('phx_leave', _trackerTopic(_userA)) ==
                leaveCountBefore + 1,
          ),
        );
        expect(leaveObserved, isTrue, reason: endpoint.frameSummary);
        expect(
          endpoint.count('phx_leave', _trackerTopic(_userA)),
          leaveCountBefore + 1,
          reason: endpoint.frameSummary,
        );
      } finally {
        await _cleanup(tester, endpoint);
      }
    },
  );

  testWidgets(
    'GLOBAL-SHELL-UNREAD-REALTIME-003 repeated signed-out cleanup emits no second leave',
    (tester) async {
      try {
        await tester.runAsync(() => _recoverSession(_userA));
        await _ensureDeterministicConnection(tester, endpoint);
        final channel = await _mountSharedTrackerShell(
          tester,
          endpoint,
          _userA,
        );
        final leaveCountBefore = endpoint.count(
          'phx_leave',
          _trackerTopic(_userA),
        );

        await tester.runAsync(
          () =>
              Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
        );
        await _runRootAuthOwner(tester, AuthChangeEvent.signedOut);
        await _runRootAuthOwner(tester, AuthChangeEvent.signedOut);
        final leaveObserved = await tester.runAsync(
          () => _waitFor(
            () =>
                endpoint.count('phx_leave', _trackerTopic(_userA)) ==
                leaveCountBefore + 1,
          ),
        );

        expect(
          Supabase.instance.client.getChannels(),
          isNot(contains(channel)),
        );
        expect(leaveObserved, isTrue, reason: endpoint.frameSummary);
        expect(
          endpoint.count('phx_leave', _trackerTopic(_userA)),
          leaveCountBefore + 1,
        );
      } finally {
        await _cleanup(tester, endpoint);
      }
    },
  );

  testWidgets(
    'GLOBAL-SHELL-UNREAD-REALTIME-004 A to B replacement leaves A before B joins',
    (tester) async {
      try {
        await tester.runAsync(() => _recoverSession(_userA));
        await _ensureDeterministicConnection(tester, endpoint);
        final channelA = await _mountSharedTrackerShell(
          tester,
          endpoint,
          _userA,
        );
        final leaveACountBefore = endpoint.count(
          'phx_leave',
          _trackerTopic(_userA),
        );
        final joinBCountBefore = endpoint.count(
          'phx_join',
          _trackerTopic(_userB),
        );

        await tester.runAsync(() => _recoverSession(_userB));
        await _runRootAuthOwner(tester, AuthChangeEvent.signedIn);

        expect(
          Supabase.instance.client.getChannels(),
          isNot(contains(channelA)),
        );

        ShareRepo(Supabase.instance.client).currentUnreadState;
        final channelB = _onlyOrNull(
          Supabase.instance.client.getChannels().where(
            (value) => !identical(value, channelA),
          ),
        );
        expect(channelB, isNotNull);
        final joinedB = await tester.runAsync(
          () => _waitFor(
            () =>
                endpoint.count('phx_leave', _trackerTopic(_userA)) ==
                    leaveACountBefore + 1 &&
                endpoint.count('phx_join', _trackerTopic(_userB)) ==
                    joinBCountBefore + 1,
          ),
        );
        expect(joinedB, isTrue);

        final leaveASequence = endpoint.lastSequence(
          'phx_leave',
          _trackerTopic(_userA),
        );
        final joinBSequence = endpoint.lastSequence(
          'phx_join',
          _trackerTopic(_userB),
        );
        expect(leaveASequence, isNotNull);
        expect(joinBSequence, isNotNull);
        expect(leaveASequence!, lessThan(joinBSequence!));
        expect(
          Supabase.instance.client.getChannels(),
          isNot(contains(channelA)),
        );
      } finally {
        await _cleanup(tester, endpoint);
      }
    },
  );

  testWidgets(
    'GLOBAL-SHELL-UNREAD-REALTIME-005 same-principal sign-in and token refresh preserve tracker',
    (tester) async {
      try {
        await tester.runAsync(() => _recoverSession(_userA));
        await _ensureDeterministicConnection(tester, endpoint);
        final channel = await _mountSharedTrackerShell(
          tester,
          endpoint,
          _userA,
        );
        final joinCount = endpoint.count('phx_join', _trackerTopic(_userA));
        final leaveCount = endpoint.count('phx_leave', _trackerTopic(_userA));

        await tester.runAsync(
          () => _recoverSession(_userA, token: 'replacement'),
        );
        await _runRootAuthOwner(tester, AuthChangeEvent.signedIn);
        await _runRootAuthOwner(tester, AuthChangeEvent.tokenRefreshed);

        expect(Supabase.instance.client.getChannels(), contains(channel));
        expect(endpoint.count('phx_join', _trackerTopic(_userA)), joinCount);
        expect(endpoint.count('phx_leave', _trackerTopic(_userA)), leaveCount);
      } finally {
        await _cleanup(tester, endpoint);
      }
    },
  );

  testWidgets(
    'GLOBAL-SHELL-UNREAD-REALTIME-006 final teardown has no channels connection or timer',
    (tester) async {
      await tester.runAsync(() => _recoverSession(_userA));
      await _ensureDeterministicConnection(tester, endpoint);
      await _mountSharedTrackerShell(tester, endpoint, _userA);

      await tester.runAsync(
        () => Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
      );
      await _runRootAuthOwner(tester, AuthChangeEvent.signedOut);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.runAsync(Supabase.instance.client.realtime.disconnect);

      expect(Supabase.instance.client.getChannels(), isEmpty);
      expect(Supabase.instance.client.realtime.connectionState, 'disconnected');
      expect(tester.takeException(), isNull);
      app.resetGlobalFloatingMenuShellForTesting();
    },
  );
}
