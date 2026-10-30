# Históricos do Funcionário (SIGAGPE)

Customização do módulo **Gestão de Pessoal** que guarda, numa tabela própria (**ZHF**), o histórico de situações do funcionário (SRA) que o Protheus padrão não registra: função gratificada, horário reduzido, licença sem vencimento, penalidades/TAC, adicionais (periculosidade, insalubridade, periculosidade judicial), comissão, auxílio creche/financeiro, ticket, condutor, elogios e licença paternidade.

O histórico é gravado de três jeitos:

- **Manual**: pela tela de Históricos, aberta pelo Cadastro de Funcionários ou direto pela rotina.
- **Automático**: ao salvar o Cadastro de Funcionários, os campos monitorados que mudaram viram uma linha nova.
- **Carga inicial**: grava a situação atual de todos os funcionários, uma vez por filial.

Ambiente de desenvolvimento: Protheus 12.1.2510.

## Fontes

| Fonte | Tipo | O que faz |
|---|---|---|
| [`ZGPX010.tlpp`](ZGPX010.tlpp) | Funções de apoio | Base do projeto, usada pelos outros fontes. Lista os 13 tipos de histórico (`U_ZGPX010C`, usada no combo do campo `ZHF_TIPO`) e a descrição de cada tipo (`U_ZGPX010T`). Traz os inicializadores da matrícula e do nome (`U_ZGPX010I`, `U_ZGPX010N`) e calcula a próxima sequência (`U_ZGPX010S`). Lê o parâmetro `MV_ZHFCPOS`, que liga cada tipo a um campo da SRA (`U_ZGPX010M`). A função principal é `U_ZGPX010G`: compara os campos monitorados do funcionário com o último histórico de cada tipo e grava uma linha nova quando o valor mudou. Não usa interface, então pode rodar dentro da gravação do cadastro. Na função gratificada, a data do histórico é a de designação (`RA_DTDESIG`) ou, quando a função é retirada, a de destituição (`RA_DTDESTI`). `U_ZGPX010V` transforma o valor gravado em texto para o relatório: código + descrição da função (tabela SZA) ou a descrição da opção do campo (ex.: "Sim", "Insalubridade Média"). |
| [`ZGPA010.prw`](ZGPA010.prw) | Tela MVC | Cadastro dos históricos (browse + formulário). `U_ZGPA010` abre com todos os funcionários. `U_ZGPA010F` abre filtrada no funcionário posicionado (chamada pela opção "Históricos" do Cadastro de Funcionários). `U_ZGPA010W` libera ou bloqueia cada campo conforme o tipo escolhido. Feita em AdvPL (`.prw`) porque MVC em TLPP exige namespace. |
| [`ZGPR010.tlpp`](ZGPR010.tlpp) | Relatório (TReport) | Relatório de históricos por faixa de matrícula, tipo e período, em página horizontal. Mostra cada funcionário com as linhas do histórico, a origem (manual, automática ou carga), a situação e os valores anterior e novo já em texto. |
| [`ZGPM010.tlpp`](ZGPM010.tlpp) | Rotina de carga | Carga inicial: grava o valor atual dos campos monitorados para todos os funcionários não demitidos da filial que ainda não têm histórico daquele tipo. `U_ZGPM010` roda com tela de confirmação; `U_ZGPM010J` roda sem interface (job/Schedule). |
| [`GPE10OPC.tlpp`](GPE10OPC.tlpp) | Ponto de entrada | Inclui a opção **"Históricos"** no menu do Cadastro de Funcionários (GPEA010). Por estar na MenuDef, a opção também aparece no cadastro de Privilégios. |
| [`GPE10MENU.prw`](GPE10MENU.prw) | Ponto de entrada | Mesma opção "Históricos" para ambientes cujo GPEA010 ainda não chama o GPE10OPC. Se a opção já existir, não duplica. |
| [`GP010AGRV.tlpp`](GP010AGRV.tlpp) | Ponto de entrada | Roda depois que o Cadastro de Funcionários grava uma inclusão ou alteração e chama `U_ZGPX010G` para registrar automaticamente o que mudou. Se falhar, só registra no log, sem travar a gravação do funcionário. |
| [`teste/ZGPTST.prw`](teste/ZGPTST.prw) | Teste (só base local) | Testes automáticos do projeto: regras da tela por tipo, gravação manual, bloqueio de dependente inválido, gravação automática (grava quando muda e não grava quando não muda), proteção das linhas automáticas e carga inicial sem duplicar. Roda em job como programa inicial `U_ZGPTST`. **Não compilar no cliente.** |

## Dicionário (tabela ZHF)

| Campo | Tipo | Tamanho | Descrição |
|---|---|---|---|
| ZHF_FILIAL | C | 2 | Filial |
| ZHF_MAT | C | 6 | Matrícula do funcionário (gatilho preenche o nome) |
| ZHF_NOME | C | 30 | Nome (virtual) |
| ZHF_TIPO | C | 2 | Tipo do histórico (combo `#U_ZGPX010C()`) |
| ZHF_SEQ | C | 3 | Sequência por filial + matrícula + tipo |
| ZHF_DATA | D | 8 | Data do evento |
| ZHF_SITUAC | C | 1 | Situação Sim/Não (tipos 02, 03, 08, 11, 12, 13) |
| ZHF_PENAL | C | 1 | Penalidade (tipo 04) |
| ZHF_TPAUX | C | 1 | Tipo de auxílio (tipo 09): 1 = Creche, 2 = Creche judicial, 3 = Financeiro, 4 = Financeiro judicial |
| ZHF_DEPEND | C | 2 | Dependente |
| ZHF_PROCES | C | 40 | Processo / documento |
| ZHF_VLANT | C | 60 | Valor anterior |
| ZHF_VLNOV | C | 60 | Valor novo |
| ZHF_ORIGEM | C | 1 | 1 = Manual, 2 = Automática (cadastro), 3 = Carga inicial |
| ZHF_USER | C | 25 | Usuário que gravou |
| ZHF_DTINC | D | 8 | Data da inclusão |
| ZHF_HRINC | C | 8 | Hora da inclusão |

Índices: `1 = ZHF_FILIAL + ZHF_MAT + ZHF_TIPO + ZHF_SEQ` e `2 = ZHF_FILIAL + ZHF_TIPO + DTOS(ZHF_DATA)`.

Parâmetro **`MV_ZHFCPOS`**: liga cada tipo ao campo da SRA que é monitorado na gravação automática. Padrão: `01=RA_XCODFUN;05=RA_ADCPERI;06=RA_ADCINS;07=RA_XPERELE;10=RA_XOPTICK` (função gratificada, periculosidade, insalubridade, periculosidade judicial e opção de ticket). Campos que não existem no ambiente são ignorados.

## Como instalar

1. Criar a tabela ZHF, os índices, o gatilho `ZHF_MAT → ZHF_NOME` e o parâmetro `MV_ZHFCPOS` no dicionário.
2. Compilar os 7 fontes da pasta (sem o `teste/`). Os `.tlpp` precisam do include `tlpp-core.th`.
3. Se o ambiente já tiver algum dos pontos de entrada (GPE10OPC, GPE10MENU, GP010AGRV), juntar o trecho deste projeto ao fonte que já existe.
4. Rodar a carga inicial (`U_ZGPM010`) uma vez em cada filial.
5. Incluir `U_ZGPA010` e `U_ZGPR010` no menu do SIGAGPE.
