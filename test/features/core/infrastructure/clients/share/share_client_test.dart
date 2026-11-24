import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:cordato/features/core/infrastructure/clients/share/share_client.dart';
import 'package:cordato/features/core/infrastructure/clients/share/share_client_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory temporary;
  late ShareClient client;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('cordato-share-test-');
    client = ShareClient(directory: () async => temporary);
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await temporary.delete(recursive: true);
  });

  Future<String> prepare() => client.prepare(
    bytes: Uint8List.fromList([1, 2, 3]),
    fileName: 'cordato-despesas-2026-11-24.csv',
  );

  test(
    'writes unique private attachments without touching other cache',
    () async {
      final unrelated = File(path.join(temporary.path, 'unrelated'));
      await unrelated.writeAsString('keep');

      final first = await prepare();
      final second = await prepare();

      expect(first, isNot(second));
      expect(await File(first).readAsBytes(), [1, 2, 3]);
      expect(path.isWithin(temporary.path, first), isTrue);
      expect(path.basename(first), 'cordato-despesas-2026-11-24.csv');
      expect(await unrelated.readAsString(), 'keep');
    },
  );

  for (final fileName in ['../escape.csv', r'..\escape.csv', '', '.', '..']) {
    test('rejects unsafe filename "$fileName"', () async {
      await expectLater(
        client.prepare(bytes: Uint8List(0), fileName: fileName),
        throwsArgumentError,
      );
    });
  }

  for (final outcome in [
    'selected-app',
    'dev.fluttercommunity.plus/share/dismissed',
    'dev.fluttercommunity.plus/share/unavailable',
  ]) {
    test('shares CSV with iPad origin and retains file for $outcome', () async {
      final attachment = await prepare();
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return outcome;
      });

      await client.share(path: attachment, mimeType: 'text/csv');

      expect(calls, hasLength(1));
      expect(calls.single.method, 'share');
      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(arguments['paths'], [attachment]);
      expect(arguments['mimeTypes'], ['text/csv']);
      expect(arguments['originX'], 0);
      expect(arguments['originY'], 0);
      expect(arguments['originWidth'], 1);
      expect(arguments['originHeight'], 1);
      expect(await File(attachment).exists(), isTrue);
    });
  }

  test('discard removes only its attachment and is idempotent', () async {
    final first = await prepare();
    final second = await prepare();

    await client.discard(path: first);
    await client.discard(path: first);

    expect(await File(first).exists(), isFalse);
    expect(await File(second).exists(), isTrue);
  });

  test('refuses files outside the sharing directory', () async {
    final outside = File(path.join(temporary.path, 'outside.csv'));
    await outside.writeAsString('keep');
    final attachment = outside.path;

    await expectLater(client.discard(path: attachment), throwsArgumentError);
    await expectLater(
      client.share(path: attachment, mimeType: 'text/csv'),
      throwsArgumentError,
    );
    expect(await outside.readAsString(), 'keep');
  });

  test('rejects symlink attachments without following them', () async {
    final attachment = await prepare();
    final outside = File(path.join(temporary.path, 'outside.csv'));
    await outside.writeAsString('keep');
    await File(attachment).delete();
    await Link(attachment).create(outside.path);

    await expectLater(
      client.share(path: attachment, mimeType: 'text/csv'),
      throwsA(isA<ShareClientException>()),
    );
    expect(await outside.readAsString(), 'keep');
  });

  test('missing files fail safely without invoking the SDK', () async {
    final attachment = await prepare();
    await File(attachment).delete();

    await expectLater(
      client.share(path: attachment, mimeType: 'text/csv'),
      throwsA(
        isA<ShareClientException>().having(
          (error) => error.code,
          'code',
          'export_file_unavailable',
        ),
      ),
    );
  });

  test('keeps active attachment while native sharing is pending', () async {
    final attachment = await prepare();
    final started = Completer<void>();
    final pending = Completer<String>();
    messenger.setMockMethodCallHandler(channel, (call) {
      started.complete();
      return pending.future;
    });
    final sharing = client.share(path: attachment, mimeType: 'text/csv');
    await started.future;

    await expectLater(
      client.discard(path: attachment),
      throwsA(
        isA<ShareClientException>().having(
          (error) => error.code,
          'code',
          'export_busy',
        ),
      ),
    );

    pending.complete('selected-app');
    await sharing;
    expect(await File(attachment).exists(), isTrue);
  });

  test('translates native failures without exposing diagnostics', () async {
    final attachment = await prepare();
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'native', message: attachment);
    });

    await expectLater(
      client.share(path: attachment, mimeType: 'text/csv'),
      throwsA(
        isA<ShareClientException>().having(
          (error) => error.code,
          'code',
          'export_share_failed',
        ),
      ),
    );
  });

  test(
    'translates filesystem errors and preserves unexpected errors',
    () async {
      final filesystem = ShareClient(
        directory: () async => throw const FileSystemException('private'),
      );
      final failure = StateError('unexpected');
      final unexpected = ShareClient(directory: () async => throw failure);

      await expectLater(
        filesystem.prepare(bytes: Uint8List(1), fileName: 'a.csv'),
        throwsA(isA<ShareClientException>()),
      );
      await expectLater(
        unexpected.prepare(bytes: Uint8List(1), fileName: 'a.csv'),
        throwsA(same(failure)),
      );
    },
  );

  test(
    'cleans only expired owned directories when preparing another file',
    () async {
      final stale = await prepare();
      final root = Directory(path.dirname(path.dirname(stale)));
      final unrelated = Directory(path.join(root.path, 'unrelated'));
      await unrelated.create();
      await File(path.join(unrelated.path, 'keep')).writeAsString('keep');
      final futureClient = ShareClient(
        directory: () async => temporary,
        now: () => DateTime.now().add(const Duration(hours: 25)),
      );

      final fresh = await futureClient.prepare(
        bytes: Uint8List(1),
        fileName: 'fresh.csv',
      );

      expect(await File(stale).exists(), isFalse);
      expect(await File(fresh).exists(), isTrue);
      expect(await unrelated.exists(), isTrue);
    },
  );

  test(
    'failed file creation discards its private temporary directory',
    () async {
      await expectLater(
        client.prepare(
          bytes: Uint8List(1),
          fileName: '${List.filled(300, 'x').join()}.csv',
        ),
        throwsA(
          isA<ShareClientException>().having(
            (error) => error.code,
            'code',
            'export_file_failed',
          ),
        ),
      );
      final root = Directory(path.join(temporary.path, 'cordato_share'));

      expect(await root.list().toList(), isEmpty);
    },
  );

  test('missing native implementation is a safe sharing failure', () async {
    final attachment = await prepare();
    messenger.setMockMethodCallHandler(channel, null);

    await expectLater(
      client.share(path: attachment, mimeType: 'text/csv'),
      throwsA(
        isA<ShareClientException>().having(
          (error) => error.code,
          'code',
          'export_share_unavailable',
        ),
      ),
    );
  });

  test(
    'rejects a symlink sharing root without deleting external files',
    () async {
      final outside = Directory(path.join(temporary.path, 'outside'));
      await outside.create();
      final keep = File(path.join(outside.path, 'keep.csv'));
      await keep.writeAsString('keep');
      await Link(path.join(temporary.path, 'cordato_share'))
          .create(outside.path);

      await expectLater(prepare(), throwsA(isA<ShareClientException>()));

      expect(await keep.readAsString(), 'keep');
    },
  );

  test(
    'cleanup skips expired files while native sharing remains active',
    () async {
      DateTime now = DateTime.now();
      client = ShareClient(directory: () async => temporary, now: () => now);
      final attachment = await prepare();
      final started = Completer<void>();
      final pending = Completer<String>();
      messenger.setMockMethodCallHandler(channel, (_) {
        started.complete();
        return pending.future;
      });
      final sharing = client.share(path: attachment, mimeType: 'text/csv');
      await started.future;
      now = now.add(const Duration(hours: 25));

      await prepare();

      expect(await File(attachment).exists(), isTrue);
      pending.complete('selected-app');
      await sharing;
    },
  );
}
