#include "totvs.ch"
#include "fwmvcdef.ch"

// Versão do importador: aparece na tela, no resumo da importação e em U_ZIMPUSRV.
// Ao alterar o fonte, suba a versão e registre a mudança em "Novidades" no portal.
#Define ZIMPUSR_VERSAO "2.0.1"

// Cache das consultas (grupos, filiais, menus, regras) durante uma importação
Static oCache := Nil
// Prefixo dos campos do cadastro em processamento: "USR_" (usuários) ou "GR__" (grupos)
Static cPfx   := "USR_"

/*/{Protheus.doc} ZIMPUSR
Importador de usuários e grupos de usuários do Protheus a partir de arquivo CSV.

A gravação usa os modelos MVC padrão do framework (os mesmos do Configurador):
  - MPUSERACCOUNTDATA  -> cadastro do usuário (SYS_USR e tabelas filhas)
  - MPUSERACCOUNTRULES -> vínculo do usuário com regras de privilégio (SYS_RULES_USR_RULES)
Assim senha (hash/salt), checksum, auditoria e validações ficam a cargo do próprio Protheus.

Formato do CSV
  - Primeira linha: cabeçalho com o nome das colunas (ordem livre, maiúsculas/minúsculas indiferente).
  - Separador ";" ou "," (detectado pelo cabeçalho). Campos com separador podem vir entre aspas.
  - Codificação ANSI (Windows-1252) ou UTF-8 (com ou sem BOM).
  - Célula vazia = mantém o padrão do Protheus (inclusão) ou o valor atual (alteração).
  - Colunas de lista usam "|" para separar os itens.

Colunas simples
  OPERACAO          I=Incluir, A=Atualizar (opcional; vazio = automático conforme a ação escolhida)

Ações (tela) / modos (job)
  Incluir novos .................... modo 1: inclui quem não existe; existentes = IGNORADO
  Incluir novos e atualizar ........ modo 2: inclui novos e atualiza existentes
  Atualizar existentes ............. modo 3: atualiza existentes; quem não existe = IGNORADO
  Excluir os do arquivo ............ modo 4: exclui os usuários/grupos listados (só a coluna chave
                                     importa). Protegidos: admin (000000), usuário logado, grupo
                                     Administradores e grupos com usuários vinculados.
                                     Na tela exige digitar EXCLUIR; use Simular antes.
  Na atualização, célula vazia mantém o valor atual: informe só a chave e o que muda.
  LOGIN             Código de login (obrigatório)
  NOME              Nome completo (obrigatório na inclusão)
  EMAIL, DEPARTAMENTO, CARGO, RAMAL
  SENHA             Senha (já preenche a confirmação). Vazia na inclusão = usa a "senha inicial" informada
                    na execução e força a troca no primeiro acesso.
  BLOQUEADO         S/N
  DT_VALIDADE       Data de bloqueio por validade (dd/mm/aaaa, aaaammdd ou aaaa-mm-dd)
  TROCA_SENHA       S/N - força troca de senha no próximo logon
  DIAS_EXPIRA_SENHA Troca periódica da senha a cada N dias
  REGRA_GRUPO       1=Priorizar, 2=Desconsiderar, 3=Somar (padrão 1 quando há GRUPOS)
  ACESSOS_SIMULT    Número de acessos simultâneos
  TIMEOUT           Timeout da estação (minutos)
  NIVEL_LEITURA     Nível global de campos (0 a 9)
  DIGITOS_ANO       2 ou 4
  DIR_IMPRESSAO     Diretório de impressão padrão
  Qualquer campo dos submodelos DATAUSER, RESTRICTION, PROTHEUSDATA, PROTHEUSPRINTER,
  PROTHEUSLOG e PROTHEUSACC também pode ser usado pelo nome (ex.: USR_OIDC, USR_LOGMAIL).

Colunas de lista
  Sem prefixo, a lista substitui o conteúdo atual. Para atualizar só alguns itens use "+" (adiciona)
  e "-" (remove) na frente de cada item: GRUPOS = +0201|-0102 mantém os demais grupos.
  Vale para GRUPOS, FILIAIS, SUPERIORES e PAPEIS. ACESSOS já é incremental (N libera, -N bloqueia).
  GRUPOS        Grupos (perfis) por código (ex.: 0101), ID ou descrição. Sufixo ":1" marca o grupo
                como prioritário. Ex.: 0101|0102:1
                Com GRUPOS preenchido e REGRA_GRUPO vazia, a inclusão usa REGRA_GRUPO = 1 (priorizar
                as regras do grupo), para o usuário herdar módulos, menus, acessos e filiais do grupo.
  SIGAxxx       Uma coluna por módulo (ex.: SIGAFAT, SIGACOM, SIGAFIN). Na célula, o nível de acesso
                (0 a 9; S ou X = nível 5). N = tira o acesso ao módulo. Vazio = não mexe.
                Só os módulos informados mudam; os demais ficam como estão.
  MENU_SIGAxxx  Opcional: menu personalizado do módulo, por nome (SIGAFAT), arquivo (SIGAFAT.XNU)
                ou ID do MPMENU. Vazio = menu padrão. Ex.: coluna MENU_SIGACOM = COMPRAS_VENDEDOR.XNU
  MODULOS       Alternativa em uma só coluna: MODULO:NIVEL[:MENU] separados por "|"
                (ex.: SIGAFAT:5|SIGACOM:3). Lista completa: os módulos fora dela ficam sem acesso.
                "@TODOS" libera todos os módulos com o menu padrão.
  FILIAIS       GRUPO/FILIAL ou só GRUPO (todas as filiais do grupo). "@TODAS" libera todas as empresas.
                Ex.: 99/01|99/02
  ACESSOS       Códigos de acesso (tabela de 200 acessos). Processados em ordem:
                @TODOS, @NENHUM, N ou +N (libera), -N (bloqueia). Ex.: @NENHUM|1|2|36|-37
  PRIVILEGIOS   Regras de privilégio (CFGA530) por ID ou código. Ex.: REGRA_FAT|REGRA_COM
  SUPERIORES    Superiores por login ou ID. Ex.: joao.silva|000005
  HORARIOS      Restrição de horário por dia da semana (1 a 7). Ex.: 2=08:00-18:00|3=08:00-18:00
  PAPEIS        Papéis de trabalho por código. Ex.: 01|02
  VINCULO_FUNC  Vínculo com funcionário: GRUPO/FILIAL/MATRICULA. Ex.: 99/01/000123

IMPORTAÇÃO DE GRUPOS (MPGROUPACCOUNTDATA + MPGROUPACCOUNTRULES)
  CODIGO            Código do grupo (obrigatório; chave para incluir/alterar). Ex.: 0101
  DESCRICAO         Descrição, até 30 caracteres (obrigatória na inclusão). Também aceito: NOME
  BLOQUEADO, DT_VALIDADE, DIAS_EXPIRA_SENHA, TIMEOUT, NIVEL_LEITURA, TODAS_EMPRESAS, DIR_IMPRESSAO
  SIGAxxx / MENU_SIGAxxx / MODULOS, FILIAIS, ACESSOS, HORARIOS, PAPEIS, PRIVILEGIOS: mesmo formato
  das colunas de usuário. Qualquer campo GR__* dos submodelos de formulário também pode ser usado.
  Importe os grupos antes dos usuários: os usuários são vinculados pelo código do grupo.

Execução
  - U_ZIMPUSR  : tela (menu do SIGACFG ou programa inicial). Pergunta se importa Grupos ou Usuários.
                 Exige usuário administrador.
  - U_ZIMPUSRJ : usuários sem interface (job/schedule/teste). Ver documentação da função.
  - U_ZIMPGRPJ : grupos sem interface.

Log: \zimpusr\log\zimpusr_AAAAMMDD_HHMMSS.csv (no RootPath do servidor), também exibido em tela.

Versão: ZIMPUSR_VERSAO (início do fonte). Para conferir a versão compilada no ambiente: U_ZIMPUSRV.

@type  User Function
@author João Victor Guimarães Alves
@since 07/10/2026
/*/
User Function ZIMPUSR()
    Local aPergs  := {}
    Local aResp   := {}
    Local aRet    := {}
    Local cTipo   := ""
    Local cNome   := ""
    Local cArq    := ""
    Local cPswIni := ""
    Local nAcao   := 0
    Local nExec   := 0
    Local nModo   := 0

    If Type("cEmpAnt") != "C" .And. !TelaLogin()
        Return
    EndIf

    If !FWIsAdmin(__cUserId)
        FWAlertError("Somente administradores podem importar usuários e grupos.", "ZIMPUSR")
        Return
    EndIf

    // Tela única. As respostas não são guardadas de propósito: a execução sempre começa
    // em "simular e depois gravar" e ninguém fixa respostas para o grupo de administradores.
    AAdd(aPergs, {2, "Importar", 2, {"1=Grupos de usuários", "2=Usuários"}, 140, ".T.", .T.})
    AAdd(aPergs, {2, "Ação", 3, {"1=Incluir novos (ignora existentes)", "2=Atualizar existentes (ignora novos)", ;
        "3=Incluir novos e atualizar existentes", "4=Excluir os do arquivo", "5=Gerar CSV modelo"}, 140, ".T.", .T.})
    AAdd(aPergs, {6, "Arquivo CSV", Space(250), "", "", "", 140, .F., "Arquivos CSV (*.csv)|*.csv", "\zimpusr\entrada\", GETF_LOCALHARD + GETF_NETWORKDRIVE})
    AAdd(aPergs, {2, "Execução", 1, {"1=Simular e depois gravar (recomendado)", "2=Só simular (não grava)", "3=Gravar direto"}, 140, ".T.", .T.})
    AAdd(aPergs, {8, "Senha inicial (usuários novos sem SENHA no CSV)", Space(50), "", "", "", "", 110, .F.})

    If !ParamBox(aPergs, "Importação de grupos e usuários - ZIMPUSR " + ZIMPUSR_VERSAO, @aResp, , , , , , , , .F., .F.)
        Return
    EndIf

    cTipo   := IIf(ComboNum(aResp[1]) == 1, "G", "U")
    cNome   := IIf(cTipo == "G", "grupos", "usuários")
    nAcao   := ComboNum(aResp[2])
    cArq    := AllTrim(aResp[3])
    nExec   := ComboNum(aResp[4])
    cPswIni := IIf(cTipo == "U", AllTrim(aResp[5]), "")
    // Modo interno: 1 = só incluir, 2 = incluir e atualizar, 3 = só atualizar, 4 = excluir
    nModo   := {1, 3, 2, 4, 0}[nAcao]

    If nAcao == 5
        GeraModelo(cTipo)
        Return
    EndIf

    If Empty(cArq)
        FWAlertWarning("Informe o arquivo CSV.", "ZIMPUSR")
        Return
    EndIf

    cArq := ArqServid(cArq)
    If Empty(cArq)
        Return
    EndIf

    // Simulação (opções 1 e 2). Com erro de arquivo/cabeçalho não há log e não segue.
    If nExec != 3
        aRet := Executa(cTipo, cNome, cArq, nModo, .T., cPswIni)
        If nExec == 2 .Or. Empty(aRet) .Or. Empty(aRet[3])
            Return
        EndIf
        If !aRet[1] .And. !MsgYesNo("A simulação encontrou erros (veja o log)." + CRLF + ;
                "Gravar mesmo assim? As linhas com erro serão ignoradas.", "ZIMPUSR")
            Return
        EndIf
    EndIf

    If !ConfGrava(cNome, cArq, nModo, nExec != 3)
        Return
    EndIf
    Executa(cTipo, cNome, cArq, nModo, .F., cPswIni)
Return

Static Function Executa(cTipo, cNome, cArq, nModo, lSimula, cPswIni)
    Local aRet := {}

    Processa({|| aRet := ZImpProc(cTipo, cArq, nModo, lSimula, cPswIni, .T.)}, ;
        "Importação de " + cNome + IIf(lSimula, " (simulação)", ""), "Processando...", .F.)
    If !Empty(aRet)
        MostraLog(aRet[2], "Resultado da importação de " + cNome + IIf(lSimula, " (SIMULAÇÃO)", ""))
    EndIf
Return aRet

// Confirmação antes de gravar, com o ambiente em destaque (homologação x produção)
Static Function ConfGrava(cNome, cArq, nModo, lSimulou)
    Local cMsg := ""

    If nModo == 4
        Return ConfExcl(cNome)
    EndIf
    cMsg := IIf(lSimulou, "Simulação concluída. ", "") + "Gravar a importação de " + cNome + " agora?" + CRLF + CRLF
    cMsg += "Arquivo: " + cArq + CRLF
    cMsg += "Ambiente: " + GetEnvServer() + CRLF
    cMsg += "Empresa/filial: " + cEmpAnt + " / " + cFilAnt
Return MsgYesNo(cMsg, "ZIMPUSR - confirmar gravação")

/*/{Protheus.doc} ZIMPUSRJ
Importação de usuários sem interface (job, schedule, testes).

Pode ser chamada com o ambiente já aberto (cUser/cPsw ignorados) ou como job do appserver.ini:
    [ONSTART]
    JOBS=ZIMPUSR_JOB
    [ZIMPUSR_JOB]
    Main=U_ZIMPUSRJ
    Environment=protheus
    nParms=8
    Parm1=\zimpusr\entrada\usuarios.csv
    Parm2=admin
    Parm3=<senha do admin>
    Parm4=99
    Parm5=01
    Parm6=1        (1=só incluir novos, 2=incluir e atualizar, 3=só atualizar existentes, 4=excluir)
    Parm7=N        (S=simular)
    Parm8=         (senha inicial para linhas com SENHA vazia; opcional)

@param cArq,    caractere, Caminho do CSV no servidor (a partir do RootPath)
@param cUser,   caractere, Usuário administrador
@param cPsw,    caractere, Senha do usuário
@param cEmp,    caractere, Grupo de empresas (padrão 99)
@param cFil,    caractere, Filial (padrão 01)
@param cModo,   caractere, 1=só incluir novos, 2=incluir e atualizar, 3=só atualizar existentes, 4=excluir (padrão 1)
@param cSimula, caractere, S=somente validar (padrão N)
@param cSenhaPad, caractere, Senha inicial para linhas com SENHA vazia (força troca no 1º acesso)
@return array, {lOk, cResumo, cArqLog}
@type  User Function
@author João Victor Guimarães Alves
/*/
User Function ZIMPUSRJ(cArq, cUser, cPsw, cEmp, cFil, cModo, cSimula, cSenhaPad)
Return RodaJob("U", cArq, cUser, cPsw, cEmp, cFil, cModo, cSimula, cSenhaPad)

/*/{Protheus.doc} ZIMPGRPJ
Importação de grupos sem interface. Mesmos parâmetros da U_ZIMPUSRJ, sem a senha inicial.
    [ZIMPGRP_JOB]
    Main=U_ZIMPGRPJ
    Environment=protheus
    nParms=7
    Parm1=\zimpusr\entrada\grupos.csv
    ...
@type  User Function
@author João Victor Guimarães Alves
/*/
User Function ZIMPGRPJ(cArq, cUser, cPsw, cEmp, cFil, cModo, cSimula)
Return RodaJob("G", cArq, cUser, cPsw, cEmp, cFil, cModo, cSimula, "")

/*/{Protheus.doc} ZIMPUSRV
Mostra (ou devolve, em job) a versão do ZIMPUSR compilada no ambiente.
Útil para conferir se o RPO do cliente tem a versão que o portal espera.
@return caractere, versão no formato N.N.N
@type  User Function
@author João Victor Guimarães Alves
/*/
User Function ZIMPUSRV()
    If Type("oMainWnd") == "O"
        FWAlertInfo("ZIMPUSR versão " + ZIMPUSR_VERSAO, "ZIMPUSR")
    Else
        ConOut("ZIMPUSR versão " + ZIMPUSR_VERSAO)
    EndIf
Return ZIMPUSR_VERSAO

Static Function RodaJob(cTipo, cArq, cUser, cPsw, cEmp, cFil, cModo, cSimula, cSenhaPad)
    Local lAbriu := .F.
    Local aRet   := {.F., "", ""}

    Default cArq      := ""
    Default cUser     := ""
    Default cPsw      := ""
    Default cEmp      := "99"
    Default cFil      := "01"
    Default cModo     := "1"
    Default cSimula   := "N"
    Default cSenhaPad := ""

    If Type("cEmpAnt") != "C"
        RpcSetType(3)
        If !RpcSetEnv(cEmp, cFil, cUser, cPsw, "CFG", "ZIMPUSRJ")
            ConOut("ZIMPUSR " + ZIMPUSR_VERSAO + ": falha ao abrir o ambiente " + cEmp + "/" + cFil + " com o usuário " + cUser)
            Return aRet
        EndIf
        lAbriu := .T.
    EndIf

    If !FWIsAdmin(__cUserId)
        ConOut("ZIMPUSR: o usuário " + cUser + " não é administrador.")
    Else
        aRet := ZImpProc(cTipo, cArq, Val(cModo), AScan({"S", "SIM", "1"}, Upper(AllTrim(cSimula))) > 0, AllTrim(cSenhaPad), .F.)
        ConOut("ZIMPUSR " + ZIMPUSR_VERSAO + ": " + aRet[2])
    EndIf

    If lAbriu
        RpcClearEnv()
    EndIf
Return aRet

/*/{Protheus.doc} ZImpProc
Processa o arquivo: lê, mapeia colunas, confere logins repetidos e grava linha a linha.
O log é gravado a cada linha, então uma importação interrompida pode ser retomada
rodando de novo com "ignorar existentes".
@return array, {lOk, cTextoLog, cArqLog}
/*/
Static Function ZImpProc(cTipo, cArq, nModo, lSimula, cSenhaPad, lTela)
    Local aLinhas := {}
    Local aHead   := {}
    Local aMap    := {}
    Local aAvisos := {}
    Local aCampos := {}
    Local aRes    := {}
    Local aErros  := {}
    Local oLogins := JsonObject():New()
    Local oModel  := Nil
    Local cSep    := ";"
    Local cTexto  := ""
    Local cArqLog := ""
    Local cLogin  := ""
    Local nLog    := -1
    Local nI      := 0
    Local nOk     := 0
    Local nErro   := 0
    Local nIgn    := 0
    Local nTotal  := 0
    Local nIni    := Seconds()
    Local nTempo  := 0
    Local cChave  := IIf(cTipo == "G", "GR__CODIGO", "USR_CODIGO")
    Local cNomeCh := IIf(cTipo == "G", "CODIGO", "LOGIN")

    If !File(cArq)
        Return {.F., "Arquivo não encontrado no servidor: " + cArq, ""}
    EndIf

    aLinhas := LerCsv(cArq)
    If Len(aLinhas) < 2
        Return {.F., "Arquivo sem cabeçalho ou sem linhas de dados: " + cArq, ""}
    EndIf

    // Separador: o que aparecer no cabeçalho (";" tem preferência)
    If At(";", aLinhas[1]) == 0 .And. At(",", aLinhas[1]) > 0
        cSep := ","
    EndIf

    oCache := JsonObject():New()
    cPfx   := IIf(cTipo == "G", "GR__", "USR_")
    oModel := FWLoadModel(IIf(cTipo == "G", "MPGROUPACCOUNTDATA", "MPUSERACCOUNTDATA"))
    aHead  := SplitCsv(aLinhas[1], cSep)
    aMap   := MapColunas(aHead, oModel, @aAvisos, cTipo)

    If AScan(aMap, {|x| x[4] == cChave}) == 0
        oModel:Destroy()
        Return {.F., "O cabeçalho precisa ter a coluna " + cNomeCh + " (ou " + cChave + ").", ""}
    EndIf
    If cTipo == "G"
        AbreGrp()
    EndIf

    nLog    := LogAbre(@cArqLog, cTipo)
    For nI := 1 To Len(aAvisos)
        LogLinha(nLog, {0, "", "", "AVISO", aAvisos[nI]})
    Next nI

    If lTela
        ProcRegua(Len(aLinhas) - 1)
    EndIf

    For nI := 2 To Len(aLinhas)
        If Empty(StrTran(StrTran(aLinhas[nI], cSep, ""), '"', ""))
            Loop
        EndIf
        nTotal++
        aCampos := SplitCsv(aLinhas[nI], cSep)
        If lTela
            IncProc("Linha " + cValToChar(nI) + " de " + cValToChar(Len(aLinhas)) + ;
                " | ok " + cValToChar(nOk) + " | erros " + cValToChar(nErro))
        EndIf

        // Chave repetida no próprio arquivo: só a primeira ocorrência é processada
        cLogin := Upper(AllTrim(ValorCol(aMap, aCampos, cChave)))
        If !Empty(cLogin) .And. oLogins:HasProperty(cLogin)
            aRes := {cLogin, "-", "ERRO", cNomeCh + " repetido no arquivo (primeira ocorrência na linha " + cValToChar(oLogins[cLogin]) + ")."}
        Else
            If !Empty(cLogin)
                oLogins[cLogin] := nI
            EndIf
            If cTipo == "G"
                aRes := GravaGrp(oModel, aMap, aCampos, nModo, lSimula)
            Else
                aRes := GravaUsr(oModel, aMap, aCampos, nModo, lSimula, cSenhaPad)
            EndIf
        EndIf

        LogLinha(nLog, {nI, aRes[1], aRes[2], aRes[3], aRes[4]})
        Do Case
            Case AScan({"INCLUIDO", "ALTERADO", "VALIDADO", "EXCLUIDO"}, aRes[3]) > 0
                nOk++
            Case aRes[3] == "IGNORADO"
                nIgn++
            Otherwise
                nErro++
                AAdd(aErros, "Linha " + StrZero(nI, 5) + " | " + PadR(aRes[1], 25) + " | " + PadR(aRes[3], 8) + " | " + aRes[4])
        EndCase
    Next nI

    oModel:Destroy()
    FClose(nLog)
    FreeObj(oLogins)
    FreeObj(oCache)
    oCache := Nil
    cPfx   := "USR_"

    nTempo := Seconds() - nIni
    If nTempo < 0
        nTempo += 86400   // virou a meia-noite
    EndIf

    cTexto := "Importação de " + IIf(cTipo == "G", "GRUPOS", "USUÁRIOS") + " - ZIMPUSR " + ZIMPUSR_VERSAO + CRLF
    cTexto += "Arquivo: " + cArq + CRLF
    cTexto += "Modo: " + {"incluir novos", "incluir novos e atualizar existentes", "atualizar existentes", "EXCLUIR"}[Max(1, Min(nModo, 4))] + IIf(lSimula, " | SIMULAÇÃO (nada foi gravado)", "") + CRLF
    cTexto += "Linhas: " + cValToChar(nTotal) + " | Sucesso: " + cValToChar(nOk) + " | Erros: " + cValToChar(nErro) + ;
        " | Ignorados: " + cValToChar(nIgn) + CRLF
    cTexto += "Tempo: " + FormTempo(nTempo) + IIf(nTotal > 0, " (média " + AllTrim(Str(nTempo / nTotal, 10, 2)) + " s por linha)", "") + CRLF
    cTexto += "Log completo: " + cArqLog + CRLF + CRLF
    For nI := 1 To Len(aAvisos)
        cTexto += "AVISO: " + aAvisos[nI] + CRLF
    Next nI
    If !Empty(aErros)
        cTexto += CRLF + "ERROS" + IIf(Len(aErros) > 500, " (primeiros 500; veja o log completo)", "") + ":" + CRLF
        For nI := 1 To Min(Len(aErros), 500)
            cTexto += aErros[nI] + CRLF
        Next nI
    EndIf
Return {nErro == 0, cTexto, cArqLog}

Static Function FormTempo(nSeg)
Return StrZero(Int(nSeg / 3600), 2) + ":" + StrZero(Int(Mod(nSeg, 3600) / 60), 2) + ":" + StrZero(Int(Mod(nSeg, 60)), 2)

/*/{Protheus.doc} GravaUsr
Inclui/altera um usuário a partir de uma linha do CSV.
@return array, {cLogin, cOperacao, cStatus, cMensagem}
/*/
Static Function GravaUsr(oModel, aMap, aCampos, nModo, lSimula, cSenhaPad)
    Local cLogin  := AllTrim(ValorCol(aMap, aCampos, "USR_CODIGO"))
    Local cOper   := Upper(Left(ValorCol(aMap, aCampos, "OPERACAO"), 1))
    Local cUsrId  := ""
    Local cMsg    := ""
    Local cValor  := ""
    Local nOper   := 0
    Local nI      := 0
    Local lOk     := .T.
    Local bErro   := Nil
    Local aRegras := {}
    Local lRepl   := .F.

    If Empty(cLogin)
        Return {"", "", "ERRO", "LOGIN não informado."}
    EndIf
    If nModo == 4
        Return ExcluiUsr(oModel, cLogin, lSimula)
    EndIf

    cUsrId := BuscaUsr(cLogin)

    Do Case
        Case cOper == "A" .And. Empty(cUsrId)
            Return {cLogin, "A", "ERRO", "Usuário não existe para alteração."}
        Case cOper == "I" .And. !Empty(cUsrId)
            Return {cLogin, "I", "ERRO", "Usuário já existe (ID " + cUsrId + ")."}
        Case Empty(cUsrId) .And. nModo == 3 .And. cOper != "I"
            Return {cLogin, "-", "IGNORADO", "Usuário não existe (modo só atualizar)."}
        Case Empty(cUsrId)
            nOper := MODEL_OPERATION_INSERT
        Case cOper == "A" .Or. nModo >= 2
            nOper := MODEL_OPERATION_UPDATE
        Otherwise
            Return {cLogin, "-", "IGNORADO", "Usuário já existe (ID " + cUsrId + ")."}
    EndCase
    cOper := IIf(nOper == MODEL_OPERATION_INSERT, "I", "A")

    // Privilégios são gravados em outro modelo; valida as regras antes de mexer no usuário
    cValor := ValorCol(aMap, aCampos, "PRIVILEGIOS")
    If !Empty(cValor)
        aRegras := ResRegras(cValor, @cMsg)
        If !Empty(cMsg)
            Return {cLogin, cOper, "ERRO", cMsg}
        EndIf
    EndIf

    // O modelo de usuários carrega o registro indicado no Cargo {recno, id, lFlag}.
    // Sem isso ele carrega o usuário logado (posicionar MPUSR_USR não tem efeito).
    oModel:Cargo := {0, "", .F.}
    If nOper == MODEL_OPERATION_UPDATE
        MPUSR_USR->(DbSetOrder(1))
        If !MPUSR_USR->(DbSeek(cUsrId))
            Return {cLogin, cOper, "ERRO", "Não foi possível posicionar o usuário " + cUsrId + "."}
        EndIf
        oModel:Cargo := {MPUSR_USR->(RecNo()), cUsrId, .F.}
    EndIf

    oModel:SetOperation(nOper)
    If !oModel:Activate()
        Return {cLogin, cOper, "ERRO", "Falha ao ativar o modelo: " + ErroModelo(oModel)}
    EndIf

    // Trava de segurança: nunca alterar um usuário diferente do esperado
    If nOper == MODEL_OPERATION_UPDATE .And. ;
            (oModel:GetValue("DATAUSER", "USR_ID") != cUsrId .Or. ;
            Upper(AllTrim(oModel:GetValue("DATAUSER", "USR_CODIGO"))) != Upper(cLogin))
        cMsg := "Modelo carregou o usuário " + oModel:GetValue("DATAUSER", "USR_ID") + " em vez de " + cUsrId + ". Nada foi gravado."
        oModel:DeActivate()
        Return {cLogin, cOper, "ERRO", cMsg}
    EndIf

    bErro := ErrorBlock({|e| cMsg := "Erro de execução: " + ErrDesc(e), Break(e)})
    Begin Sequence
        If nOper == MODEL_OPERATION_INSERT
            lOk := SetCampo(oModel, "DATAUSER", "USR_CODIGO", cLogin, @cMsg)
        EndIf

        // Colunas simples (campos dos submodelos de formulário)
        For nI := 1 To Len(aMap)
            If !lOk
                Exit
            EndIf
            If aMap[nI][2] == "F" .And. aMap[nI][4] != "USR_CODIGO"
                cValor := ColValor(aCampos, aMap[nI][1])
                If !Empty(cValor)
                    lOk := SetCampo(oModel, aMap[nI][3], aMap[nI][4], cValor, @cMsg)
                EndIf
            EndIf
        Next nI

        // Senha + confirmação. Na inclusão sem SENHA usa a senha inicial e força a troca no 1º acesso
        cValor := ValorCol(aMap, aCampos, "SENHA")
        If lOk .And. !Empty(cValor)
            lOk := SetCampo(oModel, "DATAUSER", "USR_PSW", cValor, @cMsg) .And. ;
                SetCampo(oModel, "DATAUSER", "USR_PSWCMP", cValor, @cMsg)
        ElseIf lOk .And. nOper == MODEL_OPERATION_INSERT .And. !Empty(cSenhaPad)
            lOk := SetCampo(oModel, "DATAUSER", "USR_PSW", cSenhaPad, @cMsg) .And. ;
                SetCampo(oModel, "DATAUSER", "USR_PSWCMP", cSenhaPad, @cMsg)
            If lOk .And. Empty(ValorCol(aMap, aCampos, "USR_CHGPSW"))
                lOk := SetCampo(oModel, "DATAUSER", "USR_CHGPSW", "S", @cMsg)
            EndIf
        ElseIf lOk .And. nOper == MODEL_OPERATION_INSERT
            lOk  := .F.
            cMsg := "SENHA é obrigatória na inclusão (ou informe a senha inicial padrão)."
        EndIf

        // Com grupo informado e sem REGRA_GRUPO, prioriza as regras do grupo (o padrão do sistema é desconsiderar)
        If lOk .And. nOper == MODEL_OPERATION_INSERT .And. !Empty(ValorCol(aMap, aCampos, "GRUPOS")) .And. ;
                Empty(ValorCol(aMap, aCampos, "USR_GRPRULE"))
            lOk := SetCampo(oModel, "DATAUSER", "USR_GRPRULE", "1", @cMsg)
        EndIf

        // Colunas de lista (grids)
        lOk := lOk .And. AplicaLst(oModel, aMap, aCampos, "GRUPOS", @cMsg)
        If lOk
            cValor := MontaMods(aMap, aCampos, @cMsg, @lRepl)
            lOk := Empty(cMsg)
            If lOk .And. !Empty(cValor)
                lOk := GrdModulos(oModel, cValor, @cMsg, lRepl)
            EndIf
            If !lOk
                cMsg := "MODULOS: " + cMsg
            EndIf
        EndIf
        lOk := lOk .And. AplicaLst(oModel, aMap, aCampos, "FILIAIS", @cMsg)
        lOk := lOk .And. AplicaLst(oModel, aMap, aCampos, "ACESSOS", @cMsg)
        lOk := lOk .And. AplicaLst(oModel, aMap, aCampos, "SUPERIORES", @cMsg)
        lOk := lOk .And. AplicaLst(oModel, aMap, aCampos, "HORARIOS", @cMsg)
        lOk := lOk .And. AplicaLst(oModel, aMap, aCampos, "PAPEIS", @cMsg)
        lOk := lOk .And. AplicaLst(oModel, aMap, aCampos, "VINCULO_FUNC", @cMsg)

        If lOk
            lOk := oModel:VldData()
            If !lOk
                cMsg := ErroModelo(oModel)
            EndIf
        EndIf

        If lOk .And. !lSimula
            lOk := oModel:CommitData()
            If !lOk
                cMsg := ErroModelo(oModel)
            EndIf
        EndIf

        If lOk
            cUsrId := oModel:GetValue("DATAUSER", "USR_ID")
        EndIf
    Recover
        lOk := .F.
    End Sequence
    ErrorBlock(bErro)

    oModel:DeActivate()

    If !lOk
        Return {cLogin, cOper, "ERRO", cMsg}
    EndIf

    If lSimula
        Return {cLogin, cOper, "VALIDADO", "Dados válidos (simulação, nada gravado)."}
    EndIf

    cMsg := "ID " + cUsrId
    If !Empty(aRegras)
        If GravaRegra("U", cUsrId, aRegras, @cValor)
            cMsg += " | privilégios: " + cValToChar(Len(aRegras))
        Else
            Return {cLogin, cOper, "PARCIAL", cMsg + " gravado, mas falhou ao vincular privilégios: " + cValor}
        EndIf
    EndIf
Return {cLogin, cOper, IIf(cOper == "I", "INCLUIDO", "ALTERADO"), cMsg}

/*/{Protheus.doc} GravaGrp
Inclui/altera um grupo de usuários a partir de uma linha do CSV.
@return array, {cCodigo, cOperacao, cStatus, cMensagem}
/*/
Static Function GravaGrp(oModel, aMap, aCampos, nModo, lSimula)
    Local cCod    := AllTrim(ValorCol(aMap, aCampos, "GR__CODIGO"))
    Local cOper   := Upper(Left(ValorCol(aMap, aCampos, "OPERACAO"), 1))
    Local aAtual  := {}
    Local cGrpId  := ""
    Local cMsg    := ""
    Local cValor  := ""
    Local nOper   := 0
    Local nI      := 0
    Local lOk     := .T.
    Local bErro   := Nil
    Local aRegras := {}
    Local lRepl   := .F.

    If Empty(cCod)
        Return {"", "", "ERRO", "CODIGO do grupo não informado."}
    EndIf
    If nModo == 4
        Return ExcluiGrp(oModel, cCod, lSimula)
    EndIf

    // {ID, RECNO} do grupo com esse código
    aAtual := QryLinha("SELECT GR__ID, R_E_C_N_O_ FROM SYS_GRP_GROUP WHERE D_E_L_E_T_ = ' ' AND UPPER(RTRIM(GR__CODIGO)) = '" + ;
        SqlStr(Upper(cCod)) + "'")
    If !Empty(aAtual)
        cGrpId := aAtual[1]
    EndIf

    Do Case
        Case cOper == "A" .And. Empty(cGrpId)
            Return {cCod, "A", "ERRO", "Grupo não existe para alteração."}
        Case cOper == "I" .And. !Empty(cGrpId)
            Return {cCod, "I", "ERRO", "Grupo já existe (ID " + cGrpId + ")."}
        Case Empty(cGrpId) .And. nModo == 3 .And. cOper != "I"
            Return {cCod, "-", "IGNORADO", "Grupo não existe (modo só atualizar)."}
        Case Empty(cGrpId)
            nOper := MODEL_OPERATION_INSERT
        Case cOper == "A" .Or. nModo >= 2
            nOper := MODEL_OPERATION_UPDATE
        Otherwise
            Return {cCod, "-", "IGNORADO", "Grupo já existe (ID " + cGrpId + ")."}
    EndCase
    cOper := IIf(nOper == MODEL_OPERATION_INSERT, "I", "A")

    cValor := ValorCol(aMap, aCampos, "PRIVILEGIOS")
    If !Empty(cValor)
        aRegras := ResRegras(cValor, @cMsg)
        If !Empty(cMsg)
            Return {cCod, cOper, "ERRO", cMsg}
        EndIf
    EndIf

    // O modelo de grupos carrega o registro indicado no Cargo {recno, id, lFlag},
    // com a tabela MPGRP_GROUP aberta e posicionada.
    oModel:Cargo := {0, "", .F.}
    If nOper == MODEL_OPERATION_UPDATE
        MPGRP_GROUP->(DbGoTo(Val(aAtual[2])))
        If MPGRP_GROUP->(Eof()) .Or. MPGRP_GROUP->GR__ID != cGrpId
            Return {cCod, cOper, "ERRO", "Não foi possível posicionar o grupo " + cGrpId + "."}
        EndIf
        oModel:Cargo := {Val(aAtual[2]), cGrpId, .F.}
    EndIf

    oModel:SetOperation(nOper)
    If !oModel:Activate()
        Return {cCod, cOper, "ERRO", "Falha ao ativar o modelo: " + ErroModelo(oModel)}
    EndIf

    // Trava de segurança: nunca alterar um grupo diferente do esperado
    If nOper == MODEL_OPERATION_UPDATE .And. ;
            (oModel:GetValue("DATAGROUP", "GR__ID") != cGrpId .Or. ;
            Upper(AllTrim(oModel:GetValue("DATAGROUP", "GR__CODIGO"))) != Upper(cCod))
        cMsg := "Modelo carregou o grupo " + oModel:GetValue("DATAGROUP", "GR__ID") + " em vez de " + cGrpId + ". Nada foi gravado."
        oModel:DeActivate()
        Return {cCod, cOper, "ERRO", cMsg}
    EndIf

    bErro := ErrorBlock({|e| cMsg := "Erro de execução: " + ErrDesc(e), Break(e)})
    Begin Sequence
        If nOper == MODEL_OPERATION_INSERT
            lOk := SetCampo(oModel, "DATAGROUP", "GR__CODIGO", cCod, @cMsg)
        EndIf

        For nI := 1 To Len(aMap)
            If !lOk
                Exit
            EndIf
            If aMap[nI][2] == "F" .And. aMap[nI][4] != "GR__CODIGO"
                cValor := ColValor(aCampos, aMap[nI][1])
                If !Empty(cValor)
                    lOk := SetCampo(oModel, aMap[nI][3], aMap[nI][4], cValor, @cMsg)
                EndIf
            EndIf
        Next nI

        If lOk
            cValor := MontaMods(aMap, aCampos, @cMsg, @lRepl)
            lOk := Empty(cMsg)
            If lOk .And. !Empty(cValor)
                lOk := GrdModulos(oModel, cValor, @cMsg, lRepl)
            EndIf
            If !lOk
                cMsg := "MODULOS: " + cMsg
            EndIf
        EndIf
        lOk := lOk .And. AplicaLst(oModel, aMap, aCampos, "FILIAIS", @cMsg)
        lOk := lOk .And. AplicaLst(oModel, aMap, aCampos, "ACESSOS", @cMsg)
        lOk := lOk .And. AplicaLst(oModel, aMap, aCampos, "HORARIOS", @cMsg)
        lOk := lOk .And. AplicaLst(oModel, aMap, aCampos, "PAPEIS", @cMsg)

        If lOk
            lOk := oModel:VldData()
            If !lOk
                cMsg := ErroModelo(oModel)
            EndIf
        EndIf

        If lOk .And. !lSimula
            lOk := oModel:CommitData()
            If !lOk
                cMsg := ErroModelo(oModel)
            EndIf
        EndIf

        If lOk
            cGrpId := oModel:GetValue("DATAGROUP", "GR__ID")
        EndIf
    Recover
        lOk := .F.
    End Sequence
    ErrorBlock(bErro)

    oModel:DeActivate()

    If !lOk
        Return {cCod, cOper, "ERRO", cMsg}
    EndIf

    If lSimula
        Return {cCod, cOper, "VALIDADO", "Dados válidos (simulação, nada gravado)."}
    EndIf

    // Grupo novo passa a ser encontrado pelos usuários importados na mesma sessão
    If oCache != Nil
        oCache["GRP|" + Upper(cCod)] := cGrpId
    EndIf

    cMsg := "ID " + cGrpId
    If !Empty(aRegras)
        If GravaRegra("G", cGrpId, aRegras, @cValor)
            cMsg += " | privilégios: " + cValToChar(Len(aRegras))
        Else
            Return {cCod, cOper, "PARCIAL", cMsg + " gravado, mas falhou ao vincular privilégios: " + cValor}
        EndIf
    EndIf
Return {cCod, cOper, IIf(cOper == "I", "INCLUIDO", "ALTERADO"), cMsg}

/*/{Protheus.doc} ExcluiUsr
Exclui um usuário pelo modelo padrão. Nunca exclui o administrador (000000) nem o usuário logado.
/*/
Static Function ExcluiUsr(oModel, cLogin, lSimula)
    Local aUsr  := QryLinha("SELECT USR_ID, R_E_C_N_O_, USR_NOME, USR_EMAIL FROM SYS_USR WHERE D_E_L_E_T_ = ' ' AND UPPER(RTRIM(USR_CODIGO)) = '" + ;
        SqlStr(Upper(cLogin)) + "'")
    Local cMsg  := ""
    Local lOk   := .T.
    Local bErro := Nil

    If Empty(aUsr)
        Return {cLogin, "E", "IGNORADO", "Usuário não existe."}
    EndIf
    If aUsr[1] == "000000" .Or. Upper(cLogin) == "ADMIN"
        Return {cLogin, "E", "ERRO", "Usuário administrador é protegido e não pode ser excluído."}
    EndIf
    If aUsr[1] == __cUserId
        Return {cLogin, "E", "ERRO", "Não é possível excluir o usuário que está executando a rotina."}
    EndIf

    MPUSR_USR->(DbGoTo(Val(aUsr[2])))
    If MPUSR_USR->(Eof()) .Or. MPUSR_USR->USR_ID != aUsr[1]
        Return {cLogin, "E", "ERRO", "Não foi possível posicionar o usuário " + aUsr[1] + "."}
    EndIf
    oModel:Cargo := {Val(aUsr[2]), aUsr[1], .F.}
    oModel:SetOperation(MODEL_OPERATION_DELETE)
    If !oModel:Activate()
        Return {cLogin, "E", "ERRO", "Falha ao ativar o modelo: " + ErroModelo(oModel)}
    EndIf

    // Trava de segurança: nunca excluir um usuário diferente do esperado
    If oModel:GetValue("DATAUSER", "USR_ID") != aUsr[1] .Or. ;
            Upper(AllTrim(oModel:GetValue("DATAUSER", "USR_CODIGO"))) != Upper(cLogin)
        cMsg := "Modelo carregou o usuário " + oModel:GetValue("DATAUSER", "USR_ID") + " em vez de " + aUsr[1] + ". Nada foi excluído."
        oModel:DeActivate()
        Return {cLogin, "E", "ERRO", cMsg}
    EndIf

    bErro := ErrorBlock({|e| cMsg := "Erro de execução: " + ErrDesc(e), Break(e)})
    Begin Sequence
        lOk := oModel:VldData()
        If lOk .And. !lSimula
            lOk := oModel:CommitData()
        EndIf
        If !lOk
            cMsg := ErroModelo(oModel)
        EndIf
    Recover
        lOk := .F.
    End Sequence
    ErrorBlock(bErro)
    oModel:DeActivate()

    If !lOk
        Return {cLogin, "E", "ERRO", cMsg}
    EndIf
    cMsg := "ID " + aUsr[1] + " | " + aUsr[3] + " | " + aUsr[4]
Return {cLogin, "E", IIf(lSimula, "VALIDADO", "EXCLUIDO"), IIf(lSimula, "Seria excluído: ", "") + cMsg}

/*/{Protheus.doc} ExcluiGrp
Exclui um grupo pelo modelo padrão. Nunca exclui o grupo Administradores (000000) nem grupo
com usuários vinculados.
/*/
Static Function ExcluiGrp(oModel, cCod, lSimula)
    Local aGrp  := QryLinha("SELECT GR__ID, R_E_C_N_O_, GR__NOME FROM SYS_GRP_GROUP WHERE D_E_L_E_T_ = ' ' AND UPPER(RTRIM(GR__CODIGO)) = '" + ;
        SqlStr(Upper(cCod)) + "'")
    Local cQtd  := ""
    Local cMsg  := ""
    Local lOk   := .T.
    Local bErro := Nil

    If Empty(aGrp)
        Return {cCod, "E", "IGNORADO", "Grupo não existe."}
    EndIf
    If aGrp[1] == "000000"
        Return {cCod, "E", "ERRO", "Grupo Administradores é protegido e não pode ser excluído."}
    EndIf

    cQtd := QryValor("SELECT COUNT(*) FROM SYS_USR_GROUPS G INNER JOIN SYS_USR U ON U.USR_ID = G.USR_ID AND U.D_E_L_E_T_ = ' ' " + ;
        "WHERE G.D_E_L_E_T_ = ' ' AND G.USR_GRUPO = '" + aGrp[1] + "'")
    If Val(cQtd) > 0
        Return {cCod, "E", "ERRO", "Grupo tem " + cQtd + " usuário(s) vinculado(s). Exclua os usuários ou tire-os do grupo antes."}
    EndIf

    MPGRP_GROUP->(DbGoTo(Val(aGrp[2])))
    If MPGRP_GROUP->(Eof()) .Or. MPGRP_GROUP->GR__ID != aGrp[1]
        Return {cCod, "E", "ERRO", "Não foi possível posicionar o grupo " + aGrp[1] + "."}
    EndIf
    oModel:Cargo := {Val(aGrp[2]), aGrp[1], .F.}
    oModel:SetOperation(MODEL_OPERATION_DELETE)
    If !oModel:Activate()
        Return {cCod, "E", "ERRO", "Falha ao ativar o modelo: " + ErroModelo(oModel)}
    EndIf

    If oModel:GetValue("DATAGROUP", "GR__ID") != aGrp[1] .Or. ;
            Upper(AllTrim(oModel:GetValue("DATAGROUP", "GR__CODIGO"))) != Upper(cCod)
        cMsg := "Modelo carregou o grupo " + oModel:GetValue("DATAGROUP", "GR__ID") + " em vez de " + aGrp[1] + ". Nada foi excluído."
        oModel:DeActivate()
        Return {cCod, "E", "ERRO", cMsg}
    EndIf

    bErro := ErrorBlock({|e| cMsg := "Erro de execução: " + ErrDesc(e), Break(e)})
    Begin Sequence
        lOk := oModel:VldData()
        If lOk .And. !lSimula
            lOk := oModel:CommitData()
        EndIf
        If !lOk
            cMsg := ErroModelo(oModel)
        EndIf
    Recover
        lOk := .F.
    End Sequence
    ErrorBlock(bErro)
    oModel:DeActivate()

    If !lOk
        Return {cCod, "E", "ERRO", cMsg}
    EndIf
    If oCache != Nil .And. oCache:HasProperty("GRP|" + Upper(cCod))
        oCache["GRP|" + Upper(cCod)] := ""
    EndIf
    cMsg := "ID " + aGrp[1] + " | " + aGrp[3]
Return {cCod, "E", IIf(lSimula, "VALIDADO", "EXCLUIDO"), IIf(lSimula, "Seria excluído: ", "") + cMsg}

// Abre a tabela de grupos com os índices do banco (o modelo de grupos precisa dela posicionada)
Static Function AbreGrp()
    If Select("MPGRP_GROUP") == 0
        DbUseArea(.T., "TOPCONN", "SYS_GRP_GROUP", "MPGRP_GROUP", .T., .F.)
        DbSetIndex("SYS_GRP_GROUP1")
        DbSetIndex("SYS_GRP_GROUP2")
        DbSetIndex("SYS_GRP_GROUP3")
        DbSetOrder(1)
    EndIf
Return

/*/{Protheus.doc} AplicaLst
Executa o tratamento de uma coluna de lista se ela existir e estiver preenchida.
/*/
Static Function AplicaLst(oModel, aMap, aCampos, cColuna, cMsg)
    Local cValor := ValorCol(aMap, aCampos, cColuna)
    Local lOk    := .T.

    If Empty(cValor)
        Return .T.
    EndIf

    Do Case
        Case cColuna == "GRUPOS"
            lOk := GrdGrupos(oModel, cValor, @cMsg)
        Case cColuna == "FILIAIS"
            lOk := GrdFiliais(oModel, cValor, @cMsg)
        Case cColuna == "ACESSOS"
            lOk := GrdAcessos(oModel, cValor, @cMsg)
        Case cColuna == "SUPERIORES"
            lOk := GrdSuperio(oModel, cValor, @cMsg)
        Case cColuna == "HORARIOS"
            lOk := GrdHorario(oModel, cValor, @cMsg)
        Case cColuna == "PAPEIS"
            lOk := GrdPapeis(oModel, cValor, @cMsg)
        Case cColuna == "VINCULO_FUNC"
            lOk := SetVincFun(oModel, cValor, @cMsg)
    EndCase

    If !lOk
        cMsg := cColuna + ": " + cMsg
    EndIf
Return lOk

// ---------------------------------------------------------------------------
// Grids
// ---------------------------------------------------------------------------

Static Function GrdGrupos(oModel, cValor, cMsg)
    Local oGrid  := SubModelo(oModel, "DATAGROUP", @cMsg)
    Local aItens := Tokens(cValor)
    Local aIds   := {}
    Local aPrior := {}
    Local cTok   := ""
    Local cId    := ""
    Local nI     := 0

    Local aOps   := {}
    Local lInc   := SepInc(aItens, @aOps)

    If oGrid == Nil
        Return .F.
    EndIf

    For nI := 1 To Len(aItens)
        cTok := aItens[nI]
        AAdd(aPrior, IIf(Right(cTok, 2) == ":1", "1", "2"))
        If ":" $ cTok
            cTok := Left(cTok, At(":", cTok) - 1)
        EndIf
        cId := BuscaGrupo(cTok, @cMsg)
        If Empty(cId)
            If Empty(cMsg)
                cMsg := "grupo não encontrado: " + cTok
            EndIf
            Return .F.
        EndIf
        AAdd(aIds, cId)
    Next nI

    If !AplicaIds(oGrid, "USR_GRUPO", aIds, aOps, lInc, @cMsg)
        Return .F.
    EndIf
    For nI := 1 To Len(aIds)
        If aOps[nI] == "+" .And. oGrid:SeekLine({{"USR_GRUPO", aIds[nI]}}) .And. ;
                !GridSet(oGrid, "USR_PRIORIZA", aPrior[nI], @cMsg)
            Return .F.
        EndIf
    Next nI
Return .T.

// lRepl = .T. (coluna MODULOS): a lista substitui os módulos atuais; senão só os módulos informados mudam
Static Function GrdModulos(oModel, cValor, cMsg, lRepl)
    Local oGrid  := SubModelo(oModel, "PROTHEUSMENU", @cMsg)
    Local aItens := Tokens(cValor)
    Local aPartes := {}
    Local aDef   := {}
    Local lTodos := .F.
    Local cMod   := ""
    Local cMenu  := ""
    Local nNivel := 0
    Local nPos   := 0
    Local nI     := 0
    Local nJ     := 0

    If oGrid == Nil
        Return .F.
    EndIf

    // aDef: {nModulo, cSigla, nNivel, cMenu}
    For nI := 1 To Len(aItens)
        If Upper(aItens[nI]) == "@TODOS"
            lTodos := .T.
            Loop
        EndIf
        aPartes := StrTokArr2(aItens[nI], ":", .T.)
        cMod    := Upper(AllTrim(aPartes[1]))
        nNivel  := IIf(Len(aPartes) >= 2 .And. !Empty(aPartes[2]), Val(aPartes[2]), 5)
        If Len(aPartes) >= 2 .And. Upper(AllTrim(aPartes[2])) == "N"
            nNivel := -1   // tirar o acesso ao módulo
        EndIf
        cMenu   := ""
        If Len(aPartes) >= 3 .And. !Empty(aPartes[3])
            cMenu := BuscaMenu(AllTrim(aPartes[3]))
            If Empty(cMenu)
                cMsg := "menu não encontrado: " + aPartes[3]
                Return .F.
            EndIf
        EndIf
        If nNivel < -1 .Or. nNivel > 9
            cMsg := "nível inválido para o módulo " + cMod
            Return .F.
        EndIf
        If IsDigit(cMod)
            AAdd(aDef, {Val(cMod), "", nNivel, cMenu})
        Else
            AAdd(aDef, {0, IIf(Left(cMod, 4) == "SIGA", cMod, "SIGA" + cMod), nNivel, cMenu})
        EndIf
    Next nI

    // Confere se todos os módulos informados existem no grid
    For nI := 1 To Len(aDef)
        nPos := 0
        For nJ := 1 To oGrid:Length()
            oGrid:GoLine(nJ)
            If ModIgual(oGrid, aDef[nI])
                nPos := nJ
                Exit
            EndIf
        Next nJ
        If nPos == 0
            cMsg := "módulo não encontrado: " + IIf(Empty(aDef[nI][2]), cValToChar(aDef[nI][1]), aDef[nI][2])
            Return .F.
        EndIf
    Next nI

    For nJ := 1 To oGrid:Length()
        oGrid:GoLine(nJ)
        nPos := AScan(aDef, {|x| ModIgual(oGrid, x)})
        If nPos > 0 .And. aDef[nPos][3] == -1
            If oGrid:GetValue(Fld("ACESSO")) .And. !GridSet(oGrid, Fld("ACESSO"), .F., @cMsg)
                Return .F.
            EndIf
        ElseIf nPos > 0
            If !GridSet(oGrid, Fld("ACESSO"), .T., @cMsg) .Or. ;
                    !GridSet(oGrid, Fld("NIVEL"), aDef[nPos][3], @cMsg) .Or. ;
                    (!Empty(aDef[nPos][4]) .And. !GridSet(oGrid, Fld("ARQMENU"), aDef[nPos][4], @cMsg))
                cMsg := AllTrim(oGrid:GetValue(Fld("CODMOD"))) + ": " + cMsg
                Return .F.
            EndIf
        ElseIf (lRepl .Or. lTodos) .And. oGrid:GetValue(Fld("ACESSO")) != lTodos
            If !GridSet(oGrid, Fld("ACESSO"), lTodos, @cMsg)
                Return .F.
            EndIf
        EndIf
    Next nJ
Return .T.

/*/{Protheus.doc} MontaMods
Junta as colunas por módulo (SIGAFAT = nível, MENU_SIGAFAT = menu) e a coluna MODULOS
no formato MODULO:NIVEL:MENU separado por "|".
Célula do módulo: 0 a 9 = nível, S/X = nível 5, N = tira o acesso, vazio = não mexe.
lRepl volta .T. quando a coluna MODULOS foi usada (lista completa que substitui a atual).
/*/
Static Function MontaMods(aMap, aCampos, cMsg, lRepl)
    Local cRet   := ValorCol(aMap, aCampos, "MODULOS")
    Local cNivel := ""
    Local cMenu  := ""
    Local nI     := 0

    lRepl := !Empty(cRet)
    For nI := 1 To Len(aMap)
        If aMap[nI][2] != "M"
            Loop
        EndIf
        cNivel := Upper(ColValor(aCampos, aMap[nI][1]))
        cMenu  := ValorCol(aMap, aCampos, "MENU_" + aMap[nI][4])
        Do Case
            Case Empty(cNivel)
                If !Empty(cMenu)
                    cMsg := "menu informado para " + aMap[nI][4] + " sem nível de acesso"
                    Return ""
                EndIf
                Loop
            Case AScan({"N", "NAO", "NÃO"}, cNivel) > 0
                cNivel := "N"
            Case AScan({"S", "SIM", "X"}, cNivel) > 0
                cNivel := "5"
            Case !(Len(cNivel) == 1 .And. IsDigit(cNivel))
                cMsg := aMap[nI][4] + ": nível inválido '" + cNivel + "' (use 0 a 9)"
                Return ""
        EndCase
        cRet += IIf(Empty(cRet), "", "|") + aMap[nI][4] + ":" + cNivel + IIf(Empty(cMenu), "", ":" + cMenu)
    Next nI

    // Coluna de menu sem a coluna do módulo correspondente
    For nI := 1 To Len(aMap)
        If aMap[nI][2] == "N" .And. !Empty(ColValor(aCampos, aMap[nI][1])) .And. ;
                AScan(aMap, {|x| x[2] == "M" .And. x[4] == SubStr(aMap[nI][4], 6)}) == 0
            cMsg := aMap[nI][4] + " informado sem a coluna " + SubStr(aMap[nI][4], 6)
            Return ""
        EndIf
    Next nI
Return cRet

Static Function ModIgual(oGrid, aDef)
    If aDef[1] > 0
        Return oGrid:GetValue(Fld("MODULO")) == aDef[1]
    EndIf
Return Upper(AllTrim(oGrid:GetValue(Fld("CODMOD")))) == aDef[2]

Static Function GrdFiliais(oModel, cValor, cMsg)
    Local oGrid  := SubModelo(oModel, "PROTHEUSFILIAL", @cMsg)
    Local aItens := Tokens(cValor)
    Local aFils  := {}
    Local aGrp   := {}
    Local aChave := {}
    Local cGrp   := ""
    Local cFil   := ""
    Local nI     := 0
    Local nJ     := 0
    Local aOps   := {}
    Local aOpFil := {}
    Local lInc   := .F.

    If oGrid == Nil
        Return .F.
    EndIf

    If AScan(aItens, {|x| Upper(x) == "@TODAS"}) > 0
        Return SetCampo(oModel, "PROTHEUSDATA", Fld("ALLEMP"), "1", @cMsg)
    EndIf
    If !SetCampo(oModel, "PROTHEUSDATA", Fld("ALLEMP"), "2", @cMsg)
        Return .F.
    EndIf

    lInc := SepInc(aItens, @aOps)

    // aFils: {grupo, filial}; aOpFil: operação de cada filial
    For nI := 1 To Len(aItens)
        If "/" $ aItens[nI]
            cGrp := AllTrim(Left(aItens[nI], At("/", aItens[nI]) - 1))
            cFil := AllTrim(SubStr(aItens[nI], At("/", aItens[nI]) + 1))
            If !(EmCache("FIL|" + cGrp + "|" + cFil, {|| IIf(FWFilExist(cGrp, cFil), "S", "")}) == "S")
                cMsg := "filial não existe: " + aItens[nI]
                Return .F.
            EndIf
            AAdd(aFils, {cGrp, cFil})
            AAdd(aOpFil, aOps[nI])
        Else
            cGrp := AllTrim(aItens[nI])
            aGrp := FWAllFilial(, , cGrp, .F.)
            If Empty(aGrp)
                cMsg := "grupo de empresas sem filiais: " + cGrp
                Return .F.
            EndIf
            For nJ := 1 To Len(aGrp)
                AAdd(aFils, {cGrp, aGrp[nJ]})
                AAdd(aOpFil, aOps[nI])
            Next nJ
        EndIf
    Next nI

    For nI := 1 To Len(aFils)
        AAdd(aChave, PadR(aFils[nI][1], 2) + PadR(aFils[nI][2], 12))
    Next nI

    // Substituição: remove as filiais fora da lista. Incremental: remove só as marcadas com "-"
    For nI := 1 To oGrid:Length()
        oGrid:GoLine(nI)
        nJ := AScan(aChave, oGrid:GetValue(Fld("GRPEMP")) + oGrid:GetValue(Fld("FILIAL")))
        If !oGrid:IsDeleted() .And. !Empty(oGrid:GetValue(Fld("GRPEMP"))) .And. ;
                IIf(lInc, nJ > 0 .And. aOpFil[nJ] == "-", nJ == 0)
            oGrid:DeleteLine()
        EndIf
    Next nI

    For nI := 1 To Len(aFils)
        If aOpFil[nI] == "-"
            Loop
        EndIf
        If oGrid:SeekLine({{Fld("GRPEMP"), PadR(aFils[nI][1], 2)}, {Fld("FILIAL"), PadR(aFils[nI][2], 12)}})
            Loop
        EndIf
        If !NovaLinha(oGrid, @cMsg) .Or. ;
                !GridSet(oGrid, Fld("GRPEMP"), aFils[nI][1], @cMsg) .Or. ;
                !GridSet(oGrid, Fld("FILIAL"), aFils[nI][2], @cMsg) .Or. ;
                !GridSet(oGrid, Fld("ACESSO"), .T., @cMsg)
            cMsg := aFils[nI][1] + "/" + aFils[nI][2] + ": " + cMsg
            Return .F.
        EndIf
    Next nI
Return .T.

Static Function GrdAcessos(oModel, cValor, cMsg)
    Local oGrid  := SubModelo(oModel, "PROTHEUSACCESS", @cMsg)
    Local aItens := Tokens(cValor)
    Local cTok   := ""
    Local lLibera := .T.
    Local nCod   := 0
    Local nI     := 0
    Local nJ     := 0

    If oGrid == Nil
        Return .F.
    EndIf

    For nI := 1 To Len(aItens)
        cTok := Upper(aItens[nI])
        If cTok == "@TODOS" .Or. cTok == "@NENHUM"
            For nJ := 1 To oGrid:Length()
                oGrid:GoLine(nJ)
                If !GridSet(oGrid, Fld("ACESSO"), cTok == "@TODOS", @cMsg)
                    Return .F.
                EndIf
            Next nJ
            Loop
        EndIf
        lLibera := Left(cTok, 1) != "-"
        nCod    := Val(StrTran(StrTran(cTok, "-", ""), "+", ""))
        If !oGrid:SeekLine({{Fld("CODACESSO"), nCod}})
            cMsg := "código de acesso inexistente: " + aItens[nI]
            Return .F.
        EndIf
        If !GridSet(oGrid, Fld("ACESSO"), lLibera, @cMsg)
            cMsg := "acesso " + cValToChar(nCod) + ": " + cMsg
            Return .F.
        EndIf
    Next nI
Return .T.

Static Function GrdSuperio(oModel, cValor, cMsg)
    Local oGrid  := SubModelo(oModel, "DATASUPER", @cMsg)
    Local aItens := Tokens(cValor)
    Local aIds   := {}
    Local cId    := ""
    Local nI     := 0

    Local aOps   := {}
    Local lInc   := SepInc(aItens, @aOps)

    If oGrid == Nil
        Return .F.
    EndIf

    For nI := 1 To Len(aItens)
        cId := BuscaUsr(aItens[nI])
        If Empty(cId)
            cMsg := "superior não encontrado: " + aItens[nI]
            Return .F.
        EndIf
        AAdd(aIds, cId)
    Next nI
Return AplicaIds(oGrid, "USR_SUPER", aIds, aOps, lInc, @cMsg)

Static Function GrdHorario(oModel, cValor, cMsg)
    Local oGrid  := SubModelo(oModel, "ACCESSRESTRICTION", @cMsg)
    Local aItens := Tokens(cValor)
    Local cDia   := ""
    Local cIni   := ""
    Local cFim   := ""
    Local nI     := 0

    If oGrid == Nil
        Return .F.
    EndIf

    For nI := 1 To Len(aItens)
        If !("=" $ aItens[nI]) .Or. !("-" $ aItens[nI])
            cMsg := "formato inválido (use DIA=HH:MM-HH:MM): " + aItens[nI]
            Return .F.
        EndIf
        cDia := AllTrim(Left(aItens[nI], At("=", aItens[nI]) - 1))
        cIni := AllTrim(SubStr(aItens[nI], At("=", aItens[nI]) + 1))
        cFim := AllTrim(SubStr(cIni, At("-", cIni) + 1))
        cIni := AllTrim(Left(cIni, At("-", cIni) - 1))
        If !oGrid:SeekLine({{Fld("DIASEMANA"), cDia}})
            If !NovaLinha(oGrid, @cMsg) .Or. !GridSet(oGrid, Fld("DIASEMANA"), cDia, @cMsg)
                cMsg := "dia " + cDia + ": " + cMsg
                Return .F.
            EndIf
        EndIf
        If !GridSet(oGrid, Fld("HORAINI"), cIni, @cMsg) .Or. !GridSet(oGrid, Fld("HORAFIM"), cFim, @cMsg)
            cMsg := "dia " + cDia + ": " + cMsg
            Return .F.
        EndIf
    Next nI
Return .T.

Static Function GrdPapeis(oModel, cValor, cMsg)
    Local oGrid  := SubModelo(oModel, "DATAPAPER", @cMsg)
    Local aIds   := Tokens(cValor)
    Local aOps   := {}
    Local lInc   := SepInc(aIds, @aOps)

    If oGrid == Nil
        Return .F.
    EndIf
Return AplicaIds(oGrid, Fld("PAPER"), aIds, aOps, lInc, @cMsg)

Static Function SetVincFun(oModel, cValor, cMsg)
    Local aPartes := StrTokArr2(cValor, "/", .T.)

    If Len(aPartes) != 3
        cMsg := "use GRUPO/FILIAL/MATRICULA"
        Return .F.
    EndIf
Return SetCampo(oModel, "PROTHEUSVINCFUNC", "USR_GRPEMP", AllTrim(aPartes[1]), @cMsg) .And. ;
    SetCampo(oModel, "PROTHEUSVINCFUNC", "USR_FILIAL", AllTrim(aPartes[2]), @cMsg) .And. ;
    SetCampo(oModel, "PROTHEUSVINCFUNC", "USR_CODFUNC", AllTrim(aPartes[3]), @cMsg)

// Lista incremental: se algum item começa com + ou -, só esses itens mudam (+ adiciona, - remove).
// Sem prefixo em nenhum item, a lista substitui o conteúdo atual. Remove o prefixo de aItens e
// devolve em aOps a operação de cada item ("+" ou "-").
Static Function SepInc(aItens, aOps)
    Local lInc := AScan(aItens, {|x| Left(x, 1) == "+" .Or. Left(x, 1) == "-"}) > 0
    Local nI   := 0

    aOps := {}
    For nI := 1 To Len(aItens)
        If Left(aItens[nI], 1) == "+" .Or. Left(aItens[nI], 1) == "-"
            AAdd(aOps, Left(aItens[nI], 1))
            aItens[nI] := AllTrim(SubStr(aItens[nI], 2))
        Else
            AAdd(aOps, "+")
        EndIf
    Next nI
Return lInc

// Exclui do grid as linhas com as chaves informadas
Static Function TiraGrid(oGrid, cChave, aIds, cMsg)
    Local nI := 0

    For nI := 1 To oGrid:Length()
        oGrid:GoLine(nI)
        If !oGrid:IsDeleted() .And. AScan(aIds, {|x| AllTrim(x) == AllTrim(oGrid:GetValue(cChave))}) > 0
            If !oGrid:DeleteLine()
                cMsg := ErroModelo(oGrid:GetModel())
                Return .F.
            EndIf
        EndIf
    Next nI
Return .T.

// Aplica uma lista de chaves no grid: substitui tudo ou, no modo incremental, adiciona/remove
Static Function AplicaIds(oGrid, cChave, aIds, aOps, lInc, cMsg)
    Local aAdd := {}
    Local aDel := {}
    Local nI   := 0

    For nI := 1 To Len(aIds)
        If aOps[nI] == "-"
            AAdd(aDel, aIds[nI])
        Else
            AAdd(aAdd, aIds[nI])
        EndIf
    Next nI
    If lInc
        If !TiraGrid(oGrid, cChave, aDel, @cMsg)
            Return .F.
        EndIf
    ElseIf !LimpaGrid(oGrid, cChave, aAdd, @cMsg)
        Return .F.
    EndIf
    For nI := 1 To Len(aAdd)
        If !LinhaGrid(oGrid, cChave, aAdd[nI], @cMsg)
            cMsg := aAdd[nI] + ": " + cMsg
            Return .F.
        EndIf
    Next nI
Return .T.

// Exclui do grid as linhas cuja chave não está na lista
Static Function LimpaGrid(oGrid, cChave, aIds, cMsg)
    Local nI := 0

    For nI := 1 To oGrid:Length()
        oGrid:GoLine(nI)
        If !oGrid:IsDeleted() .And. !Empty(oGrid:GetValue(cChave)) .And. ;
                AScan(aIds, {|x| AllTrim(x) == AllTrim(oGrid:GetValue(cChave))}) == 0
            If !oGrid:DeleteLine()
                cMsg := ErroModelo(oGrid:GetModel())
                Return .F.
            EndIf
        EndIf
    Next nI
Return .T.

// Posiciona na linha com a chave ou cria uma nova
Static Function LinhaGrid(oGrid, cChave, cValor, cMsg)
    If oGrid:SeekLine({{cChave, cValor}})
        Return .T.
    EndIf
Return NovaLinha(oGrid, @cMsg) .And. GridSet(oGrid, cChave, cValor, @cMsg)

Static Function NovaLinha(oGrid, cMsg)
    Local nI := 0

    // Reaproveita a linha em branco do grid vazio
    For nI := 1 To oGrid:Length()
        oGrid:GoLine(nI)
        If !oGrid:IsDeleted() .And. LinhaVazia(oGrid)
            Return .T.
        EndIf
    Next nI
    If oGrid:AddLine() == 0
        cMsg := ErroModelo(oGrid:GetModel())
        Return .F.
    EndIf
Return .T.

Static Function LinhaVazia(oGrid)
    Local aFlds := oGrid:GetStruct():GetFields()
    Local nI    := 0
    Local xVal  := Nil

    For nI := 1 To Len(aFlds)
        If AllTrim(aFlds[nI][3]) $ "USR_ID|USR_CHKSUM|USR_PRIORIZA|USR_ACESSO|GR__ID|GR__PRIORIZA|GR__ACESSO" .Or. aFlds[nI][14]
            Loop
        EndIf
        xVal := oGrid:GetValue(aFlds[nI][3])
        If !Empty(xVal)
            Return .F.
        EndIf
    Next nI
Return .T.

// Nome do campo no cadastro em processamento: Fld("ACESSO") = USR_ACESSO ou GR__ACESSO
Static Function Fld(cSufixo)
Return cPfx + cSufixo

Static Function GridSet(oGrid, cCampo, xValor, cMsg)
    If !oGrid:SetValue(cCampo, xValor)
        cMsg := ErroModelo(oGrid:GetModel())
        Return .F.
    EndIf
Return .T.

// ---------------------------------------------------------------------------
// Privilégios (MPUSERACCOUNTRULES)
// ---------------------------------------------------------------------------

Static Function ResRegras(cValor, cMsg)
    Local aItens := Tokens(cValor)
    Local aRet   := {}
    Local cId    := ""
    Local nI     := 0

    For nI := 1 To Len(aItens)
        cId := EmCache("REGRA|" + Upper(aItens[nI]), {|| QryValor("SELECT RL__ID FROM SYS_RULES WHERE D_E_L_E_T_ = ' ' AND (RTRIM(RL__ID) = '" + ;
            SqlStr(aItens[nI]) + "' OR UPPER(RTRIM(RL__CODIGO)) = '" + SqlStr(Upper(aItens[nI])) + "')")})
        If Empty(cId)
            cMsg := "PRIVILEGIOS: regra não encontrada: " + aItens[nI]
            Return {}
        EndIf
        AAdd(aRet, cId)
    Next nI
Return aRet

// Vincula regras de privilégio ao usuário (cTipo U) ou ao grupo (cTipo G)
Static Function GravaRegra(cTipo, cId, aRegras, cMsg)
    Local lGrp   := cTipo == "G"
    Local oRules := FWLoadModel(IIf(lGrp, "MPGROUPACCOUNTRULES", "MPUSERACCOUNTRULES"))
    Local cCab   := IIf(lGrp, "GROUPRULES", "USERRULES")
    Local cChvId := IIf(lGrp, "GROUP_ID", "USER_ID")
    Local cRegra := IIf(lGrp, "GR__RL_ID", "USR_RL_ID")
    Local cTab   := IIf(lGrp, "SYS_RULES_GRP_RULES", "SYS_RULES_USR_RULES")
    Local cQuem  := IIf(lGrp, "grupo", "usuário")
    Local oGrid  := Nil
    Local cAlias := ""
    Local lExist := .F.
    Local lOk    := .T.
    Local nI     := 0

    lExist := !Empty(QryValor("SELECT " + cChvId + " FROM " + cTab + " WHERE D_E_L_E_T_ = ' ' AND " + cChvId + " = '" + cId + "'"))

    If lExist
        cAlias := oRules:GetModel(cCab):GetStruct():GetTable()[1]
        If Select(cAlias) == 0 .Or. !(cAlias)->(DbSeek(cId))
            cMsg := cQuem + " já possui privilégios; ajuste-os pelo Configurador."
            oRules:Destroy()
            Return .F.
        EndIf
        oRules:SetOperation(MODEL_OPERATION_UPDATE)
    Else
        oRules:SetOperation(MODEL_OPERATION_INSERT)
    EndIf

    If !oRules:Activate()
        cMsg := ErroModelo(oRules)
        oRules:Destroy()
        Return .F.
    EndIf

    If !lExist
        lOk := oRules:SetValue(cCab, cChvId, cId)
    ElseIf oRules:GetValue(cCab, cChvId) != cId
        // Trava de segurança: nunca alterar privilégios de outro usuário/grupo
        cMsg := "modelo de privilégios carregou outro " + cQuem + "; ajuste-os pelo Configurador."
        oRules:DeActivate()
        oRules:Destroy()
        Return .F.
    EndIf
    oGrid := oRules:GetModel("DATARULES")
    lOk := lOk .And. LimpaGrid(oGrid, cRegra, aRegras, @cMsg)
    For nI := 1 To Len(aRegras)
        If !lOk
            Exit
        EndIf
        lOk := LinhaGrid(oGrid, cRegra, aRegras[nI], @cMsg)
    Next nI

    lOk := lOk .And. oRules:VldData() .And. oRules:CommitData()
    If !lOk .And. Empty(cMsg)
        cMsg := ErroModelo(oRules)
    EndIf
    oRules:DeActivate()
    oRules:Destroy()
Return lOk

// ---------------------------------------------------------------------------
// Campos e conversão de valores
// ---------------------------------------------------------------------------

Static Function SetCampo(oModel, cSub, cCampo, cValor, cMsg)
    Local oSub  := oModel:GetModel(cSub)
    Local aInfo := {}
    Local xVal  := Nil

    // O ID do submodelo muda entre versões do framework: procura o campo nos demais
    If ValType(oSub) != "O" .Or. Empty(InfoCampo(oSub, cCampo))
        cSub := AchaSub(oModel, cCampo)
        If Empty(cSub)
            SubModelo(oModel, "?", @cMsg)
            cMsg := "campo " + cCampo + " não encontrado em nenhum submodelo" + IIf("(" $ cMsg, SubStr(cMsg, At(" (", cMsg)), "")
            Return .F.
        EndIf
        oSub := oModel:GetModel(cSub)
    EndIf
    aInfo := InfoCampo(oSub, cCampo)

    If Empty(aInfo)
        cMsg := "campo " + cCampo + " não existe em " + cSub
        Return .F.
    EndIf

    xVal := ConvValor(aInfo[1], cValor, aInfo[2], aInfo[3], @cMsg)
    If xVal == Nil
        cMsg := cCampo + ": " + cMsg
        Return .F.
    EndIf

    If !oModel:SetValue(cSub, cCampo, xVal)
        cMsg := cCampo + ": " + ErroModelo(oModel)
        Return .F.
    EndIf
Return .T.

// Retorna {tipo, tamanho, opções do combo}
Static Function InfoCampo(oSub, cCampo)
    Local aFlds := {}
    Local aOpc  := {}
    Local nPos  := 0
    Local nI    := 0

    If ValType(oSub) != "O"
        Return {}
    EndIf
    aFlds := oSub:GetStruct():GetFields()
    nPos  := AScan(aFlds, {|x| AllTrim(x[3]) == cCampo})

    If nPos == 0
        Return {}
    EndIf
    If ValType(aFlds[nPos][9]) == "A"
        For nI := 1 To Len(aFlds[nPos][9])
            AAdd(aOpc, AllTrim(StrTokArr2(aFlds[nPos][9][nI], "=", .T.)[1]))
        Next nI
    EndIf
Return {aFlds[nPos][4], aFlds[nPos][5], aOpc}

Static Function ConvValor(cTipo, cValor, nTam, aOpc, cMsg)
    Local xRet  := Nil
    Local cUp   := Upper(AllTrim(cValor))
    Local aSim  := {"S", "SIM", "Y", "YES", "T", ".T.", "TRUE", "X", "1"}
    Local aNao  := {"N", "NAO", "NÃO", "NO", "F", ".F.", "FALSE", "0", "2"}

    Do Case
        Case cTipo == "L"
            Do Case
                Case AScan(aSim, cUp) > 0
                    xRet := .T.
                Case AScan(aNao, cUp) > 0
                    xRet := .F.
                Otherwise
                    cMsg := "valor lógico inválido '" + cValor + "' (use S/N)"
            EndCase

        Case cTipo == "N"
            If !Empty(StrTran(StrTran(StrTran(cUp, ",", ""), ".", ""), "-", "")) .And. ;
                    !IsDigit(StrTran(StrTran(StrTran(cUp, ",", ""), ".", ""), "-", ""))
                cMsg := "valor numérico inválido '" + cValor + "'"
            Else
                xRet := Val(StrTran(cUp, ",", "."))
            EndIf

        Case cTipo == "D"
            xRet := ConvData(cUp)
            If Empty(xRet)
                cMsg := "data inválida '" + cValor + "'"
                xRet := Nil
            EndIf

        Otherwise
            xRet := AllTrim(cValor)
            If !Empty(aOpc) .And. AScan(aOpc, xRet) == 0
                // Combos 1=Sim/2=Não aceitam S/N; "1=Priorizar" vira "1"
                Do Case
                    Case ArrIgual(aOpc, {"1", "2"}) .And. AScan(aSim, cUp) > 0
                        xRet := "1"
                    Case ArrIgual(aOpc, {"1", "2"}) .And. AScan(aNao, cUp) > 0
                        xRet := "2"
                    Case AScan(aOpc, AllTrim(StrTokArr2(xRet, "=", .T.)[1])) > 0
                        xRet := AllTrim(StrTokArr2(xRet, "=", .T.)[1])
                    Otherwise
                        cMsg := "valor '" + cValor + "' fora das opções (" + ArrTokStr(aOpc, "/") + ")"
                        xRet := Nil
                EndCase
            EndIf
            If xRet != Nil .And. cTipo == "C" .And. Len(xRet) > nTam
                cMsg := "valor maior que o tamanho do campo (" + cValToChar(nTam) + ")"
                xRet := Nil
            EndIf
    EndCase
Return xRet

Static Function ArrIgual(aA, aB)
Return Len(aA) == Len(aB) .And. ArrTokStr(aA, "|") == ArrTokStr(aB, "|")

Static Function ConvData(cValor)
    Local cNum := StrTran(StrTran(cValor, "-", ""), "/", "")

    Do Case
        Case Len(cValor) == 10 .And. SubStr(cValor, 5, 1) == "-"   // aaaa-mm-dd
            Return SToD(cNum)
        Case Len(cValor) == 8 .And. IsDigit(cValor)                 // aaaammdd
            Return SToD(cValor)
        Case "/" $ cValor                                            // dd/mm/aaaa
            Return SToD(StrZero(Val(SubStr(cNum, 5)), 4) + SubStr(cNum, 3, 2) + Left(cNum, 2))
    EndCase
Return CToD("")

// ---------------------------------------------------------------------------
// Mapeamento das colunas do CSV
// ---------------------------------------------------------------------------

/*/{Protheus.doc} MapColunas
@return array, cada item {nColuna, cTipo, cSubmodelo, cCampo/cColuna}
    cTipo: F = campo de formulário, E = coluna especial (lista/senha/operação)
/*/
Static Function MapColunas(aHead, oModel, aAvisos, cTipo)
    Local aMap    := {}
    Local aEspec  := {"OPERACAO", "SENHA", "GRUPOS", "MODULOS", "FILIAIS", "ACESSOS", "PRIVILEGIOS", ;
        "SUPERIORES", "HORARIOS", "PAPEIS", "VINCULO_FUNC"}
    Local aApelido := {}
    Local aApeUsr := {;
        {"LOGIN", "DATAUSER", "USR_CODIGO"}, ;
        {"USUARIO", "DATAUSER", "USR_CODIGO"}, ;
        {"NOME", "DATAUSER", "USR_NOME"}, ;
        {"EMAIL", "DATAUSER", "USR_EMAIL"}, ;
        {"DEPARTAMENTO", "DATAUSER", "USR_DEPTO"}, ;
        {"CARGO", "DATAUSER", "USR_CARGO"}, ;
        {"BLOQUEADO", "DATAUSER", "USR_MSBLQL"}, ;
        {"DT_VALIDADE", "DATAUSER", "USR_MSBLQD"}, ;
        {"TROCA_SENHA", "DATAUSER", "USR_CHGPSW"}, ;
        {"DIAS_EXPIRA_SENHA", "DATAUSER", "USR_QTDEXPPSW"}, ;
        {"REGRA_GRUPO", "DATAUSER", "USR_GRPRULE"}, ;
        {"DIGITOS_ANO", "DATAUSER", "USR_ANO"}, ;
        {"ACESSOS_SIMULT", "RESTRICTION", "USR_QTDACESSOS"}, ;
        {"TIMEOUT", "RESTRICTION", "USR_TIMEOUT"}, ;
        {"NIVEL_LEITURA", "PROTHEUSDATA", "USR_NIVELREAD"}, ;
        {"TODAS_EMPRESAS", "PROTHEUSDATA", "USR_ALLEMP"}, ;
        {"RAMAL", "PROTHEUSDATA", "USR_RAMAL"}, ;
        {"DIR_IMPRESSAO", "PROTHEUSPRINTER", "USR_DIRIMP"}}
    Local aApeGrp := {;
        {"CODIGO", "DATAGROUP", "GR__CODIGO"}, ;
        {"DESCRICAO", "DATAGROUP", "GR__NOME"}, ;
        {"NOME", "DATAGROUP", "GR__NOME"}, ;
        {"BLOQUEADO", "DATAGROUP", "GR__MSBLQL"}, ;
        {"DT_VALIDADE", "DATAGROUP", "GR__MSBLQD"}, ;
        {"DIAS_EXPIRA_SENHA", "DATAGROUP", "GR__QTDEXPPSW"}, ;
        {"TIMEOUT", "DATAGROUP", "GR__TIMEOUT"}, ;
        {"NIVEL_LEITURA", "PROTHEUSDATA", "GR__NIVELREAD"}, ;
        {"TODAS_EMPRESAS", "PROTHEUSDATA", "GR__ALLEMP"}, ;
        {"DIR_IMPRESSAO", "PROTHEUSPRINTER", "GR__DIRIMP"}}
    // Submodelos de formulário liberados para importação direta pelo nome do campo
    Local aSubs   := {}
    Local aBloq   := {"USR_ID", "USR_UUID", "USR_PSWMD5", "USR_CHKSUM", "USR_CODSAL", "USR_VERSAO", "USR_PSW", "USR_PSWCMP", ;
        "GR__ID", "GR__IDMID"}
    Local cCol    := ""
    Local nI      := 0
    Local nJ      := 0
    Local nPos    := 0
    Local lAchou  := .F.

    If cTipo == "G"
        aApelido := aApeGrp
        aEspec   := {"OPERACAO", "MODULOS", "FILIAIS", "ACESSOS", "PRIVILEGIOS", "HORARIOS", "PAPEIS"}
        aSubs    := {"DATAGROUP", "PROTHEUSDATA", "PROTHEUSPRINTER", "PROTHEUSACC"}
    Else
        aApelido := aApeUsr
        aSubs    := {"DATAUSER", "RESTRICTION", "PROTHEUSDATA", "PROTHEUSPRINTER", "PROTHEUSLOG", "PROTHEUSACC"}
    EndIf

    For nI := 1 To Len(aHead)
        cCol := Upper(AllTrim(StrTran(aHead[nI], '"', "")))
        If Empty(cCol)
            Loop
        EndIf
        If AScan(aMap, {|x| x[4] == cCol .Or. (x[5] == cCol)}) > 0
            AAdd(aAvisos, "Coluna repetida ignorada: " + cCol)
            Loop
        EndIf

        If AScan(aEspec, cCol) > 0
            AAdd(aMap, {nI, "E", "", cCol, cCol})
            Loop
        EndIf

        // Uma coluna por módulo (SIGAFAT = nível) e menu opcional (MENU_SIGAFAT)
        If Left(cCol, 4) == "SIGA"
            AAdd(aMap, {nI, "M", "", cCol, cCol})
            Loop
        EndIf
        If Left(cCol, 9) == "MENU_SIGA"
            AAdd(aMap, {nI, "N", "", cCol, cCol})
            Loop
        EndIf

        nPos := AScan(aApelido, {|x| x[1] == cCol})
        If nPos > 0
            AAdd(aMap, {nI, "F", aApelido[nPos][2], aApelido[nPos][3], cCol})
            Loop
        EndIf

        lAchou := .F.
        If AScan(aBloq, cCol) == 0
            For nJ := 1 To Len(aSubs)
                If !Empty(InfoCampo(oModel:GetModel(aSubs[nJ]), cCol))
                    AAdd(aMap, {nI, "F", aSubs[nJ], cCol, cCol})
                    lAchou := .T.
                    Exit
                EndIf
            Next nJ
        EndIf
        If !lAchou
            AAdd(aAvisos, "Coluna desconhecida ignorada: " + cCol)
        EndIf
    Next nI
Return aMap

// Valor de uma coluna pelo nome do campo (USR_CODIGO) ou da coluna especial (GRUPOS)
Static Function ValorCol(aMap, aCampos, cNome)
    Local nPos := AScan(aMap, {|x| x[4] == cNome})

    If nPos == 0
        Return ""
    EndIf
Return ColValor(aCampos, aMap[nPos][1])

Static Function ColValor(aCampos, nCol)
    If nCol > Len(aCampos)
        Return ""
    EndIf
Return AllTrim(aCampos[nCol])

// ---------------------------------------------------------------------------
// Consultas
// ---------------------------------------------------------------------------

Static Function BuscaUsr(cTok)
    Local cUp := SqlStr(Upper(AllTrim(cTok)))
Return QryValor("SELECT USR_ID FROM SYS_USR WHERE D_E_L_E_T_ = ' ' AND (UPPER(RTRIM(USR_CODIGO)) = '" + cUp + ;
    "' OR RTRIM(USR_ID) = '" + cUp + "')")

// Grupo por código (ex.: 0101), depois ID, depois descrição. Descrição repetida = erro.
Static Function BuscaGrupo(cTok, cMsg)
    Local cUp  := SqlStr(Upper(AllTrim(cTok)))
    Local cRet := EmCache("GRP|" + cUp, {|| AchaGrupo(cUp)})

    If cRet == "#AMBIGUO#"
        cMsg := "mais de um grupo com a descrição '" + cTok + "'; use o código"
        Return ""
    EndIf
Return cRet

Static Function AchaGrupo(cUp)
    Local cBase := "SELECT GR__ID FROM SYS_GRP_GROUP WHERE D_E_L_E_T_ = ' ' AND "
    Local aIds  := QryLista(cBase + "UPPER(RTRIM(GR__CODIGO)) = '" + cUp + "'")

    If Empty(aIds)
        aIds := QryLista(cBase + "RTRIM(GR__ID) = '" + cUp + "'")
    EndIf
    If Empty(aIds)
        aIds := QryLista(cBase + "UPPER(RTRIM(GR__NOME)) = '" + cUp + "'")
    EndIf
Return IIf(Len(aIds) > 1, "#AMBIGUO#", IIf(Empty(aIds), "", aIds[1])) // "*" é o ID do grupo Default: não serve de marcador

// Executa a busca uma vez por chave durante a importação
Static Function EmCache(cChave, bBusca)
    If oCache == Nil
        Return Eval(bBusca)
    EndIf
    If !oCache:HasProperty(cChave)
        oCache[cChave] := Eval(bBusca)
    EndIf
Return oCache[cChave]

// Menu por ID do MPMENU, nome (SIGAFAT) ou arquivo (SIGAFAT.XNU / \system\sigafat.xnu)
Static Function BuscaMenu(cTok)
Return EmCache("MENU|" + Upper(AllTrim(cTok)), {|| AchaMenu(cTok)})

Static Function AchaMenu(cTok)
    Local cUp  := Upper(AllTrim(StrTran(cTok, "\", "/")))
    Local cArq := SubStr(cUp, RAt("/", cUp) + 1)
    Local cId  := ""

    cId := QryValor("SELECT M_ID FROM MPMENU_MENU WHERE D_E_L_E_T_ = ' ' AND (RTRIM(M_ID) = '" + SqlStr(cUp) + ;
        "' OR UPPER(RTRIM(M_NAME)) = '" + SqlStr(StrTran(cArq, ".XNU", "")) + ;
        "' OR UPPER(RTRIM(M_ARQMENU)) LIKE '%/" + SqlStr(IIf(".XNU" $ cArq, cArq, cArq + ".XNU")) + "')")
    If Empty(cId) .And. ".XNU" $ cArq .And. File("\system\" + Lower(cArq))
        cId := "/system/" + Lower(cArq)
    EndIf
Return cId

Static Function QryValor(cQry)
    Local cAlias := GetNextAlias()
    Local cRet   := ""

    DbUseArea(.T., "TOPCONN", TcGenQry(, , cQry), cAlias, .F., .T.)
    If !(cAlias)->(Eof())
        cRet := AllTrim(cValToChar((cAlias)->(FieldGet(1))))
    EndIf
    (cAlias)->(DbCloseArea())
Return cRet

Static Function QryLista(cQry)
    Local cAlias := GetNextAlias()
    Local aRet   := {}

    DbUseArea(.T., "TOPCONN", TcGenQry(, , cQry), cAlias, .F., .T.)
    While !(cAlias)->(Eof())
        AAdd(aRet, AllTrim(cValToChar((cAlias)->(FieldGet(1)))))
        (cAlias)->(DbSkip())
    EndDo
    (cAlias)->(DbCloseArea())
Return aRet

// Primeira linha da consulta, todos os campos como texto
Static Function QryLinha(cQry)
    Local cAlias := GetNextAlias()
    Local aRet   := {}
    Local nI     := 0

    DbUseArea(.T., "TOPCONN", TcGenQry(, , cQry), cAlias, .F., .T.)
    If !(cAlias)->(Eof())
        For nI := 1 To (cAlias)->(FCount())
            AAdd(aRet, AllTrim(cValToChar((cAlias)->(FieldGet(nI)))))
        Next nI
    EndIf
    (cAlias)->(DbCloseArea())
Return aRet

Static Function SqlStr(cTexto)
Return StrTran(AllTrim(cTexto), "'", "''")

// ---------------------------------------------------------------------------
// Arquivos
// ---------------------------------------------------------------------------

Static Function LerCsv(cArq)
    Local oArq    := FWFileReader():New(cArq)
    Local aLinhas := {}
    Local cLinha  := ""
    Local cUtf    := Nil
    Local lUtf8   := .F.

    If !oArq:Open()
        Return {}
    EndIf
    While oArq:HasLine()
        cLinha := oArq:GetLine()
        If Empty(aLinhas) .And. Left(cLinha, 3) == Chr(239) + Chr(187) + Chr(191)
            cLinha := SubStr(cLinha, 4)
            lUtf8  := .T.
        EndIf
        cLinha := StrTran(cLinha, Chr(13), "")
        // Sem BOM: converte se a linha for UTF-8 válido com acentos
        cUtf := DecodeUTF8(cLinha)
        If cUtf != Nil .And. (lUtf8 .Or. !(cUtf == cLinha))
            cLinha := cUtf
        EndIf
        AAdd(aLinhas, cLinha)
    EndDo
    oArq:Close()
Return aLinhas

Static Function SplitCsv(cLinha, cSep)
    Local aRet   := {}
    Local cAtual := ""
    Local cChar  := ""
    Local lAspas := .F.
    Local nI     := 0

    For nI := 1 To Len(cLinha)
        cChar := SubStr(cLinha, nI, 1)
        Do Case
            Case cChar == '"' .And. lAspas .And. SubStr(cLinha, nI + 1, 1) == '"'
                cAtual += '"'
                nI++
            Case cChar == '"'
                lAspas := !lAspas
            Case cChar == cSep .And. !lAspas
                AAdd(aRet, AllTrim(cAtual))
                cAtual := ""
            Otherwise
                cAtual += cChar
        EndCase
    Next nI
    AAdd(aRet, AllTrim(cAtual))
Return aRet

Static Function Tokens(cValor)
    Local aTok := StrTokArr2(cValor, "|", .T.)
    Local aRet := {}
    Local nI   := 0

    For nI := 1 To Len(aTok)
        If !Empty(aTok[nI])
            AAdd(aRet, AllTrim(aTok[nI]))
        EndIf
    Next nI
Return aRet

// Cria o arquivo de log e grava o cabeçalho
Static Function LogAbre(cArq, cTipo)
    Local cDir := "\zimpusr\log\"
    Local nHdl := -1

    FWMakeDir(cDir, .F.)
    cArq := cDir + IIf(cTipo == "G", "zimpgrp_", "zimpusr_") + DToS(Date()) + "_" + StrTran(Time(), ":", "") + ".csv"
    nHdl := FCreate(cArq)
    FWrite(nHdl, "LINHA;" + IIf(cTipo == "G", "CODIGO", "LOGIN") + ";OPERACAO;STATUS;MENSAGEM" + CRLF)
Return nHdl

// Grava uma linha do log na hora (sobrevive a uma interrupção da importação)
Static Function LogLinha(nHdl, aLin)
    If nHdl >= 0
        FWrite(nHdl, cValToChar(aLin[1]) + ";" + aLin[2] + ";" + aLin[3] + ";" + aLin[4] + ";" + ;
            StrTran(StrTran(aLin[5], ";", ","), CRLF, " ") + CRLF)
    EndIf
Return

// Copia o arquivo da estação para o servidor quando necessário
Static Function ArqServid(cArq)
    Local cDir  := "\zimpusr\entrada\"
    Local cNome := SubStr(cArq, RAt(IIf("\" $ cArq, "\", "/"), cArq) + 1)

    If Left(cArq, 1) == "\" .And. File(cArq)
        Return cArq
    EndIf
    FWMakeDir(cDir, .F.)
    If !CpyT2S(cArq, cDir, .F.)
        FWAlertError("Não foi possível copiar o arquivo para o servidor: " + cArq, "ZIMPUSR")
        Return ""
    EndIf
Return cDir + cNome

Static Function GeraModelo(cTipo)
    Local cDir  := "\zimpusr\"
    Local cNome := IIf(cTipo == "G", "modelo_importacao_grupos.csv", "modelo_importacao_usuarios.csv")
    Local cArq  := cDir + cNome
    Local cTemp := GetTempPath()
    Local cCsv  := ""

    If cTipo == "G"
        cCsv := "CODIGO;DESCRICAO;BLOQUEADO;NIVEL_LEITURA;TODAS_EMPRESAS;FILIAIS;SIGAGPE;MENU_SIGAGPE;SIGAPON;" + ;
            "ACESSOS;PRIVILEGIOS;HORARIOS;DIAS_EXPIRA_SENHA;TIMEOUT" + CRLF
        cCsv += "0101;DF - RH - Operacional;N;5;N;01/0101;5;;5;@NENHUM|9|10|11|12|113;;;90;30" + CRLF
        cCsv += "0102;DF - RH - Operacional Restrito;N;5;N;01/0101;3;;;@NENHUM|9|10;;2=08:00-18:00|3=08:00-18:00|4=08:00-18:00|5=08:00-18:00|6=08:00-18:00;90;30" + CRLF
    Else
        cCsv := "LOGIN;NOME;EMAIL;DEPARTAMENTO;CARGO;GRUPOS;REGRA_GRUPO;FILIAIS;ACESSOS" + CRLF
        cCsv += "maria.souza;Maria de Souza;maria.souza@empresa.com.br;RH;Analista;0101;;;" + CRLF
        cCsv += "ana.costa;Ana Costa;ana.costa@empresa.com.br;RH;Coordenadora;0101|0201;;;" + CRLF
        cCsv += "joao.lima;João Lima;joao.lima@empresa.com.br;RH;Analista;0101;3;01/0201;@NENHUM" + CRLF
    EndIf

    FWMakeDir(cDir, .F.)
    MemoWrite(cArq, cCsv)
    If CpyS2T(cArq, cTemp, .F.)
        FWAlertSuccess("Modelo gerado em: " + cTemp + cNome + CRLF + "Cópia no servidor: " + cArq, "ZIMPUSR")
    Else
        FWAlertInfo("Modelo gerado no servidor: " + cArq, "ZIMPUSR")
    EndIf
Return

// ---------------------------------------------------------------------------
// Interface
// ---------------------------------------------------------------------------

// Confirmação extra antes de excluir de verdade: o usuário digita EXCLUIR
Static Function ConfExcl(cNome)
    Local aPergs := {}
    Local aResp  := {}

    AAdd(aPergs, {9, "A exclusão não pode ser desfeita. Os " + cNome + " do arquivo serão apagados.", 220, 20, .T.})
    AAdd(aPergs, {1, "Digite EXCLUIR para confirmar", Space(10), "@!", "", "", "", 60, .T.})
    If !ParamBox(aPergs, "Confirmar exclusão", @aResp, , , , , , , , .F., .F.)
        Return .F.
    EndIf
    If AllTrim(aResp[2]) != "EXCLUIR"
        FWAlertWarning("Confirmação incorreta. Nada foi excluído.", "ZIMPUSR")
        Return .F.
    EndIf
Return .T.

Static Function ComboNum(xValor)
    If ValType(xValor) == "N"
        Return xValor
    EndIf
Return Val(Left(AllTrim(xValor), 1))

Static Function MostraLog(cTexto, cTitulo)
    Local oDlg  := Nil
    Local oFont := TFont():New("Courier New", , -12)

    DEFINE MSDIALOG oDlg TITLE cTitulo FROM 0, 0 TO 520, 960 PIXEL
    TMultiGet():New(5, 5, {|u| IIf(PCount() > 0, cTexto := u, cTexto)}, oDlg, 470, 225, oFont, , , , , .T., , , , , , .T.)
    TButton():New(238, 425, "Fechar", oDlg, {|| oDlg:End()}, 50, 14, , , , .T.)
    ACTIVATE MSDIALOG oDlg CENTERED
Return

// Login simples quando a rotina é chamada como programa inicial (sem ambiente aberto)
Static Function TelaLogin()
    Local oDlg  := Nil
    Local cEmp  := "99"
    Local cFil  := "01"
    Local cUser := Space(25)
    Local cPsw  := Space(50)
    Local lOk   := .F.

    DEFINE MSDIALOG oDlg TITLE "ZIMPUSR - Acesso" FROM 0, 0 TO 220, 320 PIXEL
    @ 10, 10 SAY "Grupo de empresas" SIZE 60, 10 OF oDlg PIXEL
    @ 08, 80 MSGET cEmp SIZE 30, 10 OF oDlg PIXEL
    @ 26, 10 SAY "Filial" SIZE 60, 10 OF oDlg PIXEL
    @ 24, 80 MSGET cFil SIZE 50, 10 OF oDlg PIXEL
    @ 42, 10 SAY "Usuário" SIZE 60, 10 OF oDlg PIXEL
    @ 40, 80 MSGET cUser SIZE 70, 10 OF oDlg PIXEL
    @ 58, 10 SAY "Senha" SIZE 60, 10 OF oDlg PIXEL
    @ 56, 80 MSGET cPsw SIZE 70, 10 OF oDlg PIXEL PASSWORD
    TButton():New(85, 60, "Entrar", oDlg, {|| lOk := .T., oDlg:End()}, 45, 14, , , , .T.)
    TButton():New(85, 110, "Cancelar", oDlg, {|| oDlg:End()}, 45, 14, , , , .T.)
    ACTIVATE MSDIALOG oDlg CENTERED

    If lOk
        lOk := RpcSetEnv(AllTrim(cEmp), AllTrim(cFil), AllTrim(cUser), AllTrim(cPsw), "CFG", "ZIMPUSR")
        If !lOk
            MsgStop("Usuário, senha ou empresa/filial inválidos.", "ZIMPUSR")
        EndIf
    EndIf
Return lOk

Static Function ErroModelo(oModel)
    Local aErro := oModel:GetErrorMessage()
    Local cRet  := ""

    If ValType(aErro) == "A" .And. Len(aErro) >= 7
        cRet := AllTrim(cValToChar(aErro[6]))
        If !Empty(aErro[4])
            cRet := AllTrim(aErro[4]) + ": " + cRet
        EndIf
        If !Empty(aErro[7])
            cRet += " Solução: " + AllTrim(cValToChar(aErro[7]))
        EndIf
    EndIf
Return StrTran(IIf(Empty(cRet), "erro não identificado no modelo", cRet), CRLF, " ")

/*/{Protheus.doc} ErrDesc
Descrição do erro de execução com o primeiro ponto do ZIMPUSR na pilha (função e linha).
@type  Static Function
/*/
Static Function ErrDesc(oErr)
    Local aPilha := StrTokArr2(StrTran(oErr:ErrorStack, Chr(13), ""), Chr(10), .F.)
    Local cRet   := AllTrim(oErr:Description)
    Local nI     := 0

    For nI := 1 To Len(aPilha)
        If "ZIMPUSR.PRW" $ Upper(aPilha[nI])
            cRet += " | " + AllTrim(StrTran(aPilha[nI], "Called from", "em"))
            Exit
        EndIf
    Next nI
Return cRet

/*/{Protheus.doc} SubModelo
Devolve o submodelo pelo ID. Se não existir (ID diferente na versão do framework),
devolve Nil e preenche cMsg com os IDs disponíveis no modelo.
@type  Static Function
/*/
Static Function SubModelo(oModel, cId, cMsg)
    Local oSub  := oModel:GetModel(cId)
    Local aSubs := {}
    Local cIds  := ""
    Local bErro := Nil
    Local nI    := 0

    If ValType(oSub) == "O"
        Return oSub
    EndIf

    bErro := ErrorBlock({|e| Break(e)})
    Begin Sequence
        aSubs := oModel:GetAllSubModels()
        For nI := 1 To Len(aSubs)
            cIds += IIf(Empty(cIds), "", ", ") + aSubs[nI]:GetId()
        Next nI
    End Sequence
    ErrorBlock(bErro)
    cMsg := "submodelo " + cId + " não existe neste ambiente" + IIf(Empty(cIds), "", " (disponíveis: " + cIds + ")")
Return Nil

/*/{Protheus.doc} AchaSub
Procura em todos os submodelos o que tem o campo informado. Retorna o ID ou "".
@type  Static Function
/*/
Static Function AchaSub(oModel, cCampo)
    Local aSubs := {}
    Local cRet  := ""
    Local bErro := Nil
    Local nI    := 0

    bErro := ErrorBlock({|e| Break(e)})
    Begin Sequence
        aSubs := oModel:GetAllSubModels()
        For nI := 1 To Len(aSubs)
            If !Empty(InfoCampo(aSubs[nI], cCampo))
                cRet := aSubs[nI]:GetId()
                Exit
            EndIf
        Next nI
    End Sequence
    ErrorBlock(bErro)
Return cRet
