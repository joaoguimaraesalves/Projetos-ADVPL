# Históricos do Funcionário (SIGAGPE)

Customização do módulo **Gestão de Pessoal** que guarda, numa tabela própria (**ZHF**), o histórico de situações do funcionário (SRA) que o Protheus padrão não registra: função gratificada, horário reduzido, licença sem vencimento, penalidades/TAC, adicionais (periculosidade, insalubridade, periculosidade judicial), comissão, auxílio creche/financeiro, ticket, condutor, elogios e licença paternidade.

O histórico é gravado de três jeitos:

- **Manual**: pela tela de Históricos (legenda verde).
- **Automático**: ao salvar o Cadastro ou a Gestão de Funcionários, os campos monitorados que mudaram viram uma linha nova (legenda azul). O histórico novo fecha o anterior do mesmo tipo (Data Final).
- **Carga inicial**: grava a situação atual de todos os funcionários, uma vez por filial (legenda amarela).

Cada histórico tem **Data Inicial, Data Final e Processo**, e toda inclusão, alteração ou exclusão fica registrada na tabela de auditoria **ZHG** (quem, quando e o que mudou). Na aba **Adicionais** do cadastro entram o prazo e as datas de início e fim da periculosidade e da insalubridade, que só abrem quando o funcionário tem o adicional.

Os nomes seguem o padrão do ambiente do cliente (`CBGPE` + tipo + número, tudo em `.prw`). Ambiente de desenvolvimento: Protheus 12.1.2510.

## Fontes

| Fonte | Tipo | O que faz |
|---|---|---|
| [`CBGPEX01.prw`](CBGPEX01.prw) | Funções de apoio | Base do projeto, usada pelos outros fontes (funções `U_CBXHIS*`). Lista os 13 tipos de histórico (`U_CBXHISC`, combo do `ZHF_TIPO`), inicializadores, próxima sequência e o mapa de campos monitorados (`MV_ZHFCPOS`). A função principal é `U_CBXHISG`: compara os campos monitorados do funcionário com o último histórico de cada tipo, pede Data Inicial/Final/Processo quando há tela e grava a linha nova; também acerta a Data Final quando só o prazo do adicional muda. Traz o bloqueio de prazo/datas do adicional (`U_CBXHISW`, `U_CBXHISK`), a auditoria (`U_CBXHISA`) e o texto dos valores para tela e relatório (`U_CBXHISV`). |
| [`CBGPEA21.prw`](CBGPEA21.prw) | Tela MVC | Cadastro dos históricos (browse + formulário). `U_CBGPEA21` abre com todos os funcionários; `U_CBGPA21F` abre filtrada no funcionário posicionado (opção "Históricos" do cadastro). Mostra o valor anterior/novo também por extenso (ex.: `1 - 50/50`). Outras Ações: Auditoria, Legenda, Relatório e Carga inicial. Linhas automáticas não podem ser excluídas. |
| [`CBGPER20.prw`](CBGPER20.prw) | Relatório (TReport) | Relatório por faixa de matrícula, tipo e período, em paisagem, com origem, situação, valores em texto e quem incluiu/alterou. |
| [`CBGPEM13.prw`](CBGPEM13.prw) | Rotina de carga | Carga inicial: grava o valor atual dos campos monitorados de todos os funcionários não demitidos da filial que ainda não têm histórico daquele tipo. `U_CBGPEM13` com tela; `U_CBGPM13J` sem interface (job/Schedule). |
| [`UPDZHF00.prw`](UPDZHF00.prw) | Compatibilizador | Cria a tabela ZHF (SX2, SX3, SIX e o gatilho da matrícula) e a tabela física. Tem modo Simular; não grava nada se encontrar inconsistência. |
| [`UPDZHF01.prw`](UPDZHF01.prw) | Compatibilizador | Campos da v3: prazo e datas dos adicionais na aba Adicionais da SRA, campos de auditoria na ZHF e a tabela ZHG. Também com modo Simular. |
| [`GPE10OPC.prw`](GPE10OPC.prw) | Ponto de entrada | Opção **"Históricos"** na MenuDef do Cadastro de Funcionários (GPEA010); aparece em Privilégios. |
| [`GP011MEN.prw`](GP011MEN.prw) | Ponto de entrada | Mesma opção na **Gestão de Funcionários** (GPEA011). |
| [`GPE10MENU.prw`](GPE10MENU.prw) | Ponto de entrada | Opção "Históricos" para ambientes cujo GPEA010 não chama o GPE10OPC; não duplica. |
| [`GP010AGRV.tlpp`](GP010AGRV.tlpp) | Ponto de entrada | Depois de gravar o funcionário, chama `U_CBXHISG("2")`. Se falhar, só registra no log, sem travar a gravação. |

Se o ambiente já tiver algum desses pontos de entrada, juntar o trecho deste projeto ao fonte existente e compilar **com o nome de arquivo original** (outro nome dá "Duplicated function").

## Dicionário

**ZHF** (25 campos): filial, matrícula, nome, tipo, sequência, Data Inicial, Data Final, situação, penalidade, tipo de auxílio, dependente, processo, valor anterior, valor novo, origem (1 = manual, 2 = automática, 3 = carga) e auditoria (usuário, código e matrícula de quem incluiu e de quem alterou, datas e horas). Índices `ZHF_FILIAL + ZHF_MAT + ZHF_TIPO + ZHF_SEQ` e `ZHF_FILIAL + ZHF_TIPO + DTOS(ZHF_DATA)`.

**ZHG**: log de auditoria (operação, usuário, data, hora, rotina e detalhe).

**SRA** (aba Adicionais): `RA_XPERPRZ`, `RA_XPERDTI`, `RA_XPERDTF`, `RA_XINSPRZ`, `RA_XINSDTI`, `RA_XINSDTF`.

Parâmetros opcionais (o padrão está no fonte): `MV_ZHFCPOS` = `01=RA_XCODFUN;05=RA_ADCPERI;06=RA_ADCINS;07=RA_XPERELE;10=RA_XOPTICK` e `MV_ZHFDTS` = `05=RA_XPERDTI,RA_XPERDTF,RA_XPERPRZ;06=RA_XINSDTI,RA_XINSDTF,RA_XINSPRZ`.

## Como instalar

1. Backup do banco e dos RPOs; ninguém usando o Cadastro de Funcionários.
2. Compilar os 10 fontes de uma vez.
3. Rodar `U_UPDZHF00` e depois `U_UPDZHF01` (primeiro Simular, depois Executar) por um item de menu temporário do SIGAGPE. O Configurador bloqueia funções de usuário; como Programa Inicial funciona, mas consome uma licença a mais. O aviso "__SetX31Mode será descontinuada" é só informativo.
4. Incluir `CBGPEA21` (Históricos) e `CBGPER20` (Relatório) no menu do SIGAGPE.
5. Rodar a **Carga inicial** (Outras Ações da tela de Históricos) uma vez em cada filial, antes de alterarem cadastros.
