import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:localstore/localstore.dart';

import 'package:cordato/features/user/infrastructure/repositories/user_repository.dart';

final class LocalstoreTestStorage {
  late final Directory directory;
  final Localstore database = Localstore.instance;

  Future<void> open() async {
    directory = await Directory.systemTemp.createTemp('cordato-localstore-');
    Localstore.getInstance(customPath: directory.path);
  }

  Future<T> writing<T>(Set<Object> values, Future<T> Function() action) async {
    final remaining = {...values};
    final completed = Completer<void>();
    final subscription = database.collection('user').stream.listen((data) {
      remaining.removeAll(data.values);
      if (remaining.isEmpty && !completed.isCompleted) {
        completed.complete();
      }
    });
    try {
      final output = await action();
      await completed.future;
      return output;
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> clear() async {
    await database.collection('user').doc('profile').delete();
    final expenses = database.collection('expenses');
    final documents = await expenses.get();
    for (final path in documents?.keys ?? const <String>[]) {
      await expenses.doc(path.split('/').last).delete();
    }
    await expenses.get();
  }

  Future<T> expense<T>(Future<T> Function() action) async {
    final collection = database.collection('expenses');
    final before = await collection.get();
    final previous = <String, String>{
      for (final document in before?.values ?? const <dynamic>[])
        (document as Map<String, dynamic>)['id'] as String: jsonEncode(
          document,
        ),
    };
    final written = collection.stream.firstWhere(
      (document) => previous[document['id']] != jsonEncode(document),
    );
    final output = await action();
    await written;
    return output;
  }

  Future<void> initialize() async {
    await writing({'Cordato'}, () => UserRepository(database: database).get());
  }

  Future<void> close() async {
    await clear();
    await directory.delete(recursive: true);
    Localstore.getInstance();
  }
}
