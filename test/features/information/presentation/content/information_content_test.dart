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
          expect(document.sections, isNotEmpty);
          expect(document.summary.trim(), isNotEmpty);
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

            expect(text, contains(InformationContent.email));
            expect(text, contains('Exclusão de conta Cordato'));
            expect(text, contains('Dados pessoais → Excluir conta'));
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

        expect(text, contains('Resend'));
        expect(text, contains('Estados Unidos'));
        expect(text, contains('Hostinger, no Brasil'));
        expect(text, contains('backups próprios por 7 dias'));
      },
    );

    test(
      'discloses optional audio processing and international AI providers',
      () {
        final text = InformationContent.privacySections
            .expand((section) => section.paragraphs)
            .join('\n');

        expect(
          InformationContent.privacySummary,
          contains('inteligência artificial'),
        );
        expect(text, contains('permissão'));
        expect(text, contains('formulário'));
        expect(text, contains('OpenRouter'));
        expect(text, contains('30 segundos'));
        expect(text, contains('aciona o envio'));
        expect(text, contains('fora do Brasil'));
        expect(text, contains('Gemini, do Google'));
        expect(text, contains('não garante retenção zero'));
        expect(text, contains('uso desse recurso é opcional'));
        expect(text, contains('https://openrouter.ai/privacy'));
        expect(text, contains('credencial de sessão não são enviadas à IA'));
      },
    );

    test('distinguishes temporary audio cleanup from provider retention', () {
      final text = InformationContent.privacySections
          .expand((section) => section.paragraphs)
          .join('\n');

      expect(text, contains('finalização ou cancelamento'));
      expect(text, contains('retenção nos serviços de IA'));
      expect(text, contains('Não prometemos retenção zero'));
      expect(text, contains('arquivo temporário no dispositivo'));
      expect(text, contains('logs desse processamento não incluem áudio'));
      expect(text, contains('em memória, sem arquivo ou fila persistente'));
    });

    test(
      'qualifies backup configuration consistently across public content',
      () {
        final terms = InformationContent.termsSections
            .expand((section) => section.paragraphs)
            .join('\n');
        final privacy = InformationContent.privacySections
            .expand((section) => section.paragraphs)
            .join('\n');
        final help = InformationContent.helpSections
            .expand((section) => section.questions)
            .map((item) => item.answer)
            .join('\n');

        for (final text in [terms, privacy, help]) {
          expect(text, isNot(contains('Não mantemos backups próprios')));
          expect(text, isNot(contains('não mantemos backups próprios')));
        }

        expect(terms, contains('Backups não garantem'));
        expect(
          privacy,
          contains('backups semanais e até três cópias automáticas'),
        );
        expect(privacy, contains('não comprova execução'));
        expect(help, contains('não comprova sua execução'));
        expect(privacy, contains('conservar registros excluídos'));
      },
    );

    test('explains audio acceptance without promising expense creation', () {
      final terms = InformationContent.termsSections
          .expand((section) => section.paragraphs)
          .join('\n');
      final answer = InformationContent.helpSections
          .expand((section) => section.questions)
          .singleWhere(
            (item) => item.question == 'O que acontece quando envio um áudio?',
          )
          .answer;

      expect(answer, contains('formulário manual'));
      expect(answer, contains('O aceite não confirma o cadastro'));
      expect(terms, contains('aceite do envio não confirma o cadastro'));
      expect(answer, contains('confira suas despesas antes de reenviar'));
    });

    test(
      'explains current-session revocation and uncertain transport outcomes',
      () {
        final answer = InformationContent.helpSections
            .expand((section) => section.questions)
            .singleWhere(
              (item) => item.question == 'O que acontece quando saio da conta?',
            )
            .answer;

        expect(answer, contains('revogação da sessão atual'));
        expect(answer, contains('resultado incerto'));
        expect(answer, contains('outros dispositivos'));
        expect(answer, contains('Essa ação não exclui sua conta'));
      },
    );

    test(
      'public access instructions use email codes instead of password flows',
      () {
        final access = InformationContent.helpSections.first.questions
            .map((question) => question.answer)
            .join('\n');
        expect(access, contains('Enviar código'));
        expect(access, contains('seis dígitos'));
        expect(access, isNot(contains('Crie uma')));
        expect(access, isNot(contains('redefina sua senha')));
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

      expect(answer, contains('Não envie senhas'));
      expect(answer, contains(InformationContent.email));
      expect(answer, contains('não precisa reinstalar'));
      expect(answer, contains('Exclusão de conta Cordato'));
    });
  });
}
