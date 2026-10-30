#include "totvs.ch"
#include "fwmvcdef.ch"

// Versão do importador: aparece na tela, no resumo e no log.
#Define ZIMPPRV_VERSAO "1.0.0"

// Colunas de operação do CSV e as palavras do menu que caem em cada uma (sem acento, maiúsculas).
// A ordem importa: as específicas vêm antes das genéricas (ex.: "Canc. Desdobr." é ESTORNAR, não EXCLUIR).
Static aColOps := {;
    {"ESTORNAR",     {"ESTORN", "CANCEL"}}, ;
    {"BAIXAR",       {"BAIX"}}, ;
    {"APROVAR",      {"APROV", "LIBER"}}, ;
    {"CONTABILIZAR", {"CONTAB"}}, ;
    {"IMPRIMIR",     {"IMPRIM", "RELAT", "EXPORT", "PLANILHA"}}, ;
    {"VISUALIZAR",   {"VISUAL", "PESQUIS", "LEGENDA", "CONSULT", "RASTR", "TRACKER", "HISTOR", "CONHEC"}}, ;
    {"INCLUIR",      {"INCLU", "COPIA"}}, ;
    {"ALTERAR",      {"ALTER"}}, ;
    {"EXCLUIR",      {"EXCLU", "ELIMIN", "DELET"}}}

/*/{Protheus.doc} ZIMPPRV
Importador de regras de privilégio (Configurador > Privilégios, CFGA530) a partir de CSV.

Grava pelo modelo MVC padrão do framework (FWRULESACCOUNTDATA), o mesmo do Configurador: checksum,
auditoria e validações ficam a cargo do Protheus. Ao informar a rotina, o modelo carrega os itens do
MenuDef DO AMBIENTE; o importador decide o acesso de cada item a partir das colunas do CSV.

Formato do CSV (separador ";", Windows-1252 ou UTF-8, uma linha por regra × rotina)
  REGRA         Código da regra (até 50). Linhas com a mesma REGRA formam uma regra só.
  DESCRICAO     Comentário da regra (até 150; vale o da primeira linha)
  ROTINA        Código da rotina (ex.: FINA050)
  VISUALIZAR, INCLUIR, ALTERAR, EXCLUIR, ESTORNAR, BAIXAR, APROVAR, IMPRIMIR, CONTABILIZAR
                S = Permitido, N ou vazio = Não permitido, X = Negado
  OUTRAS        Itens do menu pelo nome, quando a coluna não basta: "Eliminar acessos=S|Bloquear=N"

Como cada item do menu da rotina é classificado
  1. pelo nome informado em OUTRAS;
  2. pelas palavras do nome do item (Baixar, Aprovar/Liberar, Estornar/Cancelar, Imprimir/Relatório...);
  3. pela operação do item (1/2 = Visualizar, 3 = Incluir, 4 = Alterar, 5 = Excluir).
  Item que não cai em nenhuma coluna fica Não permitido e sai no log como SEM COLUNA, para conferência.
  A rotina (transação) fica Permitida quando algum item é permitido.

Ações: 1 = Incluir novas (existentes são ignoradas), 2 = Incluir novas e atualizar existentes,
       3 = Atualizar existentes. Na atualização, as rotinas da regra passam a ser exatamente as do arquivo.
Execução: simular (valida e gera o log sem gravar) ou gravar.

Log: \zimpprv\log\zimpprv_AAAAMMDD_HHMMSS.csv com a matriz item a item (o que cada regra vai permitir).

Uso
  U_ZIMPPRV  : tela (programa do SIGACFG). Exige administrador.
  U_ZIMPPRVJ : job/schedule (cArq, cUser, cPsw, cEmp, cFil, cModo 1/2/3, cSimula S/N)

Vincular as regras aos grupos: coluna PRIVILEGIOS da importação de grupos do ZIMPUSR.

@type  User Function
@author João Victor Guimarães Alves
@since 23/10/2026
/*/
User Function ZIMPPRV()
    Local aPergs := {}
    Local aResp  := {}
    Local aRet   := {}
    Local cArq   := ""

    If !FWIsAdmin(__cUserId)
        FWAlertError("Somente administradores podem importar regras de privilégio.", "ZIMPPRV")
        Return
    EndIf
    AAdd(aPergs, {6, "Arquivo CSV", Space(250), "", "", "", 140, .T., "Arquivos CSV (*.csv)|*.csv", "\zimpprv\entrada\", GETF_LOCALHARD + GETF_NETWORKDRIVE})
    AAdd(aPergs, {2, "Ação", 2, {"1=Incluir novas (ignora existentes)", "2=Incluir novas e atualizar existentes", "3=Atualizar existentes"}, 140, ".T.", .T.})
    AAdd(aPergs, {2, "Execução", 1, {"1=Simular e depois gravar (recomendado)", "2=Só simular (não grava)", "3=Gravar direto"}, 140, ".T.", .T.})
    If !ParamBox(aPergs, "Importação de regras de privilégio - ZIMPPRV " + ZIMPPRV_VERSAO, @aResp, , , , , , , , .F., .F.)
        Return
    EndIf
    cArq := ArqServid(AllTrim(aResp[1]))
    If Empty(cArq)
        Return
    EndIf
    If Num(aResp[3]) != 3
        aRet := Processa(cArq, Num(aResp[2]), .T.)
        MostraLog(aRet[2], "Simulação da importação de privilégios")
        If Num(aResp[3]) == 2 .Or. !aRet[1] .Or. !MsgYesNo("Simulação concluída. Gravar agora no ambiente " + GetEnvServer() + ", empresa " + cEmpAnt + "/" + cFilAnt + "?", "ZIMPPRV")
            Return
        EndIf
    EndIf
    aRet := Processa(cArq, Num(aResp[2]), .F.)
    MostraLog(aRet[2], "Resultado da importação de privilégios")
Return

/*/{Protheus.doc} ZIMPPRVJ
Importação de regras de privilégio sem interface.
@param cArq, caractere, Arquivo no servidor (ex.: \zimpprv\entrada\privilegios.csv)
@param cUser, caractere, Usuário administrador
@param cPwd, caractere, Senha
@param cEmp, caractere, Grupo de empresas (padrão 99)
@param cFil, caractere, Filial (padrão 01)
@param cModo, caractere, 1 = incluir novas, 2 = incluir e atualizar, 3 = só atualizar (padrão 2)
@param cSimula, caractere, S = só valida (padrão N)
@return array, {lOk, cResumo, cArqLog}
@type  User Function
@author João Victor Guimarães Alves
/*/
User Function ZIMPPRVJ(cArq, cUser, cPwd, cEmp, cFil, cModo, cSimula)
    Local lAbriu := .F.
    Local aRet   := {.F., "", ""}

    Default cEmp := "99"
    Default cFil := "01"
    Default cModo := "2"
    Default cSimula := "N"
    If Type("cEmpAnt") != "C"
        RpcSetType(3)
        If !RpcSetEnv(cEmp, cFil, cUser, cPwd, "CFG", "ZIMPPRVJ")
            ConOut("ZIMPPRV " + ZIMPPRV_VERSAO + ": falha ao abrir o ambiente " + cEmp + "/" + cFil)
            Return aRet
        EndIf
        lAbriu := .T.
    EndIf
    If !FWIsAdmin(__cUserId)
        ConOut("ZIMPPRV " + ZIMPPRV_VERSAO + ": o usuário não é administrador.")
    Else
        aRet := Processa(cArq, Val(cModo), AScan({"S", "SIM", "1"}, Upper(AllTrim(cSimula))) > 0)
        ConOut("ZIMPPRV " + ZIMPPRV_VERSAO + ": " + aRet[2])
    EndIf
    If lAbriu
        RpcClearEnv()
    EndIf
Return aRet

/*/{Protheus.doc} ZIMPPRVV
Versão do ZIMPPRV compilada no ambiente.
@type  User Function
@author João Victor Guimarães Alves
/*/
User Function ZIMPPRVV()
    If Type("oMainWnd") == "O"
        FWAlertInfo("ZIMPPRV versão " + ZIMPPRV_VERSAO, "ZIMPPRV")
    Else
        ConOut("ZIMPPRV versão " + ZIMPPRV_VERSAO)
    EndIf
Return ZIMPPRV_VERSAO

// ---------------------------------------------------------------------------
// Processamento
// ---------------------------------------------------------------------------

Static Function Processa(cArq, nModo, lSimula)
    Local aLin    := LeCsv(cArq)
    Local aCab    := {}
    Local aRegras := {}
    Local nI      := 0
    Local nPos    := 0
    Local nOk     := 0
    Local nErro   := 0
    Local nIgn    := 0
    Local nSemCol := 0
    Local aRes    := {}
    Local aErros  := {}
    Local nHdl    := -1
    Local cArqLog := ""
    Local cTexto  := ""
    Local nIni    := Seconds()

    If Len(aLin) < 2
        Return {.F., "Arquivo vazio ou não encontrado: " + cArq, ""}
    EndIf
    aCab := aLin[1]
    For nI := 1 To Len(aCab)
        aCab[nI] := Upper(AllTrim(aCab[nI]))
    Next nI
    If AScan(aCab, "REGRA") == 0 .Or. AScan(aCab, "ROTINA") == 0
        Return {.F., "O cabeçalho precisa ter as colunas REGRA e ROTINA.", ""}
    EndIf

    // agrupa as linhas por regra, na ordem do arquivo
    For nI := 2 To Len(aLin)
        If Empty(Col(aCab, aLin[nI], "REGRA")) .And. Empty(Col(aCab, aLin[nI], "ROTINA"))
            Loop
        EndIf
        nPos := AScan(aRegras, {|x| x[1] == Upper(AllTrim(Col(aCab, aLin[nI], "REGRA")))})
        If nPos == 0
            AAdd(aRegras, {Upper(AllTrim(Col(aCab, aLin[nI], "REGRA"))), AllTrim(Col(aCab, aLin[nI], "DESCRICAO")), {}})
            nPos := Len(aRegras)
        EndIf
        AAdd(aRegras[nPos][3], {nI, aLin[nI]})
    Next nI

    nHdl := LogAbre(@cArqLog)
    For nI := 1 To Len(aRegras)
        aRes := GravaRegra(aRegras[nI], aCab, nModo, lSimula, nHdl, @nSemCol)
        Do Case
            Case aRes[1] == "OK"
                nOk++
            Case aRes[1] == "IGNORADO"
                nIgn++
            Otherwise
                nErro++
                AAdd(aErros, aRegras[nI][1] + ": " + aRes[2])
        EndCase
    Next nI
    If nHdl >= 0
        FClose(nHdl)
    EndIf

    cTexto := "Importação de REGRAS DE PRIVILÉGIO - ZIMPPRV " + ZIMPPRV_VERSAO + CRLF
    cTexto += "Arquivo: " + cArq + CRLF
    cTexto += "Ação: " + {"incluir novas", "incluir novas e atualizar existentes", "atualizar existentes"}[Max(1, Min(nModo, 3))] + ;
        IIf(lSimula, " | SIMULAÇÃO (nada foi gravado)", "") + CRLF
    cTexto += "Regras: " + cValToChar(Len(aRegras)) + " | Sucesso: " + cValToChar(nOk) + " | Erros: " + cValToChar(nErro) + ;
        " | Ignoradas: " + cValToChar(nIgn) + CRLF
    cTexto += "Itens de menu sem coluna (ficaram Não permitido): " + cValToChar(nSemCol) + " - confira no log" + CRLF
    cTexto += "Tempo: " + cValToChar(Round(Seconds() - nIni, 1)) + " s" + CRLF
    cTexto += "Log completo (matriz item a item): " + cArqLog + CRLF
    If Len(aErros) > 0
        cTexto += CRLF + "ERROS:" + CRLF
        AEval(aErros, {|x| cTexto += x + CRLF})
    EndIf
Return {nErro == 0, cTexto, cArqLog}

/** Inclui ou atualiza uma regra com as rotinas do arquivo. Devolve {status, mensagem}. */
Static Function GravaRegra(aRegra, aCab, nModo, lSimula, nHdl, nSemCol)
    Local cCod   := aRegra[1]
    Local aExist := BuscaRegra(cCod)
    Local lExist := !Empty(aExist[1])
    Local oModel := Nil
    Local oTr    := Nil
    Local oMn    := Nil
    Local cAli   := ""
    Local nI     := 0
    Local nJ     := 0
    Local aRot   := {}
    Local cRot   := ""
    Local aLinha := {}
    Local aAces  := {}
    Local lAlguma := .F.
    Local cMsg   := ""
    Local lOk    := .T.
    Local bErro  := Nil

    If Len(cCod) > 50
        Return Loga(nHdl, cCod, "", "", "", "", "ERRO", "Código com mais de 50 caracteres.")
    EndIf
    If lExist .And. nModo == 1
        Return Loga(nHdl, cCod, "", "", "", "", "IGNORADO", "Regra já existe (ação 1 = só incluir).")
    EndIf
    If !lExist .And. nModo == 3
        Return Loga(nHdl, cCod, "", "", "", "", "IGNORADO", "Regra não existe (ação 3 = só atualizar).")
    EndIf

    oModel := FWLoadModel("FWRULESACCOUNTDATA")
    If lExist
        cAli := oModel:GetModel("DATARULE"):GetStruct():GetTable()[1]
        If Select(cAli) == 0
            MPRulesOpenTable()
        EndIf
        (cAli)->(DbGoTo(aExist[2]))
        oModel:Cargo := {aExist[2], aExist[1], .F.}
        oModel:SetOperation(MODEL_OPERATION_UPDATE)
    Else
        oModel:SetOperation(MODEL_OPERATION_INSERT)
    EndIf
    If !oModel:Activate()
        cMsg := ErroModelo(oModel)
        oModel:Destroy()
        Return Loga(nHdl, cCod, "", "", "", "", "ERRO", "Falha ao ativar o modelo: " + cMsg)
    EndIf
    // trava de segurança: na atualização, o modelo tem de ter carregado exatamente esta regra
    If lExist .And. (oModel:GetValue("DATARULE", "RL__ID") != aExist[1] .Or. Upper(AllTrim(oModel:GetValue("DATARULE", "RL__CODIGO"))) != cCod)
        cMsg := "Modelo carregou a regra " + oModel:GetValue("DATARULE", "RL__ID") + " em vez de " + aExist[1] + ". Nada foi gravado."
        oModel:DeActivate()
        oModel:Destroy()
        Return Loga(nHdl, cCod, "", "", "", "", "ERRO", cMsg)
    EndIf

    bErro := ErrorBlock({|e| cMsg := "Erro de execução: " + e:Description, lOk := .F., Break(e)})
    Begin Sequence
        If !lExist
            lOk := oModel:SetValue("DATARULE", "RL__CODIGO", cCod)
        EndIf
        If lOk .And. !Empty(aRegra[2])
            lOk := oModel:SetValue("DATARULE", "RL__DESCRI", Left(aRegra[2], 150))
        EndIf
        oTr := oModel:GetModel("DATATRANSACTION")
        oMn := oModel:GetModel("DATAMENUDEF")

        // rotinas do arquivo (sem repetir)
        For nI := 1 To Len(aRegra[3])
            cRot := Upper(AllTrim(Col(aCab, aRegra[3][nI][2], "ROTINA")))
            If !Empty(cRot) .And. AScan(aRot, {|x| x[1] == cRot}) == 0
                AAdd(aRot, {cRot, aRegra[3][nI][2]})
            EndIf
        Next nI

        // na atualização, tira as rotinas que não estão mais no arquivo
        If lOk .And. lExist
            For nI := 1 To oTr:Length()
                oTr:GoLine(nI)
                If !oTr:IsDeleted() .And. AScan(aRot, {|x| x[1] == Upper(AllTrim(oTr:GetValue("RL__ROTINA")))}) == 0
                    Loga(nHdl, cCod, AllTrim(oTr:GetValue("RL__ROTINA")), "", "", "", "REMOVIDA", "Rotina saiu da regra.")
                    oTr:DeleteLine()
                EndIf
            Next nI
        EndIf

        For nI := 1 To Len(aRot)
            If !lOk
                Exit
            EndIf
            cRot := aRot[nI][1]
            aLinha := aRot[nI][2]
            If !(lExist .And. oTr:SeekLine({{"RL__ROTINA", cRot}}))
                If !(oTr:Length() == 1 .And. Empty(oTr:GetValue("RL__ROTINA")))
                    If oTr:AddLine() <= 0 .Or. !Empty(oTr:GetValue("RL__ROTINA"))
                        cMsg := "Rotina " + cRot + ": não foi possível abrir uma linha nova. " + ErroModelo(oModel)
                        lOk := .F.
                        Exit
                    EndIf
                EndIf
                If !FindFunction(cRot)
                    Loga(nHdl, cCod, cRot, "", "", "", "AVISO", "Rotina não encontrada no RPO deste ambiente; confira o código.")
                EndIf
                If !oTr:SetValue("RL__ROTINA", cRot)
                    cMsg := "Rotina " + cRot + ": " + ErroModelo(oModel)
                    lOk := .F.
                    Exit
                EndIf
            EndIf
            lAlguma := .F.
            If SemMenu(oMn)
                // rotina sem MenuDef (relatório, processo): vale só o acesso à rotina, pela coluna VISUALIZAR
                lAlguma := Acesso(Col(aCab, aLinha, "VISUALIZAR")) == "1" .Or. AScan({"INCLUIR", "ALTERAR", "IMPRIMIR", "OUTRAS"}, ;
                    {|c| Acesso(Col(aCab, aLinha, c)) == "1" .Or. (c == "OUTRAS" .And. "=S" $ Upper(StrTran(Col(aCab, aLinha, c), " ", "")))}) > 0
                Loga(nHdl, cCod, cRot, "", "", "ROTINA", IIf(lAlguma, "Permitido", "Não permitido"), ;
                    "Rotina sem itens de menu (MenuDef) neste ambiente: vale só o acesso à rotina.")
            EndIf
            For nJ := 1 To IIf(SemMenu(oMn), 0, oMn:Length())
                oMn:GoLine(nJ)
                aAces := Classifica(aCab, aLinha, AllTrim(oMn:GetValue("RL__DESMDEF")), oMn:GetValue("RL__MENUOPER"))
                If aAces[2] == "SEM COLUNA"
                    nSemCol++
                EndIf
                lAlguma := lAlguma .Or. aAces[1] == "1"
                If !oMn:SetValue("RL__ACESSO", aAces[1])
                    cMsg := "Rotina " + cRot + ", item " + AllTrim(oMn:GetValue("RL__DESMDEF")) + ": " + ErroModelo(oModel)
                    lOk := .F.
                    Exit
                EndIf
                Loga(nHdl, cCod, cRot, cValToChar(nJ) + " " + AllTrim(oMn:GetValue("RL__DESMDEF")), cValToChar(oMn:GetValue("RL__MENUOPER")), ;
                    aAces[2], {"Permitido", "Não permitido", "Negado"}[Val(aAces[1])], aAces[3])
            Next nJ
            If lOk
                lOk := oTr:SetValue("RL__ACESSO", IIf(lAlguma, "1", "2"))
            EndIf
        Next nI

        If lOk
            lOk := oModel:VldData()
            If lOk .And. !lSimula
                lOk := oModel:CommitData()
            EndIf
            If !lOk
                cMsg := ErroModelo(oModel)
            EndIf
        EndIf
    Recover
        lOk := .F.
    End Sequence
    ErrorBlock(bErro)
    oModel:DeActivate()
    oModel:Destroy()

    If !lOk
        Return Loga(nHdl, cCod, "", "", "", "", "ERRO", cMsg)
    EndIf
Return Loga(nHdl, cCod, "", "", "", "", "OK", IIf(lSimula, "Simulação OK", IIf(lExist, "Atualizada", "Incluída")) + ;
    " com " + cValToChar(Len(aRot)) + " rotina(s).")

/** Decide o acesso de um item do menu: {acesso "1"/"2"/"3", coluna usada, observação}. */
Static Function Classifica(aCab, aLinha, cDesc, nOper)
    Local cNome  := Simples(cDesc)
    Local aOut   := Tokens(Col(aCab, aLinha, "OUTRAS"), "|")
    Local nI     := 0
    Local nJ     := 0
    Local cPar   := ""
    Local cVal   := ""
    Local cCol   := ""

    // 1) nome informado em OUTRAS ("Eliminar acessos=S")
    For nI := 1 To Len(aOut)
        If "=" $ aOut[nI]
            cPar := Simples(Left(aOut[nI], At("=", aOut[nI]) - 1))
            cVal := AllTrim(SubStr(aOut[nI], At("=", aOut[nI]) + 1))
            If !Empty(cPar) .And. (cPar $ cNome .Or. cNome $ cPar)
                Return {Acesso(cVal), "OUTRAS", "pelo nome (" + AllTrim(Left(aOut[nI], At("=", aOut[nI]) - 1)) + ")"}
            EndIf
        EndIf
    Next nI
    // 2) palavras do nome do item
    For nI := 1 To Len(aColOps)
        For nJ := 1 To Len(aColOps[nI][2])
            If aColOps[nI][2][nJ] $ cNome
                cCol := aColOps[nI][1]
                Return {Acesso(Col(aCab, aLinha, cCol)), cCol, "pelo nome do item"}
            EndIf
        Next nJ
    Next nI
    // 3) operação do item
    Do Case
        Case nOper == 1 .Or. nOper == 2
            cCol := "VISUALIZAR"
        Case nOper == 3
            cCol := "INCLUIR"
        Case nOper == 4
            cCol := "ALTERAR"
        Case nOper == 5
            cCol := "EXCLUIR"
    EndCase
    If !Empty(cCol)
        Return {Acesso(Col(aCab, aLinha, cCol)), cCol, "pela operação " + cValToChar(nOper)}
    EndIf
Return {"2", "SEM COLUNA", "Nenhuma coluna corresponde: ficou Não permitido. Informe em OUTRAS se precisar."}

/** Grade de menu vazia (só a linha em branco que o modelo cria). */
Static Function SemMenu(oMn)
    If oMn:IsEmpty() .Or. oMn:Length() == 0
        Return .T.
    EndIf
    oMn:GoLine(1)
Return oMn:Length() == 1 .And. Empty(oMn:GetValue("RL__DESMDEF"))

/** S = 1 Permitido, X/NEGADO = 3 Negado, demais = 2 Não permitido. */
Static Function Acesso(cVal)
    cVal := Upper(AllTrim(cVal))
    Do Case
        Case Left(cVal, 1) == "S"
            Return "1"
        Case cVal == "X" .Or. Left(cVal, 3) == "NEG"
            Return "3"
    EndCase
Return "2"

/** {RL__ID, R_E_C_N_O_} da regra pelo código; {"", 0} se não existe. */
Static Function BuscaRegra(cCod)
    Local cAli := GetNextAlias()
    Local aRet := {"", 0}
    MPSysOpenQuery("SELECT RL__ID, R_E_C_N_O_ RECNO FROM SYS_RULES WHERE D_E_L_E_T_ = ' ' AND UPPER(RTRIM(RL__CODIGO)) = '" + ;
        StrTran(cCod, "'", "''") + "'", cAli)
    If !(cAli)->(Eof())
        aRet := {(cAli)->RL__ID, (cAli)->RECNO}
    EndIf
    (cAli)->(DbCloseArea())
Return aRet

// ---------------------------------------------------------------------------
// CSV, log e utilidades
// ---------------------------------------------------------------------------

/** Lê o CSV (Windows-1252 ou UTF-8) e devolve as linhas já separadas em colunas (aceita aspas). */
Static Function LeCsv(cArq)
    Local cTxt  := MemoRead(cArq)
    Local aRet  := {}
    Local aL    := {}
    Local nI    := 0

    If Empty(cTxt)
        Return aRet
    EndIf
    If Left(cTxt, 3) == Chr(239) + Chr(187) + Chr(191)
        cTxt := DecodeUTF8(SubStr(cTxt, 4))
    ElseIf DecodeUTF8(cTxt) != Nil .And. !(DecodeUTF8(cTxt) == cTxt)
        cTxt := DecodeUTF8(cTxt)
    EndIf
    aL := StrTokArr2(StrTran(cTxt, Chr(13), ""), Chr(10), .T.)
    For nI := 1 To Len(aL)
        If !Empty(aL[nI])
            AAdd(aRet, Separa(aL[nI]))
        EndIf
    Next nI
Return aRet

Static Function Separa(cLin)
    Local aCol  := {}
    Local cAtu  := ""
    Local lAsp  := .F.
    Local nI    := 0
    Local cC    := ""
    For nI := 1 To Len(cLin)
        cC := SubStr(cLin, nI, 1)
        Do Case
            Case cC == '"' .And. lAsp .And. SubStr(cLin, nI + 1, 1) == '"'
                cAtu += '"'
                nI++
            Case cC == '"'
                lAsp := !lAsp
            Case cC == ";" .And. !lAsp
                AAdd(aCol, cAtu)
                cAtu := ""
            Otherwise
                cAtu += cC
        EndCase
    Next nI
    AAdd(aCol, cAtu)
Return aCol

Static Function Col(aCab, aLinha, cNome)
    Local nPos := AScan(aCab, cNome)
Return IIf(nPos > 0 .And. nPos <= Len(aLinha), AllTrim(aLinha[nPos]), "")

Static Function Tokens(cTxt, cSep)
    Local aRet := {}
    If !Empty(cTxt)
        aRet := StrTokArr2(cTxt, cSep, .F.)
    EndIf
Return aRet

Static Function Simples(cTxt)
Return Upper(AllTrim(StrTran(FwNoAccent(cTxt), "&", "")))

Static Function Num(xVal)
Return IIf(ValType(xVal) == "N", xVal, Val(Left(cValToChar(xVal), 1)))

Static Function LogAbre(cArq)
    Local cDir := "\zimpprv\log\"
    Local nHdl := -1
    FWMakeDir(cDir, .F.)
    cArq := cDir + "zimpprv_" + DToS(Date()) + "_" + StrTran(Time(), ":", "") + ".csv"
    nHdl := FCreate(cArq)
    FWrite(nHdl, "REGRA;ROTINA;ITEM DO MENU;OPERACAO;COLUNA;ACESSO;MENSAGEM" + CRLF)
Return nHdl

/** Grava uma linha no log e devolve {status, mensagem} (para as linhas de resultado da regra). */
Static Function Loga(nHdl, cRegra, cRot, cItem, cOper, cCol, cStatus, cMsg)
    If nHdl >= 0
        FWrite(nHdl, cRegra + ";" + cRot + ";" + StrTran(cItem, ";", ",") + ";" + cOper + ";" + cCol + ";" + cStatus + ";" + ;
            StrTran(StrTran(cMsg, ";", ","), CRLF, " ") + CRLF)
    EndIf
Return {cStatus, cMsg}

Static Function ErroModelo(oModel)
    Local aErro := oModel:GetErrorMessage()
Return AllTrim(cValToChar(aErro[4]) + " " + cValToChar(aErro[6]) + " " + cValToChar(aErro[7]))

Static Function ArqServid(cArq)
    Local cDir  := "\zimpprv\entrada\"
    Local cNome := SubStr(cArq, RAt(IIf("\" $ cArq, "\", "/"), cArq) + 1)
    If Left(cArq, 1) == "\" .And. File(cArq)
        Return cArq
    EndIf
    FWMakeDir(cDir, .F.)
    If !CpyT2S(cArq, cDir, .F.)
        FWAlertError("Não foi possível copiar o arquivo para o servidor: " + cArq, "ZIMPPRV")
        Return ""
    EndIf
Return cDir + cNome

Static Function MostraLog(cTexto, cTitulo)
    Local oDlg  := Nil
    Local oFont := TFont():New("Courier New", , 16)
    DEFINE MSDIALOG oDlg TITLE cTitulo FROM 0, 0 TO 520, 960 PIXEL
    TMultiGet():New(5, 5, {|u| IIf(PCount() > 0, cTexto := u, cTexto)}, oDlg, 470, 225, oFont, , , , , .T., , , , , , .T.)
    TButton():New(235, 420, "Fechar", oDlg, {|| oDlg:End()}, 50, 15, , , , .T.)
    ACTIVATE MSDIALOG oDlg CENTERED
Return
