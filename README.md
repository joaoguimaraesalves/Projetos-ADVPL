# Projetos e Fontes em ADVPL

Bem-vindo ao meu repositório de trabalho! Aqui você encontrará o código-fonte de projetos e rotinas que desenvolvo em ADVPL/TLPP para o TOTVS Protheus. A ideia é ter um espaço centralizado para armazenar e organizar as soluções que crio no meu dia a dia profissional.

## Projetos

| Pasta | O que é |
|---|---|
| [`historicos-funcionario/`](historicos-funcionario/) | **Históricos do Funcionário (SIGAGPE).** Tabela própria (ZHF) com o histórico de função gratificada, adicionais, licenças, penalidades, auxílios e outros, com tela MVC, relatório, carga inicial e gravação automática ao salvar o Cadastro de Funcionários. 7 fontes + 1 de teste. |
| [`importadores/`](importadores/) | **Importadores do Configurador.** Importação de usuários e grupos (ZIMPUSR) e de regras de privilégio (ZIMPPRV) a partir de CSV, pelos modelos MVC padrão. |

Cada pasta tem um README com a explicação de cada fonte, e todo fonte tem um cabeçalho Protheus.doc descrevendo o que faz.

## Fontes avulsos

| Fonte | O que faz |
|---|---|
| [`EREST_02.prw`](EREST_02.prw) | Serviço REST `CLIENTES` (WSRESTFUL): `GET /CLIENTES/{CPF}` devolve em JSON os dados do cliente (SA1) daquele CPF, com tipo de pessoa, bloqueio e endereços principal, de cobrança, de entrega e de recebimento. |
| [`F0100110.prw`](F0100110.prw) | Cadastro de Regiões em MVC (Modelo 1) sobre a tabela ZA6: browse, ModelDef e ViewDef. |

## Observações

- Os fontes estão em **Windows-1252 com CRLF**, o único formato aceito pelo compilador do Protheus. O `.gitattributes` impede o Git de convertê-los. No GitHub, alguns acentos podem aparecer trocados, mas o arquivo está correto.
- Nenhum fonte contém senha, chave ou dado de cliente.
