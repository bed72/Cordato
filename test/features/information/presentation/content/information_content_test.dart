import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/information/presentation/content/information_content.dart';

void main() {
  group('Information editorial content', () {
    test('identifies the responsible person and a real contact', () {
      expect(InformationContent.responsible, 'Gabriel Ramos');
      expect(InformationContent.email, 'developer.bed@gmail.com');
    });

    test('versions both legal documents with an explicit update date', () {
      expect(InformationContent.version, isNotEmpty);
      expect(InformationContent.updatedAt, matches(r'^\d{2}/\d{2}/\d{4}$'));
    });

    for (final document in [
      (
        name: 'terms',
        summary: InformationContent.termsSummary,
        sections: InformationContent.termsSections,
      ),
      (
        name: 'privacy',
        summary: InformationContent.privacySummary,
        sections: InformationContent.privacySections,
      ),
    ]) {
      group(document.name, () {
        test('has a summary and uniquely titled, nonempty sections', () {
          expect(document.summary.trim(), isNotEmpty);
          expect(document.sections, isNotEmpty);
          expect(
            document.sections.map((section) => section.title).toSet(),
            hasLength(document.sections.length),
          );
          for (final section in document.sections) {
            expect(section.title.trim(), isNotEmpty);
            expect(section.paragraphs, isNotEmpty);
            for (final paragraph in section.paragraphs) {
              expect(paragraph.trim(), isNotEmpty);
            }
          }
        });

        test(
          'provides account deletion instructions inside and outside the app',
          () {
            final text = document.sections
                .expand((section) => section.paragraphs)
                .join('\n');

            expect(text, contains('Dados pessoais → Excluir conta'));
            expect(text, contains(InformationContent.email));
            expect(text, contains('Exclusão de conta Cordato'));
          },
        );
      });
    }

    test(
      'distinguishes database hosting from international email processing',
      () {
        final text = InformationContent.privacySections
            .expand((section) => section.paragraphs)
            .join('\n');

        expect(text, contains('Hostinger, no Brasil'));
        expect(text, contains('Resend'));
        expect(text, contains('Estados Unidos'));
        expect(text, contains('Não mantemos backups próprios'));
        expect(text, contains('backups próprios por 7 dias'));
      },
    );

    test('groups unique questions with nonempty answers', () {
      expect(InformationContent.helpSections, isNotEmpty);
      final titles = InformationContent.helpSections
          .map((section) => section.title)
          .toSet();
      expect(titles, hasLength(InformationContent.helpSections.length));

      final questions = <String>{};
      for (final section in InformationContent.helpSections) {
        expect(section.title.trim(), isNotEmpty);
        expect(section.questions, isNotEmpty);
        for (final item in section.questions) {
          expect(item.question.trim(), isNotEmpty);
          expect(item.answer.trim(), isNotEmpty);
          expect(questions.add(item.question), isTrue);
        }
      }
    });

    test('explains deletion without requiring app access or credentials', () {
      final answer = InformationContent.helpSections
          .expand((section) => section.questions)
          .singleWhere(
            (item) =>
                item.question == 'Como peço exclusão sem acessar o aplicativo?',
          )
          .answer;

      expect(answer, contains(InformationContent.email));
      expect(answer, contains('Exclusão de conta Cordato'));
      expect(answer, contains('Não envie senhas'));
      expect(answer, contains('não precisa reinstalar'));
    });
  });
}
