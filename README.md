<div align="center">

<img src="https://upload.wikimedia.org/wikipedia/commons/0/0c/Logotipo_da_Totvs_%282025%29.svg" alt="TOTVS" height="56">
&nbsp;&nbsp;&nbsp;&nbsp;
<img src="assets/advpl.svg" alt="AdvPL" height="56">
&nbsp;
<img src="assets/tlpp.svg" alt="TLPP" height="56">

# Projetos e Fontes em AdvPL / TLPP

**Rotinas, customizações e utilitários para o TOTVS Protheus, desenvolvidos no dia a dia de consultoria.**

![Protheus](https://img.shields.io/badge/Protheus-12.1.2510-0A1F44?style=for-the-badge)
![AdvPL](https://img.shields.io/badge/AdvPL-.prw-00A0DF?style=for-the-badge)
![TLPP](https://img.shields.io/badge/TLPP-.tlpp-00C7B1?style=for-the-badge)
![MVC](https://img.shields.io/badge/MVC-FWFormModel-5C6BC0?style=for-the-badge)
![Encoding](https://img.shields.io/badge/encoding-Windows--1252-6E7781?style=for-the-badge)

[Projetos](#-projetos) · [Fontes avulsos](#-fontes-avulsos) · [Padrões](#-padrões-adotados) · [Como usar](#-como-usar)

</div>

---

## 📦 Projetos

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>👥 <a href="historicos-funcionario/">Históricos do Funcionário</a></h3>
      <p><code>SIGAGPE</code> · <code>MVC</code> · <code>TReport</code> · <code>Compatibilizador</code></p>
      <p>Tabela própria (<b>ZHF</b>) com o histórico de função gratificada, adicionais, licenças, penalidades, auxílios e outros, com Data Inicial/Final e auditoria (<b>ZHG</b>).</p>
      <ul>
        <li>Gravação automática ao salvar o Cadastro, a Gestão de Funcionários e os Dependentes</li>
        <li>Tela MVC, relatório, carga inicial e compatibilizadores de dicionário</li>
        <li>12 fontes</li>
      </ul>
    </td>
    <td width="50%" valign="top">
      <h3>🔐 <a href="importadores/">Importadores do Configurador</a></h3>
      <p><code>SIGACFG</code> · <code>MVC padrão</code> · <code>CSV</code></p>
      <p>Carga em massa de cadastros do Configurador a partir de planilhas CSV, usando os modelos MVC padrão do Protheus.</p>
      <ul>
        <li><b>ZIMPUSR</b>: usuários e grupos</li>
        <li><b>ZIMPPRV</b>: regras de privilégio</li>
      </ul>
    </td>
  </tr>
</table>

> Cada pasta tem um README com a explicação de cada fonte, e todo fonte tem um cabeçalho **Protheus.doc** descrevendo o que faz.

## 🧩 Fontes avulsos

| Fonte | Tipo | O que faz |
|---|---|---|
| [`EREST_02.prw`](EREST_02.prw) | REST (WSRESTFUL) | Serviço `CLIENTES`: `GET /CLIENTES/{CPF}` devolve em JSON os dados do cliente (SA1) daquele CPF, com tipo de pessoa, bloqueio e endereços principal, de cobrança, de entrega e de recebimento. |
| [`F0100110.prw`](F0100110.prw) | MVC (Modelo 1) | Cadastro de Regiões sobre a tabela ZA6: browse, ModelDef e ViewDef. |

## 📐 Padrões adotados

| | |
|---|---|
| **Documentação** | Cabeçalho Protheus.doc em todos os fontes |
| **Nomenclatura** | Notação húngara nas variáveis; nomes de função no padrão do ambiente de cada projeto |
| **Dicionário** | Alterações sempre por compatibilizador, com modo **Simular** antes de gravar |
| **Segurança** | Nenhum fonte contém senha, chave ou dado de cliente |
| **Encoding** | Windows-1252 com CRLF, o único formato aceito pelo compilador do Protheus |

## 🚀 Como usar

1. Baixe o fonte desejado (botão **Raw** ou `git clone`), **sem converter o encoding**.
2. Compile pelo **TOTVS Developer Studio for VS Code** num ambiente de testes.
3. Siga o passo a passo do README da pasta do projeto: compatibilizadores, menu e parâmetros.

> [!NOTE]
> O `.gitattributes` impede o Git de converter os fontes. No GitHub, alguns acentos podem aparecer trocados por causa do Windows-1252, mas o arquivo baixado está correto.

---

<div align="center">
<sub>
Projeto pessoal, sem vínculo oficial com a TOTVS S.A. TOTVS, Protheus, AdvPL e TLPP são marcas dos seus respectivos donos.<br>
Logotipo TOTVS: <a href="https://commons.wikimedia.org/wiki/File:Logotipo_da_Totvs_(2025).svg">Wikimedia Commons</a> (domínio público) ·
Ícones AdvPL/TLPP: <a href="https://github.com/totvs/tds-vscode">totvs/tds-vscode</a> (Apache-2.0)
</sub>
</div>
