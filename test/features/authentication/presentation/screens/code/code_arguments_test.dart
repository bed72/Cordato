import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/authentication/presentation/screens/code/arguments/code_arguments.dart';

void main() {
  test('preserves the email and identifier unchanged', () {
    const arguments = CodeArguments(
      email: ' User@example.com ',
      userId: ' user ',
    );
    expect(arguments.isValid, isTrue);
    expect(arguments.email, ' User@example.com ');
    expect(arguments.userId, ' user ');
  });
  for (final arguments in [
    const CodeArguments(email: '', userId: 'user'),
    const CodeArguments(email: ' ', userId: 'user'),
    const CodeArguments(email: 'user@example.com', userId: ''),
    const CodeArguments(email: 'user@example.com', userId: ' '),
  ]) {
    test(
      'rejects incomplete route input ${arguments.email}/${arguments.userId}',
      () {
        expect(arguments.isValid, isFalse);
      },
    );
  }
}
