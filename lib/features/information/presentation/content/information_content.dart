abstract final class InformationContent {
  static const version = '1.1';
  static const updatedAt = '12/11/2026';
  static const responsible = 'Gabriel Ramos';
  static const email = 'developer.bed@gmail.com';

  static const termsSummary =
      'O Cordato ajuda você a registrar despesas e entender seus gastos. '
      'O uso é gratuito, sem anúncios ou assinatura. '
      'Você pode encerrar sua conta quando quiser.';

  static const termsSections = [
    (
      title: 'Sobre o Cordato',
      paragraphs: [
        'O Cordato é um aplicativo de organização financeira pessoal mantido '
            'por $responsible. Estes Termos de uso regem a utilização do aplicativo. '
            'Leia também a Política de Privacidade para conhecer o tratamento dos seus dados.',
        'Você pode registrar, consultar, editar e excluir despesas, além de acompanhar '
            'totais e categorias por mês. O Cordato não é um banco, não movimenta '
            'dinheiro, não concede crédito e não oferece consultoria de investimentos.',
      ],
    ),
    (
      title: 'Quem pode usar',
      paragraphs: [
        'O aplicativo é destinado a adultos e adolescentes, sem direcionamento '
            'a crianças. Se você for menor de idade, utilize o serviço com '
            'orientação do seu responsável legal e com a assistência ou '
            'autorização exigida pela legislação aplicável.',
      ],
    ),
    (
      title: 'Sua conta e sua segurança',
      paragraphs: [
        'Para utilizar os recursos pessoais, crie uma conta com um e-mail ao '
            'qual você tenha acesso, confirme esse endereço e escolha uma senha. '
            'Mantenha seus dados corretos e sua senha em sigilo.',
        'Não compartilhe senhas, códigos ou links de confirmação e recuperação. '
            'Se suspeitar de acesso indevido, redefina sua senha e fale com '
            '$email. Nunca pedimos sua senha por e-mail.',
      ],
    ),
    (
      title: 'Seus registros',
      paragraphs: [
        'As despesas são registros informados por você. Confira os valores, '
            'as datas e as categorias antes de tomar decisões. Os totais '
            'apresentados dependem desses registros e não substituem extratos '
            'bancários ou orientação profissional.',
        'O envio de áudio é opcional e usa inteligência artificial para '
            'interpretar uma despesa e tentar cadastrá-la na sua conta. '
            'O aceite do envio não confirma o cadastro. A interpretação pode '
            'conter erros ou falhar; confira suas despesas antes de reenviar '
            'um áudio para evitar duplicações.',
        'Você continua sendo titular dos seus dados. Não use o aplicativo para '
            'atividades ilícitas, tentar acessar contas de outras pessoas ou '
            'comprometer a segurança e o funcionamento do serviço.',
      ],
    ),
    (
      title: 'Gratuidade e disponibilidade',
      paragraphs: [
        'O uso atual do Cordato é gratuito, sem anúncios, assinatura ou '
            'pagamento obrigatório para acessar seus recursos.',
        'O acesso à conta e a gravação ou consulta de despesas dependem '
            'de conexão com a internet. Manutenções, falhas e interrupções '
            'podem ocorrer. Não prometemos disponibilidade ininterrupta '
            'ou recuperação de registros excluídos ou perdidos.',
        'Backups não garantem a recuperação de registros excluídos ou perdidos. '
            'Não utilize o aplicativo como a única cópia de informações '
            'financeiras que você precise preservar.',
      ],
    ),
    (
      title: 'Encerramento e exclusão',
      paragraphs: [
        'Você pode deixar de usar o aplicativo a qualquer momento. Para excluir '
            'sua conta e as despesas associadas, acesse Configurações → '
            'Dados pessoais → Excluir conta e confirme a ação.',
        'Sem acesso ao aplicativo, solicite a exclusão pelo e-mail $email, '
            'com o assunto "Exclusão de conta Cordato". Informe o e-mail '
            'cadastrado, sem enviar sua senha. Podemos confirmar sua identidade '
            'para proteger a conta. Desinstalar o aplicativo ou sair da sessão '
            'não exclui os dados armazenados no serviço.',
      ],
    ),
    (
      title: 'Responsabilidades e seus direitos',
      paragraphs: [
        'Cuide do acesso à sua conta e confira as informações que registrar. '
            'As limitações descritas nestes termos não excluem direitos '
            'ou responsabilidades previstos na legislação brasileira, '
            'inclusive nas normas de defesa do consumidor quando aplicáveis.',
      ],
    ),
    (
      title: 'Atualizações e contato',
      paragraphs: [
        'Estes termos podem ser atualizados para acompanhar mudanças no '
            'aplicativo ou na legislação. A versão e a data de atualização '
            'ficam no início deste documento. Alterações que exijam aviso '
            'ou nova manifestação serão tratadas conforme a legislação aplicável.',
        'Dúvidas sobre estes termos ou sobre o Cordato podem ser enviadas '
            'a $responsible pelo e-mail $email.',
      ],
    ),
  ];

  static const privacySummary =
      'Usamos os dados da sua conta e das suas despesas para fazer o Cordato '
      'funcionar. Se você enviar áudio, ele será processado por serviços de '
      'inteligência artificial para registrar uma despesa. '
      'Não vendemos seus dados nem usamos ferramentas de publicidade '
      'ou análise de comportamento no aplicativo. Você pode pedir acesso, '
      'correção ou exclusão pelo nosso contato.';

  static const privacySections = [
    (
      title: 'Quem cuida dos seus dados',
      paragraphs: [
        '$responsible é o responsável pelo Cordato e pelo tratamento dos '
            'dados pessoais descritos nesta Política de Privacidade. '
            'Para dúvidas ou solicitações sobre seus dados, escreva para $email.',
      ],
    ),
    (
      title: 'Quais dados são tratados',
      paragraphs: [
        'Conta: e-mail, nome quando informado, identificação da conta, '
            'representação do avatar, senha protegida pelo mecanismo de '
            'autenticação e situação da confirmação do e-mail. No dispositivo, '
            'armazenamos a identificação da conta e a credencial de sessão '
            'para manter seu acesso.',
        'Despesas: descrição, valor, data, categoria e vínculo com sua conta. '
            'Os resumos mensais são derivados desses registros. Não solicitamos '
            'senha bancária, número de cartão ou conexão com sua instituição financeira.',
        'Áudio: quando você grava e aciona o envio, tratamos sua voz, o conteúdo '
            'da gravação e a data de referência do dispositivo para interpretar '
            'a despesa. O conteúdo pode incluir dados pessoais e financeiros '
            'que você mencionar. O uso desse recurso é opcional; você pode '
            'continuar cadastrando despesas pelo formulário.',
        'Comunicações: endereço de e-mail, conteúdo e registros de entrega '
            'das mensagens de confirmação de conta e recuperação de senha. '
            'Se você entrar em contato, também trataremos o que enviar '
            'para responder à solicitação.',
        'A operação da infraestrutura pode gerar registros técnicos, como '
            'endereço IP, data, horário e resultado de requisições. Isso é '
            'diferente de ferramentas de publicidade ou análise de comportamento, '
            'que não integram o aplicativo.',
      ],
    ),
    (
      title: 'Para que usamos esses dados',
      paragraphs: [
        'Usamos os dados para criar e proteger sua conta, autenticar o acesso, '
            'enviar mensagens necessárias à conta, armazenar suas despesas, '
            'apresentar sugestões do seu próprio histórico e calcular '
            'resumos mensais. Também os usamos para atender solicitações '
            'e investigar problemas de segurança ou funcionamento.',
        'No recurso de áudio, nosso serviço de processamento (worker) verifica '
            'sua sessão e encaminha a gravação à inteligência artificial. '
            'Os dados extraídos, como descrição, valor, data e categoria, '
            'são validados para tentar cadastrar uma despesa na sua conta. '
            'Sua senha e sua credencial de sessão não são enviadas à IA.',
        'O tratamento necessário ao serviço se relaciona à execução da relação '
            'de uso e às etapas solicitadas por você. Outras bases legais, '
            'como cumprimento de obrigação legal ou exercício regular '
            'de direitos, são utilizadas quando cabíveis. Quando uma '
            'operação depender de consentimento, ele deverá ser solicitado '
            'de forma específica; consultar esta política não é um '
            'consentimento genérico para qualquer uso dos seus dados.',
      ],
    ),
    (
      title: 'Provedores e localização',
      paragraphs: [
        'O banco de dados do Cordato está hospedado na Hostinger, no Brasil. '
            'A infraestrutura de hospedagem participa do armazenamento '
            'e da operação necessários ao serviço.',
        'Usamos o Resend para enviar e-mails transacionais. Para isso, '
            'ele recebe o endereço do destinatário, o conteúdo da mensagem '
            'e os dados técnicos necessários à entrega. Os e-mails de '
            'confirmação e recuperação incluem links de uso restrito; '
            'não enviamos suas despesas nessas mensagens.',
        'O Resend informa que armazena dados nos Estados Unidos e utiliza '
            'suboperadores. Portanto, o envio dessas mensagens envolve '
            'tratamento internacional, mesmo com o banco principal no Brasil. '
            'Informações do provedor estão disponíveis em '
            'https://resend.com/security/gdpr e https://resend.com/legal/dpa.',
        'Para interpretar áudios, a configuração padrão utiliza o OpenRouter '
            'como intermediário de acesso a modelos de IA, com um modelo '
            'da família Gemini, do Google. O áudio e a data de referência '
            'são enviados ao serviço de IA configurado e aos provedores '
            'envolvidos no processamento. Esse tratamento pode ocorrer '
            'fora do Brasil, mesmo com o banco principal hospedado no país. '
            'O modelo e o provedor efetivamente utilizados dependem da '
            'configuração do serviço; informações sobre os operadores '
            'aplicáveis podem ser solicitadas pelo nosso contato.',
        'O processamento de IA está sujeito às políticas e às configurações '
            'do intermediário e do provedor. No OpenRouter, a integração '
            'solicita provedores que não coletem dados e desativa fallback '
            'automático. Isso não garante retenção zero nem comprova que '
            'todo provedor tenha as mesmas condições. Consulte '
            'https://openrouter.ai/privacy e solicite esclarecimentos '
            'pelo nosso contato antes de enviar conteúdo sensível.',
        'Não vendemos dados pessoais. Além dos provedores necessários '
            'à operação, dados podem ser apresentados às autoridades '
            'quando houver obrigação legal aplicável.',
      ],
    ),
    (
      title: 'Proteção e cuidados',
      paragraphs: [
        'O acesso aos seus registros depende de autenticação e das regras '
            'de autorização do serviço. No dispositivo, as credenciais '
            'de sessão usam o armazenamento seguro disponibilizado '
            'pelo sistema operacional. Nenhum serviço é isento de riscos.',
        'Não compartilhe sua senha nem links recebidos por e-mail. Evite '
            'registrar dados pessoais desnecessários, especialmente de '
            'outras pessoas, no campo de descrição das despesas ou nas '
            'gravações. O microfone é usado mediante permissão para a captura '
            'iniciada por você; a gravação tem limite de 30 segundos. '
            'A permissão de microfone não autoriza outros usos dos seus dados.',
      ],
    ),
    (
      title: 'Retenção e exclusão',
      paragraphs: [
        'Os dados da conta e as despesas permanecem no banco enquanto '
            'sua conta existir, até que você exclua os registros ou solicite '
            'a exclusão da conta.',
        'A configuração inicial do banco prevê backups semanais e até três '
            'cópias automáticas. Esse agendamento não comprova execução ou '
            'recuperação e pode diferir da configuração em operação. '
            'Cópias existentes podem conservar registros excluídos até sua '
            'substituição ou remoção. Para conhecer a situação e os prazos '
            'efetivos dos backups, entre em contato; não prometemos '
            'recuperação de dados nem eliminação imediata das cópias.',
        'A gravação usa um arquivo temporário no dispositivo, removido pelo '
            'fluxo de finalização ou cancelamento. O worker processa o áudio '
            'em memória, sem arquivo ou fila persistente; reinícios podem '
            'perder envios aceitos. Os logs desse processamento não incluem '
            'áudio, conteúdo interpretado ou credenciais. Isso não elimina '
            'a possibilidade de retenção nos serviços de IA: os prazos e '
            'as condições dependem dos operadores e da configuração contratada. '
            'Não prometemos retenção zero nem exclusão instantânea nesses serviços.',
        'A exclusão da conta remove seu cadastro e as despesas associadas '
            'do banco do Cordato. Sair da sessão ou desinstalar o app '
            'não produz essa exclusão. Mensagens já entregues permanecem '
            'na sua caixa de e-mail conforme o controle do seu provedor.',
        'Os provedores também podem conservar dados. O Resend informa retenção de conteúdo e '
            'registros de e-mail por 30 dias nos planos Free, Pro e Scale, '
            'com condições diferentes no Enterprise, e backups próprios '
            'por 7 dias. Esses prazos não representam o tempo de exclusão '
            'da sua conta no Cordato.',
        'Pedidos sobre registros técnicos, mensagens nos provedores '
            'ou comunicações de suporte podem ser enviados a $email. '
            'Eventual conservação necessária para cumprir obrigação legal '
            'ou exercer direitos será limitada à finalidade e ao prazo '
            'aplicáveis; não prometemos eliminação instantânea em toda '
            'a infraestrutura de terceiros.',
      ],
    ),
    (
      title: 'Seus direitos e como exercê-los',
      paragraphs: [
        'Nos termos da LGPD, você pode solicitar confirmação de tratamento, '
            'acesso, correção, informações sobre compartilhamento e, '
            'quando aplicável, portabilidade, anonimização, bloqueio '
            'ou eliminação. Também pode questionar o tratamento '
            'e revogar consentimentos que tenha concedido.',
        'Para excluir a conta no app, vá a Configurações → Dados pessoais '
            '→ Excluir conta. Sem acesso ao app, escreva para $email '
            'com o assunto "Exclusão de conta Cordato" e informe o '
            'e-mail cadastrado. Não envie sua senha. Podemos solicitar '
            'confirmação de identidade para evitar exclusões indevidas '
            'e informaremos as etapas necessárias no atendimento.',
        'Para os demais direitos, use o mesmo contato e descreva o pedido. '
            'Você também pode recorrer à Autoridade Nacional de '
            'Proteção de Dados, conforme os procedimentos aplicáveis.',
      ],
    ),
    (
      title: 'Adolescentes e crianças',
      paragraphs: [
        'O Cordato é destinado a adultos e adolescentes, sem direcionamento '
            'a crianças. Adolescentes devem contar com orientação de '
            'seus responsáveis legais e com a assistência ou autorização '
            'necessária ao uso. O tratamento de dados de menores deve '
            'observar seu melhor interesse.',
        'Se você for responsável e tiver dúvidas sobre uma conta de menor '
            'de idade, entre em contato pelo e-mail $email para '
            'solicitar avaliação e as providências cabíveis.',
      ],
    ),
    (
      title: 'Mudanças nesta política',
      paragraphs: [
        'A versão e a data de atualização estão no início desta página. '
            'Mudanças no tratamento de dados devem ser refletidas '
            'nesta política. Avisos e consentimentos específicos serão '
            'adotados quando exigidos pela legislação aplicável.',
      ],
    ),
  ];

  static const helpSections = [
    (
      title: 'Conta e acesso',
      questions: [
        (
          question: 'Como começo a usar o Cordato?',
          answer:
              'Na tela inicial, toque em Continuar e depois em Crie uma. '
              'Cadastre seu e-mail e uma senha, confirme o e-mail pelo '
              'link recebido e entre na sua conta.',
        ),
        (
          question: 'Não recebi o e-mail de confirmação. E agora?',
          answer:
              'Confira o endereço informado e as pastas de spam e lixo '
              'eletrônico. Use Reenviar na tela de confirmação. Após um '
              'envio bem-sucedido, aguarde os 60 segundos indicados '
              'antes de solicitar outro. Se continuar sem receber, '
              'entre em contato pelo e-mail de suporte abaixo.',
        ),
        (
          question: 'Como recupero minha senha?',
          answer:
              'Na tela de entrada, toque em recupere sua senha. '
              'Informe seu e-mail e siga o link recebido para definir uma '
              'nova senha. A mensagem de solicitação não confirma '
              'se existe uma conta para aquele endereço. Se o link '
              'estiver inválido ou expirado, solicite outro.',
        ),
        (
          question: 'O que acontece quando saio da conta?',
          answer:
              'Em Configurações, Sair remove a sessão deste dispositivo, '
              'sem invalidar cópias da credencial no servidor ou encerrar '
              'o acesso em outros dispositivos. Essa ação não exclui sua '
              'conta ou suas despesas. Se suspeitar de acesso indevido, '
              'redefina sua senha e entre em contato com o suporte.',
        ),
      ],
    ),
    (
      title: 'Despesas e resumos',
      questions: [
        (
          question: 'Como registro ou altero uma despesa?',
          answer:
              'Abra o cadastro de despesa, preencha descrição, valor, '
              'data e categoria e confirme. Para editar, abra uma despesa '
              'na listagem, ajuste os campos e salve. Uma sugestão do '
              'histórico apenas ajuda a preencher o formulário: ela '
              'não salva uma nova despesa automaticamente.',
        ),
        (
          question: 'Como os totais do mês são calculados?',
          answer:
              'Os resumos consideram os valores e as categorias das '
              'despesas da sua conta, agrupados pelo mês da data '
              'registrada. Eles não consultam sua conta bancária. '
              'Se um total parecer incorreto, confira as datas, '
              'os valores e os filtros da listagem.',
        ),
        (
          question: 'Preciso de internet? Meus dados têm backup?',
          answer:
              'Você precisa de internet para acessar a conta, consultar '
              'e salvar despesas. As páginas de Termos de uso, Política '
              'de Privacidade e Ajuda ficam no próprio app. A configuração '
              'inicial prevê backups semanais e até três cópias automáticas, '
              'mas isso não comprova sua execução nem garante recuperação. '
              'Consulte nosso contato sobre os backups em operação. Preserve '
              'separadamente as informações que forem importantes.',
        ),
        (
          question: 'O que acontece quando envio um áudio?',
          answer:
              'O envio é opcional. A gravação passa pelo nosso serviço de '
              'processamento e por serviços de inteligência artificial para '
              'interpretar e tentar cadastrar uma despesa. A configuração '
              'padrão usa OpenRouter e um modelo Gemini, do Google, e pode '
              'envolver processamento fora do Brasil. Não grave senhas nem '
              'dados desnecessários de terceiros. O aceite não confirma o '
              'cadastro: recarregue e confira suas despesas antes de reenviar '
              'para evitar duplicações. Consulte a Política de Privacidade '
              'sobre compartilhamento e retenção ou use o formulário manual.',
        ),
      ],
    ),
    (
      title: 'Privacidade e exclusão',
      questions: [
        (
          question: 'Como altero meu nome e meu avatar?',
          answer:
              'Abra Configurações → Dados pessoais. Toque no nome '
              'para editá-lo ou no avatar para gerar outra opção. '
              'O avatar é gerado no aplicativo, sem precisar enviar '
              'uma foto da sua galeria.',
        ),
        (
          question: 'Como excluo minha conta?',
          answer:
              'Vá a Configurações → Dados pessoais → Excluir conta '
              'e confirme. A ação exclui a conta e suas despesas. '
              'Sair ou desinstalar o aplicativo não exclui sua conta. '
              'Consulte a Política de Privacidade para entender '
              'a retenção de registros pelos provedores.',
        ),
        (
          question: 'Como peço exclusão sem acessar o aplicativo?',
          answer:
              'Escreva para $email com o assunto "Exclusão de conta '
              'Cordato". Informe o e-mail cadastrado, de preferência '
              'enviando a solicitação por ele. Não envie senhas ou '
              'links de recuperação. Podemos confirmar sua identidade '
              'antes de atender ao pedido. Você não precisa '
              'reinstalar o aplicativo para solicitar a exclusão.',
        ),
      ],
    ),
  ];
}
