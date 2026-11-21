abstract final class InformationContent {
  static const version = '2.1';
  static const updatedAt = '21/11/2026';
  static const responsible = 'Gabriel Ramos';
  static const email = 'developer.bed@gmail.com';

  static const termsSummary =
      'O Cordato é um organizador financeiro pessoal de uso local, '
      'sem cadastro ou login. O uso é gratuito, sem anúncios ou assinatura. '
      'Os registros ficam no dispositivo: cuide das suas cópias, pois não '
      'oferecemos sincronização ou recuperação remota.';

  static const termsSections = [
    (
      title: 'Sobre o Cordato',
      paragraphs: [
        'O Cordato é mantido por $responsible. Estes Termos de uso regem '
            'a utilização do aplicativo. Leia também a Política de Privacidade.',
        'O aplicativo organiza registros de despesas, valores em reais, datas '
            'e categorias. Não é um banco, não movimenta dinheiro, não concede '
            'crédito e não oferece consultoria de investimentos.',
      ],
    ),
    (
      title: 'Quem pode usar',
      paragraphs: [
        'O aplicativo é destinado a adultos e adolescentes, sem direcionamento '
            'a crianças. Menores de idade devem contar com orientação de seu '
            'responsável legal e com a assistência ou autorização exigida '
            'pela legislação aplicável.',
      ],
    ),
    (
      title: 'Perfil local e acesso ao dispositivo',
      paragraphs: [
        'Não há cadastro, login ou senha do Cordato. O nome e o avatar '
            'personalizam um perfil local e não identificam uma conta em servidor. '
            'Alterar o nome ou o avatar não cria outro conjunto de despesas.',
        'Proteja o acesso ao dispositivo com os recursos do sistema operacional. '
            'O aplicativo não oferece um bloqueio próprio por senha nem '
            'separação de perfis para pessoas que compartilhem a mesma instalação.',
      ],
    ),
    (
      title: 'Seus registros',
      paragraphs: [
        'Confira os valores, as datas e as categorias que registrar. Resumos '
            'financeiros dependem desses registros e não substituem extratos '
            'bancários ou orientação profissional.',
        'O Cordato não oferece gravação de áudio, interpretação por inteligência '
            'artificial ou compartilhamento familiar nesta versão local. '
            'Não utilize o aplicativo para atividades ilícitas ou para '
            'comprometer a segurança de outros dispositivos e pessoas.',
      ],
    ),
    (
      title: 'Armazenamento, cópias e perda de dados',
      paragraphs: [
        'O perfil e as despesas são armazenados localmente. O Cordato não oferece '
            'sincronização entre dispositivos, backup remoto próprio ou '
            'restauração de registros pelo suporte.',
        'Limpar os dados do aplicativo, desinstalá-lo, perder ou trocar '
            'o dispositivo pode apagar seus registros locais. Não mantenha '
            'no Cordato a única cópia de informações que precise preservar.',
        'Esta versão não oferece exportação de despesas, criação de backup '
            'ou restauração de arquivos pelo aplicativo.',
        'Recursos de backup e transferência do sistema operacional dependem '
            'das configurações e dos serviços escolhidos por você. '
            'Não garantimos que incluam os registros ou permitam recuperá-los.',
      ],
    ),
    (
      title: 'Gratuidade e apoio voluntário',
      paragraphs: [
        'O uso é gratuito, sem anúncios, assinatura ou pagamento obrigatório. '
            'O apoio por Pix em Configurações → Pague-me um café é voluntário '
            'e não desbloqueia funcionalidades.',
        'O pagamento acontece no aplicativo do seu banco, sob as condições '
            'da instituição financeira. Confira o destinatário e o valor '
            'antes de confirmar. O Cordato não processa nem confirma pagamentos.',
      ],
    ),
    (
      title: 'Encerramento do uso e responsabilidades',
      paragraphs: [
        'Você pode deixar de usar o aplicativo a qualquer momento. Não existe '
            'conta remota para encerrar ou excluir. Para remover os dados locais, '
            'consulte as opções de armazenamento do sistema operacional, quando '
            'disponíveis, ou desinstale o aplicativo.',
        'Essas ações não apagam arquivos exportados anteriormente, cópias do sistema ou '
            'informações compartilhadas com outros aplicativos. '
            'O suporte não tem acesso ao banco local para apagá-lo remotamente.',
        'Podem ocorrer falhas e perda de registros. As limitações destes termos '
            'não excluem direitos ou responsabilidades previstos na legislação '
            'brasileira, inclusive nas normas de defesa do consumidor quando aplicáveis.',
      ],
    ),
    (
      title: 'Atualizações e contato',
      paragraphs: [
        'Estes termos podem mudar para acompanhar o aplicativo ou a legislação. '
            'A versão e a data ficam no início do documento. Avisos ou '
            'manifestações específicas serão solicitados quando exigidos.',
        'Dúvidas podem ser enviadas a $responsible pelo e-mail $email. '
            'Não envie senhas ou dados financeiros desnecessários.',
      ],
    ),
  ];

  static const privacySummary =
      'Nome, seed do avatar e despesas são armazenados no dispositivo. '
      'Não há conta remota nem envio desses registros a um servidor do Cordato. '
      'Não usamos publicidade, análise de comportamento ou processamento de áudio. '
      'Contatar o suporte pode compartilhar informações por sua iniciativa.';

  static const privacySections = [
    (
      title: 'Responsável e contato',
      paragraphs: [
        '$responsible é o responsável pelo Cordato. Para dúvidas sobre esta '
            'política ou solicitações relativas a dados tratados no atendimento, '
            'escreva para $email.',
      ],
    ),
    (
      title: 'Dados armazenados localmente',
      paragraphs: [
        'Perfil: nome de exibição e seed do avatar, uma sequência usada para '
            'gerar a imagem no próprio aplicativo. O nome inicial é Cordato '
            'e a seed inicial é gerada aleatoriamente. Não é necessário enviar '
            'foto da galeria.',
        'Despesas: valor em centavos de real, categoria, descrição quando '
            'informada e data civil. Os resumos usam os registros do dispositivo. '
            'Não solicitamos senha bancária, cartão ou conexão com seu banco.',
        'Não há e-mail de cadastro, senha de acesso, token de sessão ou '
            'identificação de conta remota. Esta versão não oferece captura '
            'de áudio ou envio de conteúdo para serviços de inteligência artificial.',
      ],
    ),
    (
      title: 'Finalidades e acesso',
      paragraphs: [
        'Os dados locais servem para personalizar o perfil, organizar despesas, '
            'preencher sugestões do próprio histórico e apresentar resumos. '
            'O aplicativo não envia esses registros a um servidor do Cordato '
            'nem utiliza ferramentas de publicidade ou análise de comportamento.',
        'Quem tiver acesso ao aplicativo no dispositivo poderá consultar esses '
            'dados. Não há autenticação própria, múltiplos perfis, sincronização '
            'com outros aparelhos ou acesso familiar nesta versão.',
        'O widget do sistema pode manter uma cópia do mês e do total mensal '
            'para exibição fora do aplicativo. Esse resumo pode ficar visível '
            'a quem puder ver a tela do dispositivo.',
      ],
    ),
    (
      title: 'Compartilhamento por sua iniciativa',
      paragraphs: [
        'Esta versão não oferece exportação ou compartilhamento de arquivos '
            'de despesas pelo aplicativo. Cópias enviadas anteriormente a '
            'outros aplicativos ou destinos continuam sob as condições '
            'dos respectivos destinatários.',
        'Se você escrever ao suporte, o endereço de e-mail, o conteúdo e os '
            'anexos enviados serão tratados para responder ao pedido. O envio '
            'envolve os provedores de e-mail e pode incluir processamento '
            'fora do Brasil. Não envie registros financeiros ou dados de '
            'terceiros que não sejam necessários ao atendimento.',
        'O apoio por Pix é realizado no aplicativo do banco. O Cordato não '
            'consulta sua conta bancária nem recebe confirmação automática '
            'do pagamento. A instituição financeira e o destinatário podem '
            'receber os dados da transferência conforme as regras do Pix.',
        'Não vendemos dados pessoais. Comunicações recebidas no atendimento '
            'podem ser conservadas quando necessário ao cumprimento de '
            'obrigação legal ou ao exercício regular de direitos.',
      ],
    ),
    (
      title: 'Segurança e cópias do sistema',
      paragraphs: [
        'Proteja o dispositivo e evite registrar dados pessoais desnecessários. '
            'O banco do Cordato não possui criptografia adicional configurada '
            'pelo aplicativo; a proteção do sistema operacional não equivale '
            'a uma garantia de acesso impossível ou recuperação de dados.',
        'Backups e transferências realizados pelo sistema operacional ou por '
            'serviços escolhidos por você podem copiar dados do aplicativo '
            'para outros locais, conforme suas configurações e políticas. '
            'Isso não é um backup remoto oferecido pelo Cordato.',
      ],
    ),
    (
      title: 'Retenção, remoção e recuperação',
      paragraphs: [
        'Os registros permanecem no armazenamento local até serem removidos '
            'por você ou pelo sistema. Limpar os dados do aplicativo ou '
            'desinstalá-lo pode apagar o perfil e as despesas. Perda ou '
            'troca do dispositivo também pode causar perda dos registros.',
        'Não existe conta remota para excluir. O suporte não tem acesso ao '
            'banco do dispositivo e não pode apagar ou recuperar seus registros '
            'remotamente. Não oferecemos sincronização, backup remoto próprio '
            'ou restauração de arquivos pelo aplicativo.',
        'Excluir dados locais não remove arquivos exportados anteriormente, cópias em backups '
            'do sistema, mensagens de suporte ou cópias enviadas a terceiros. '
            'Gerencie essas cópias nos serviços e destinos utilizados.',
        'Mensagens recebidas no suporte são conservadas pelo tempo necessário '
            'ao atendimento e às obrigações legais aplicáveis. Solicitações '
            'sobre essas mensagens podem ser enviadas a $email; não prometemos '
            'eliminação instantânea das cópias dos provedores de e-mail.',
      ],
    ),
    (
      title: 'Seus direitos',
      paragraphs: [
        'Nos termos da LGPD, você pode solicitar confirmação de tratamento, '
            'acesso, correção e informações sobre compartilhamento e, quando '
            'aplicável, portabilidade, anonimização, bloqueio ou eliminação. '
            'Também pode questionar o tratamento e revogar consentimentos concedidos.',
        'Para dados locais, use os recursos do aplicativo e as opções do '
            'sistema operacional. Para dados enviados ao suporte ou dúvidas '
            'sobre seus direitos, escreva para $email. Não é necessário '
            'fornecer uma conta do Cordato. Podemos solicitar apenas as '
            'informações necessárias para localizar e proteger o atendimento.',
        'Você também pode recorrer à Autoridade Nacional de Proteção de Dados '
            'conforme os procedimentos aplicáveis. A consulta desta política '
            'não constitui consentimento genérico para outros tratamentos.',
      ],
    ),
    (
      title: 'Menores de idade e mudanças nesta política',
      paragraphs: [
        'O aplicativo é destinado a adultos e adolescentes, sem direcionamento '
            'a crianças. O uso por menores deve observar seu melhor interesse '
            'e a orientação de seus responsáveis legais.',
        'A versão e a data ficam no início desta página. Mudanças no tratamento '
            'de dados serão refletidas nesta política, com avisos ou '
            'consentimentos específicos quando exigidos.',
      ],
    ),
  ];

  static const helpSections = [
    (
      title: 'Começar e personalizar',
      questions: [
        (
          question: 'Preciso criar uma conta?',
          answer:
              'Não. O Cordato usa um perfil local, sem cadastro, login ou '
              'senha. Não há sincronização entre dispositivos nem múltiplos '
              'perfis na mesma instalação.',
        ),
        (
          question: 'Como altero meu nome e meu avatar?',
          answer:
              'Abra Configurações → Dados pessoais. Toque no nome para '
              'editá-lo ou no avatar para gerar outra opção. O avatar é '
              'gerado no aplicativo a partir de uma seed, sem enviar foto. '
              'Alterar o nome não muda o avatar nem as despesas.',
        ),
        (
          question: 'Preciso de internet?',
          answer:
              'O perfil e os dados locais não dependem de conexão com '
              'um servidor do Cordato. Termos de uso, Política de Privacidade '
              'e Ajuda também ficam no aplicativo. Enviar um e-mail de suporte '
              'ou usar serviços externos, como o banco para um Pix, pode exigir internet.',
        ),
      ],
    ),
    (
      title: 'Despesas e resumos',
      questions: [
        (
          question: 'Como registro ou altero uma despesa?',
          answer:
              'Abra o cadastro de despesa, informe o valor, a data e a '
              'categoria e confira os campos antes de confirmar. Para editar, '
              'abra uma despesa na listagem e salve as alterações. Sugestões '
              'do histórico não salvam novas despesas automaticamente.',
        ),
        (
          question: 'Como os totais do mês são calculados?',
          answer:
              'Os resumos consideram as despesas pela data civil registrada, '
              'agrupadas por mês e categoria. Não consultam seu banco. '
              'Confira datas, valores e filtros se um total parecer incorreto.',
        ),
        (
          question: 'Posso registrar despesas por áudio?',
          answer:
              'Esta versão local não oferece gravação de áudio nem '
              'interpretação por inteligência artificial. Use o formulário de despesa.',
        ),
      ],
    ),
    (
      title: 'Dados, cópias e privacidade',
      questions: [
        (
          question: 'Posso exportar despesas ou criar um backup?',
          answer:
              'Esta versão não oferece exportação de despesas, criação de '
              'backup ou restauração de arquivos pelo aplicativo. Recursos '
              'de cópia do sistema operacional dependem das suas configurações '
              'e não são um backup próprio do Cordato.',
        ),
        (
          question: 'O que acontece se eu desinstalar ou trocar de aparelho?',
          answer:
              'Os registros são locais e podem ser perdidos ao desinstalar, '
              'limpar os dados, perder ou trocar o dispositivo. Não há '
              'sincronização, backup remoto próprio ou recuperação pelo suporte. '
              'Recursos de backup do sistema dependem das suas configurações '
              'e não garantem a recuperação. Preserve informações importantes '
              'separadamente.',
        ),
        (
          question: 'Como removo meus dados?',
          answer:
              'Não há conta remota para excluir. Você pode excluir despesas '
              'pela listagem. Para remover os dados locais do aplicativo, '
              'consulte as opções de armazenamento do sistema, quando disponíveis, '
              'ou desinstale o app. Isso não apaga arquivos exportados anteriormente, backups '
              'do sistema ou cópias compartilhadas. O suporte não pode apagar '
              'o banco local remotamente.',
        ),
        (
          question: 'Como falo com o suporte?',
          answer:
              'Escreva para $email e descreva o problema. Não envie senhas '
              'ou dados financeiros desnecessários. Podemos orientar, mas não '
              'temos acesso ao armazenamento do seu dispositivo para recuperar '
              'registros. Pedidos sobre mensagens enviadas ao suporte podem '
              'ser feitos pelo mesmo contato.',
        ),
      ],
    ),
  ];
}
