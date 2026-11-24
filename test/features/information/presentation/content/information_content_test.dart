import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/information/presentation/content/information_content.dart';

void main() {
  final terms = InformationContent.termsSections
      .expand((section) => section.paragraphs)
      .join('\n');
  final privacy = InformationContent.privacySections
      .expand((section) => section.paragraphs)
      .join('\n');
  final questions = InformationContent.helpSections
      .expand((section) => section.questions)
      .toList();
  final help = questions.map((item) => item.answer).join('\n');

  group('Information editorial content', () {
    test('identifies the responsible person and a real contact', () {
      expect(InformationContent.responsible, 'Gabriel Ramos');
      expect(InformationContent.email, 'developer.bed@gmail.com');
    });

    test('versions the local documents with an explicit update date', () {
      expect(InformationContent.version, '2.2');
      expect(InformationContent.updatedAt, '24/11/2026');
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
      test(
        '${document.name} has a summary and uniquely titled nonempty sections',
        () {
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
        },
      );
    }

    test('explains a local profile rather than a remote account', () {
      expect(
        InformationContent.termsSummary,
        contains('sem cadastro ou login'),
      );
      expect(terms, contains('Não há cadastro, login ou senha'));
      expect(privacy, contains('Não há e-mail de cadastro'));
      expect(privacy, contains('Não há autenticação própria'));
      expect(help, contains('sem cadastro, login ou senha'));
      expect(privacy, contains('seed inicial é gerada aleatoriamente'));
    });

    test('explains storage and does not promise remote recovery', () {
      for (final text in [terms, privacy, help]) {
        expect(text, contains('dispositivo'));
        expect(text, contains('backup remoto próprio'));
        expect(text, contains('sistema'));
        expect(text, isNot(contains('backups semanais')));
        expect(text, isNot(contains('três cópias automáticas')));
      }
      expect(terms, contains('pode apagar seus registros'));
      expect(privacy, contains('não pode apagar ou recuperar'));
      expect(help, contains('podem ser perdidos'));
    });

    test('explains local CSV without promising restorable backups', () {
      expect(terms, contains('não é criptografado nem um backup restaurável'));
      expect(privacy, contains('24 horas'));
      expect(privacy, contains('não confirma que o arquivo foi salvo'));
      final answer = questions
          .singleWhere(
            (item) =>
                item.question == 'Posso exportar despesas ou criar um backup?',
          )
          .answer;
      expect(answer, contains('não pode ser restaurado no app'));
      expect(answer, contains('não são um backup próprio'));
      for (final text in [terms, privacy, help]) {
        expect(text, contains('Configurações → Exportar despesas'));
        expect(text, contains('CSV'));
      }
    });

    test('explains local deletion without obsolete account actions', () {
      for (final text in [terms, privacy, help]) {
        expect(text, contains('conta remota para'));
        expect(text, contains('desinstal'));
        expect(text, contains('arquivos exportados'));
        expect(text, isNot(contains('Excluir conta')));
        expect(text, isNot(contains('Exclusão de conta Cordato')));
      }
      expect(privacy, contains('O suporte não tem acesso ao banco'));
    });

    test(
      'removes operational claims about retired providers and credentials',
      () {
        final allContent = [
          InformationContent.termsSummary,
          terms,
          InformationContent.privacySummary,
          privacy,
          help,
        ].join('\n');
        for (final retiredInstruction in [
          'Hostinger',
          'Resend',
          'OpenRouter',
          'Gemini',
          'Reenviar',
          'recupere sua senha',
          'confirme o e-mail',
          'credencial de sessão',
          'aceite do envio',
          '30 segundos',
        ]) {
          expect(allContent, isNot(contains(retiredInstruction)));
        }
        expect(privacy, contains('não oferece captura de áudio'));
        expect(help, contains('não oferece gravação de áudio'));
      },
    );

    test(
      'does not claim absolute privacy or configured database encryption',
      () {
        expect(
          privacy,
          contains('não possui criptografia adicional configurada'),
        );
        expect(privacy, contains('Backups e transferências'));
        expect(privacy, contains('processamento fora do Brasil'));
        expect(privacy, contains('destino'));
        expect(privacy, contains('cópias enviadas a terceiros'));
      },
    );

    test('discloses the native widget snapshot', () {
      expect(privacy, contains('widget do sistema'));
      expect(privacy, contains('mês e do total mensal'));
      expect(privacy, contains('fora do aplicativo'));
    });

    test(
      'provides privacy rights and support without demanding an account',
      () {
        expect(privacy, contains('LGPD'));
        expect(privacy, contains('Autoridade Nacional'));
        expect(privacy, contains('Não é necessário fornecer uma conta'));
        expect(privacy, contains(InformationContent.email));
        expect(help, contains(InformationContent.email));
        expect(help, contains('Não envie senhas'));
      },
    );

    test('distinguishes voluntary support from app payment processing', () {
      expect(terms, contains('voluntário'));
      expect(terms, contains('não desbloqueia funcionalidades'));
      expect(terms, contains('não processa nem confirma pagamentos'));
      expect(privacy, contains('instituição financeira'));
    });

    test('groups unique questions with nonempty answers', () {
      expect(InformationContent.helpSections, isNotEmpty);
      expect(
        InformationContent.helpSections.map((section) => section.title).toSet(),
        hasLength(InformationContent.helpSections.length),
      );
      final uniqueQuestions = <String>{};
      for (final section in InformationContent.helpSections) {
        expect(section.title.trim(), isNotEmpty);
        expect(section.questions, isNotEmpty);
        for (final item in section.questions) {
          expect(item.question.trim(), isNotEmpty);
          expect(item.answer.trim(), isNotEmpty);
          expect(uniqueQuestions.add(item.question), isTrue);
        }
      }
    });
  });
}
