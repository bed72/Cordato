import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/share/share_client.dart';

import 'package:cordato/features/core/application/enums/share_outcome_enum.dart';
import 'package:cordato/features/core/application/models/share_origin_model.dart';
import 'package:cordato/features/core/application/models/share_attachment_model.dart';
import 'package:cordato/features/core/application/exceptions/file_share_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathsChannel = MethodChannel('plugins.flutter.io/path_provider');
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory temporary;
  late ShareClient client;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('cordato-share-test-');
    client = ShareClient();
    messenger.setMockMethodCallHandler(
      pathsChannel,
      (_) async => temporary.path,
    );
    messenger.setMockMethodCallHandler(shareChannel, (_) async => 'chosen.app');
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(pathsChannel, null);
    messenger.setMockMethodCallHandler(shareChannel, null);
    await temporary.delete(recursive: true);
  });

  Future<ShareAttachmentModel> prepare() => client.prepare(
    bytes: Uint8List.fromList([1, 2, 3]),
    fileName: 'cordato-despesas-2026-11-08.csv',
  );

  File fileOf(ShareAttachmentModel attachment) => File(
    '${temporary.path}/cordato-file-share/${attachment.id}/${attachment.fileName}',
  );

  group('Private attachments', () {
    test(
      'writes bytes privately with a public-safe name and no sharing yet',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(shareChannel, (call) async {
          calls.add(call);
          return '';
        });
        final attachment = await prepare();
        expect(await fileOf(attachment).readAsBytes(), [1, 2, 3]);
        expect(attachment.id, matches(r'^attachment-[a-zA-Z0-9]+$'));
        expect(calls, isEmpty);
      },
    );

    test('discards abandoned attachments idempotently', () async {
      final attachment = await prepare();
      await client.discard(attachment);
      await client.discard(attachment);
      expect(await fileOf(attachment).exists(), false);
    });

    test('rejects unsafe names without creating an export', () async {
      await expectLater(
        client.prepare(bytes: Uint8List(0), fileName: '../private.csv'),
        throwsArgumentError,
      );
      expect(temporary.listSync(), isEmpty);
    });

    test('rejects directory traversal attachment IDs', () async {
      await expectLater(
        client.discard(
          const ShareAttachmentModel(id: '../elsewhere', fileName: 'safe.csv'),
        ),
        throwsArgumentError,
      );
    });

    test(
      'maps directory IO errors without exposing a filesystem path',
      () async {
        await File('${temporary.path}/cordato-file-share')
            .writeAsString('blocked');
        await expectLater(
          prepare(),
          throwsA(
            isA<FileShareException>().having(
              (error) => error.errors.errors.single.code,
              'code',
              'file_share_failed',
            ),
          ),
        );
      },
    );

    test('maps unavailable native directory lookup', () async {
      messenger.setMockMethodCallHandler(
        pathsChannel,
        (_) async => throw PlatformException(
          code: 'unavailable',
          message: 'private-path',
        ),
      );
      await expectLater(prepare(), throwsA(isA<FileShareException>()));
    });

    test(
      'discards the owned directory when writing the attachment fails',
      () async {
        final longName = '${List.filled(300, 'a').join()}.csv';

        await expectLater(
          client.prepare(bytes: Uint8List.fromList([1]), fileName: longName),
          throwsA(isA<FileShareException>()),
        );

        final root = Directory('${temporary.path}/cordato-file-share');
        expect(await root.list().toList(), isEmpty);
      },
    );
  });

  group('Native sharing', () {
    for (final platformOutcome in {
      'chosen.app': ShareOutcomeEnum.completed,
      '': ShareOutcomeEnum.dismissed,
      'dev.fluttercommunity.plus/share/unavailable':
          ShareOutcomeEnum.unavailable,
    }.entries) {
      test(
        'maps ${platformOutcome.value.name} and retains the attachment for the receiver',
        () async {
          final calls = <MethodCall>[];
          messenger.setMockMethodCallHandler(shareChannel, (call) async {
            calls.add(call);
            return platformOutcome.key;
          });
          final attachment = await prepare();
          final outcome = await client.share(
            attachment: attachment,
            mimeType: 'text/csv',
            origin: const ShareOriginModel(
              x: 10,
              y: 20,
              width: 120,
              height: 56,
            ),
          );
          await client.discard(attachment);
          final arguments = calls.single.arguments as Map;
          expect(outcome, platformOutcome.value);
          expect(calls.single.method, 'share');
          expect(arguments['paths'], [fileOf(attachment).path]);
          expect(arguments['mimeTypes'], ['text/csv']);
          expect(arguments['originX'], 10);
          expect(arguments['originY'], 20);
          expect(arguments['originWidth'], 120);
          expect(arguments['originHeight'], 56);
          expect(await fileOf(attachment).exists(), true);
        },
      );
    }

    test('maps platform failure and conservatively retains an attachment already handed off', () async {
      messenger.setMockMethodCallHandler(
        shareChannel,
        (_) async =>
            throw PlatformException(code: 'failed', message: 'private-path'),
      );
      final attachment = await prepare();
      await expectLater(
        client.share(attachment: attachment, mimeType: 'text/csv'),
        throwsA(isA<FileShareException>()),
      );
      await client.discard(attachment);
      expect(await fileOf(attachment).exists(), true);
    });

    test(
      'discard cannot revoke an attachment during pending native sharing',
      () async {
        final started = Completer<void>();
        final outcome = Completer<String>();
        messenger.setMockMethodCallHandler(shareChannel, (_) {
          started.complete();
          return outcome.future;
        });
        final attachment = await prepare();
        final pending = client.share(
          attachment: attachment,
          mimeType: 'text/csv',
        );
        await started.future;
        await client.discard(attachment);
        expect(await fileOf(attachment).exists(), true);
        outcome.complete('chosen.app');
        await pending;
      },
    );
  });

  group('Restricted stale cleanup', () {
    test(
      'removes only expired owned directories and preserves unrelated content',
      () async {
        final attachment = await prepare();
        await client.share(attachment: attachment, mimeType: 'text/csv');
        final old = DateTime.now().subtract(const Duration(days: 2));
        await fileOf(attachment).setLastModified(old);
        final recent = await prepare();
        final unrelated = await File('${temporary.path}/unrelated.txt')
            .writeAsString('keep');
        final foreign = await Directory(
          '${temporary.path}/cordato-file-share/other-feature',
        ).create();
        await File('${foreign.path}/keep').writeAsString('keep');

        await client.cleanExpired();

        expect(await fileOf(attachment).exists(), false);
        expect(await fileOf(recent).exists(), true);
        expect(await unrelated.exists(), true);
        expect(await foreign.exists(), true);
      },
    );

    test(
      'preserves active attachments even if filesystem timestamps are old',
      () async {
        final attachment = await prepare();
        final old = DateTime.now().subtract(const Duration(days: 2));
        await fileOf(attachment).setLastModified(old);
        await client.cleanExpired();
        expect(await fileOf(attachment).exists(), true);
      },
    );

    test(
      'preserves a shared attachment inside its 24-hour retention window',
      () async {
        final attachment = await prepare();
        await client.share(attachment: attachment, mimeType: 'text/csv');
        final recent = DateTime.now().subtract(const Duration(hours: 23));
        await fileOf(attachment).setLastModified(recent);
        await client.cleanExpired();
        expect(await fileOf(attachment).exists(), true);
      },
    );
  });
}
