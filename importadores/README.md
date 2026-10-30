# Importadores do Configurador

Rotinas que fazem em lote, a partir de um arquivo CSV, cadastros do Configurador que normalmente são feitos um a um na tela. As duas gravam pelos **modelos MVC padrão do framework** (os mesmos do Configurador), então senha, checksum, auditoria e validações ficam por conta do próprio Protheus.

As duas têm **simulação**: valida o arquivo e gera o log sem gravar nada.

## Fontes

| Fonte | Versão | O que faz |
|---|---|---|
| [`ZIMPUSR.prw`](ZIMPUSR.prw) | 2.0.1 | **Importador de usuários e grupos.** Inclui, atualiza ou exclui usuários (modelo `MPUSERACCOUNTDATA`) e grupos (`MPGROUPACCOUNTDATA`), com grupos, filiais, módulos e menus, acessos, superiores, horários, papéis e regras de privilégio. Quatro modos: incluir novos, incluir e atualizar, só atualizar, excluir. Na atualização, célula vazia mantém o valor atual. Protege o admin, o usuário logado, o grupo Administradores e grupos com usuários. A exclusão exige digitar EXCLUIR. Funções: `U_ZIMPUSR` (tela), `U_ZIMPUSRJ` (usuários sem interface), `U_ZIMPGRPJ` (grupos sem interface) e `U_ZIMPUSRV` (mostra a versão compilada). |
| [`ZIMPPRV.prw`](ZIMPPRV.prw) | 1.0.0 | **Importador de regras de privilégio** (Configurador > Privilégios, CFGA530), pelo modelo `FWRULESACCOUNTDATA`. Cada linha do CSV é uma regra × rotina, com colunas S/N/X para Visualizar, Incluir, Alterar, Excluir, Estornar, Baixar, Aprovar, Imprimir e Contabilizar. Cada item do menu da rotina é classificado pelo nome (ex.: "Canc. Desdobr." conta como Estornar) ou pela operação. Itens que não se encaixam saem no log como SEM COLUNA, para conferência. Funções: `U_ZIMPPRV` (tela), `U_ZIMPPRVJ` (sem interface) e `U_ZIMPPRVV` (versão). |

O formato completo do CSV (colunas, separadores, codificação) está documentado no cabeçalho de cada fonte.

Os arquivos são **Windows-1252 com CRLF**. Não converter para UTF-8, porque o compilador do Protheus não aceita.
