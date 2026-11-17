#include "totvs.ch"

// Históricos do Funcionário (ZHF) - tipo 09 Auxílio creche/financeiro gravado
// automaticamente a partir do cadastro de Dependentes (SRB).
#Define AUX_TIPO    "09"
#Define AUX_ATIVOS  "1|2|3|4"   // RB_XCRECHE: 1=Creche;2=Creche judicial;3=Financeiro;4=Financeiro judicial
                                // 5=Não optante e 6=Excluído (ou vazio) = sem auxílio

/*/{Protheus.doc} CBXAUXG
Sincroniza o histórico tipo 09 (Auxílio creche/financeiro) de um funcionário com o
auxílio cadastrado em cada dependente (SRB: RB_XCRECHE, RB_DTINAUX, RB_DTFIAUX).
Compara, por dependente, o cadastro com o último histórico tipo 09 DAQUELE dependente:
- auxílio sem histórico: inclui linha nova (Data Inicial/Final do dependente);
- tipo de auxílio mudou: inclui linha nova e fecha a anterior na Data Inicial da nova;
- mesmo tipo, só as datas mudaram: acerta as datas da última linha (com auditoria);
- mesmo tipo, novo período (Data Inicial depois da Data Final do último): linha nova;
- auxílio retirado (vazio, 5=Não optante, 6=Excluído) ou dependente excluído: fecha
  a última linha (Data Final do dependente, ou a data base quando vazia).
Na carga inicial (origem 3) só inclui para dependentes que ainda não têm histórico.
Chamado pelo PE do cadastro de Dependentes (GPEA020, MODELCOMMITNTTS) e pela carga
inicial (CBGPEM13). Não abre tela: o Número do processo dos auxílios judiciais é
completado depois na rotina de Históricos.
@type user function
@author João Victor Guimarães Alves
@since 17/11/2026
@param cOrigem, character, 2=Automática (cadastro de dependentes) ou 3=Carga inicial
@param cFilFun, character, filial do funcionário (opcional; padrão SRA posicionada)
@param cMatFun, character, matrícula do funcionário (opcional; padrão SRA posicionada)
@return numeric, quantidade de linhas incluídas ou alteradas
/*/
User Function CBXAUXG(cOrigem as Character, cFilFun as Character, cMatFun as Character) as Numeric
    Local nGrav    := 0 as Numeric
    Local nI       := 0 as Numeric
    Local aArea    := GetArea() as Array
    Local aAreaZH  := {} as Array
    Local aAreaRB  := {} as Array
    Local cFilZHF  := "" as Character
    Local cFilSRB  := "" as Character
    Local aDeps    := {} as Array
    Local aUsr     := {} as Array

    If !FWAliasInDic("ZHF") .Or. SRB->(FieldPos("RB_XCRECHE")) == 0
        Return nGrav
    EndIf

    Default cOrigem := "2"
    If Empty(cFilFun) .Or. Empty(cMatFun)
        cFilFun := SRA->RA_FILIAL
        cMatFun := SRA->RA_MAT
    EndIf
    If Empty(cMatFun)
        Return nGrav
    EndIf

    aAreaZH := ZHF->(GetArea())
    aAreaRB := SRB->(GetArea())
    cFilZHF := xFilial("ZHF", cFilFun)
    cFilSRB := xFilial("SRB", cFilFun)
    aUsr    := U_CBXHISU()

    // {cDepend, lNoCadastro, cTpAux, dIni, dFim, nRecZHF (último histórico do dependente)}
    aDeps := Dependentes(cFilSRB, cMatFun)
    UltimosHist(cFilZHF, cMatFun, aDeps)

    For nI := 1 To Len(aDeps)
        nGrav += SincDep(cOrigem, cFilZHF, cMatFun, aDeps[nI], aUsr)
    Next nI

    RestArea(aAreaRB)
    RestArea(aAreaZH)
    RestArea(aArea)
Return nGrav

/*/{Protheus.doc} Dependentes
Lê os dependentes do funcionário na SRB com o auxílio cadastrado.
@type static function
@author João Victor Guimarães Alves
@since 17/11/2026
@param cFilSRB, character, filial da SRB
@param cMat, character, matrícula
@return array, {{cDepend, .T., cTpAux, dIni, dFim, 0}, ...}
/*/
Static Function Dependentes(cFilSRB as Character, cMat as Character) as Array
    Local aDeps  := {} as Array
    Local cTpAux := "" as Character

    SRB->(DbSetOrder(1)) // RB_FILIAL+RB_MAT+RB_COD
    SRB->(DbSeek(cFilSRB + cMat))
    While !SRB->(Eof()) .And. SRB->(RB_FILIAL + RB_MAT) == cFilSRB + cMat
        cTpAux := AllTrim(SRB->RB_XCRECHE)
        If !(cTpAux $ AUX_ATIVOS) .Or. Empty(cTpAux)
            cTpAux := ""
        EndIf
        aAdd(aDeps, {SRB->RB_COD, .T., cTpAux, SRB->RB_DTINAUX, SRB->RB_DTFIAUX, 0})
        SRB->(DbSkip())
    EndDo
Return aDeps

/*/{Protheus.doc} UltimosHist
Acha o último histórico tipo 09 de cada dependente (maior sequência). Dependentes
que só existem no histórico (excluídos do cadastro) entram na lista sem cadastro.
@type static function
@author João Victor Guimarães Alves
@since 17/11/2026
@param cFilZHF, character, filial da ZHF
@param cMat, character, matrícula
@param aDeps, array, lista de Dependentes() (alterada por referência)
/*/
Static Function UltimosHist(cFilZHF as Character, cMat as Character, aDeps as Array)
    Local cChave := cFilZHF + cMat + AUX_TIPO as Character
    Local nPos   := 0 as Numeric

    ZHF->(DbSetOrder(1)) // ZHF_FILIAL+ZHF_MAT+ZHF_TIPO+ZHF_SEQ
    ZHF->(DbSeek(cChave))
    While !ZHF->(Eof()) .And. ZHF->(ZHF_FILIAL + ZHF_MAT + ZHF_TIPO) == cChave
        If !Empty(ZHF->ZHF_DEPEND)
            nPos := aScan(aDeps, {|x| x[1] == ZHF->ZHF_DEPEND})
            If nPos == 0
                aAdd(aDeps, {ZHF->ZHF_DEPEND, .F., "", CToD(""), CToD(""), 0})
                nPos := Len(aDeps)
            EndIf
            aDeps[nPos][6] := ZHF->(Recno()) // ordem crescente de sequência: fica o último
        EndIf
        ZHF->(DbSkip())
    EndDo
Return

/*/{Protheus.doc} SincDep
Compara o auxílio de um dependente com o último histórico dele e grava o que mudou.
@type static function
@author João Victor Guimarães Alves
@since 17/11/2026
@param cOrigem, character, 2=Automática ou 3=Carga inicial
@param cFilZHF, character, filial da ZHF
@param cMat, character, matrícula
@param aDep, array, item de Dependentes()
@param aUsr, array, retorno de U_CBXHISU
@return numeric, linhas incluídas ou alteradas
/*/
Static Function SincDep(cOrigem as Character, cFilZHF as Character, cMat as Character, aDep as Array, aUsr as Array) as Numeric
    Local nGrav   := 0 as Numeric
    Local cDep    := aDep[1] as Character
    Local cTpAux  := aDep[3] as Character
    Local dIni    := aDep[4] as Date
    Local dFim    := aDep[5] as Date
    Local nRec    := aDep[6] as Numeric
    Local lTemHis := (nRec > 0) as Logical
    Local cTpAnt  := "" as Character
    Local dIniAnt := CToD("") as Date
    Local dFimAnt := CToD("") as Date
    Local dFecha  := CToD("") as Date
    Local cDet    := "" as Character

    If lTemHis
        ZHF->(DbGoTo(nRec))
        cTpAnt  := AllTrim(ZHF->ZHF_TPAUX)
        dIniAnt := ZHF->ZHF_DATA
        dFimAnt := ZHF->ZHF_DTFIM
    EndIf

    // Carga inicial: só quem tem auxílio e ainda não tem histórico
    If cOrigem == "3"
        If !lTemHis .And. !Empty(cTpAux)
            nGrav += Inclui(cOrigem, cFilZHF, cMat, cDep, cTpAux, IIf(Empty(dIni), dDataBase, dIni), dFim, aUsr)
        EndIf
        Return nGrav
    EndIf

    Do Case
        // Sem auxílio no cadastro (ou dependente excluído): fecha a última linha aberta
        Case Empty(cTpAux)
            If lTemHis
                dFecha := IIf(aDep[2] .And. !Empty(dFim), dFim, dDataBase)
                If dFecha < dIniAnt
                    dFecha := dIniAnt
                EndIf
                If Empty(dFimAnt) .Or. dFimAnt > dFecha
                    cDet := IIf(aDep[2], "auxílio retirado no cadastro de dependentes", "dependente excluído do cadastro")
                    nGrav += AjustaDatas(nRec, dIniAnt, dFecha, aUsr, cDet)
                EndIf
            EndIf

        // Primeiro auxílio do dependente
        Case !lTemHis
            nGrav += Inclui(cOrigem, cFilZHF, cMat, cDep, cTpAux, IIf(Empty(dIni), dDataBase, dIni), dFim, aUsr)

        // Mudou o tipo de auxílio, ou é um novo período depois do último encerrado
        Case cTpAux <> cTpAnt .Or. (!Empty(dFimAnt) .And. !Empty(dIni) .And. dIni > dFimAnt)
            If Empty(dIni)
                dIni := dDataBase
            EndIf
            nGrav += Inclui(cOrigem, cFilZHF, cMat, cDep, cTpAux, dIni, dFim, aUsr)
            // Data Final do anterior = Data Inicial do novo (regra do cliente, 10/11/2026)
            If (Empty(dFimAnt) .Or. dFimAnt > dIni) .And. dIniAnt <= dIni
                cDet := "fechado pelo histórico novo do dependente " + cDep
                nGrav += AjustaDatas(nRec, dIniAnt, dIni, aUsr, cDet)
            EndIf

        // Mesmo auxílio: acerta as datas se mudaram no cadastro
        Otherwise
            If (!Empty(dIni) .And. dIni <> dIniAnt) .Or. dFim <> dFimAnt
                nGrav += AjustaDatas(nRec, IIf(Empty(dIni), dIniAnt, dIni), dFim, aUsr, ;
                    "datas do auxílio alteradas no cadastro de dependentes")
            EndIf
    EndCase
Return nGrav

/*/{Protheus.doc} Inclui
Inclui uma linha de histórico tipo 09 para o dependente e grava a auditoria.
@type static function
@author João Victor Guimarães Alves
@since 17/11/2026
@return numeric, 1 quando gravou
/*/
Static Function Inclui(cOrigem as Character, cFilZHF as Character, cMat as Character, cDep as Character, ;
        cTpAux as Character, dIni as Date, dFim as Date, aUsr as Array) as Numeric
    Local cSeq := U_CBXHISS(cFilZHF, cMat, AUX_TIPO) as Character
    Local cDet := "" as Character

    If !Empty(dFim) .And. dFim < dIni
        dFim := CToD("")
    EndIf

    RecLock("ZHF", .T.)
    ZHF->ZHF_FILIAL := cFilZHF
    ZHF->ZHF_MAT    := cMat
    ZHF->ZHF_TIPO   := AUX_TIPO
    ZHF->ZHF_SEQ    := cSeq
    ZHF->ZHF_DATA   := dIni
    ZHF->ZHF_DTFIM  := dFim
    ZHF->ZHF_TPAUX  := cTpAux
    ZHF->ZHF_DEPEND := cDep
    ZHF->ZHF_ORIGEM := cOrigem
    ZHF->ZHF_USER   := aUsr[2]
    ZHF->ZHF_DTINC  := Date()
    ZHF->ZHF_HRINC  := Time()
    GravaCampo("ZHF_CODUSR", aUsr[1])
    GravaCampo("ZHF_MATINC", aUsr[3])
    ZHF->(MsUnlock())

    cDet := IIf(cOrigem == "3", "Carga inicial. ", "Cadastro de dependentes. ") + ;
        "Dependente " + cDep + ": " + U_CBXHISD(AUX_TIPO, "", "", cTpAux) + ;
        ". Data Inicial " + U_CBXHISB(dIni) + IIf(Empty(dFim), "", ", Data Final " + U_CBXHISB(dFim))
    U_CBXHISA(cFilZHF, cMat, AUX_TIPO, cSeq, "1", cDet)
Return 1

/*/{Protheus.doc} AjustaDatas
Altera Data Inicial/Data Final de uma linha da ZHF e grava a auditoria.
@type static function
@author João Victor Guimarães Alves
@since 17/11/2026
@param nRec, numeric, Recno da ZHF
@param dIni, date, Data Inicial nova
@param dFim, date, Data Final nova
@param aUsr, array, retorno de U_CBXHISU
@param cMotivo, character, motivo para o log
@return numeric, 1 quando alterou
/*/
Static Function AjustaDatas(nRec as Numeric, dIni as Date, dFim as Date, aUsr as Array, cMotivo as Character) as Numeric
    Local dIniAnt := CToD("") as Date
    Local dFimAnt := CToD("") as Date
    Local cDet    := "" as Character

    ZHF->(DbGoTo(nRec))
    dIniAnt := ZHF->ZHF_DATA
    dFimAnt := ZHF->ZHF_DTFIM
    If !Empty(dFim) .And. dFim < dIni
        dFim := dIni
    EndIf
    If dIniAnt == dIni .And. dFimAnt == dFim
        Return 0
    EndIf

    RecLock("ZHF", .F.)
    ZHF->ZHF_DATA  := dIni
    ZHF->ZHF_DTFIM := dFim
    U_CBXHISZ(aUsr)
    ZHF->(MsUnlock())

    If dIniAnt <> dIni
        cDet += "Data Inicial: " + U_CBXHISB(dIniAnt) + " -> " + U_CBXHISB(dIni) + "; "
    EndIf
    If dFimAnt <> dFim
        cDet += "Data Final: " + U_CBXHISB(dFimAnt) + " -> " + U_CBXHISB(dFim) + "; "
    EndIf
    cDet := Left(cDet, Len(cDet) - 2) + " (" + cMotivo + ")"
    U_CBXHISA(ZHF->ZHF_FILIAL, ZHF->ZHF_MAT, ZHF->ZHF_TIPO, ZHF->ZHF_SEQ, "2", cDet)
Return 1

/*/{Protheus.doc} GravaCampo
Grava o campo na ZHF (já travada) só se ele existir no dicionário.
@type static function
@author João Victor Guimarães Alves
@since 17/11/2026
@param cCampo, character, nome do campo
@param xValor, variant, conteúdo
/*/
Static Function GravaCampo(cCampo as Character, xValor as Variant)
    Local nPos := ZHF->(FieldPos(cCampo)) as Numeric

    If nPos > 0
        ZHF->(FieldPut(nPos, xValor))
    EndIf
Return

/*/{Protheus.doc} CBXAUXP
Chamada do ponto de entrada do cadastro de Dependentes (User Function GPEA020,
momento MODELCOMMITNTTS, depois da gravação). Protegida: um erro aqui não
desfaz nem bloqueia a gravação dos dependentes; fica registrado no console.log.
@type user function
@author João Victor Guimarães Alves
@since 17/11/2026
@param oModel, object, modelo do GPEA020 (PARAMIXB[1])
@return numeric, linhas gravadas
/*/
User Function CBXAUXP(oModel as Object) as Numeric
    Local nGrav  := 0 as Numeric
    Local cFil   := "" as Character
    Local cMat   := "" as Character
    Local bErro  := Nil as Codeblock
    Local cErro  := "" as Character

    MatModelo(oModel, @cFil, @cMat)

    bErro := ErrorBlock({|e| cErro := e:Description + CRLF + e:ErrorStack, Break(e)})
    Begin Sequence
        nGrav := U_CBXAUXG("2", cFil, cMat)
    End Sequence
    ErrorBlock(bErro)

    If !Empty(cErro)
        FWLogMsg("ERROR", , "CBGPEX02", "CBXAUXP", , "01", "Histórico do auxílio creche não gravado (matrícula " + cMat + "): " + cErro, 0, 0, {})
    EndIf
Return nGrav

/*/{Protheus.doc} MatModelo
Filial e matrícula do funcionário do modelo do cadastro de Dependentes. Usa o
submodelo principal (SRA) quando existir; senão a SRA posicionada.
@type static function
@author João Victor Guimarães Alves
@since 17/11/2026
@param oModel, object, modelo
@param cFil, character, filial (por referência)
@param cMat, character, matrícula (por referência)
/*/
Static Function MatModelo(oModel as Object, cFil as Character, cMat as Character)
    Local aIds := {} as Array
    Local nI   := 0 as Numeric
    Local oSub := Nil as Object

    If ValType(oModel) == "O"
        aIds := oModel:GetModelIds()
        For nI := 1 To Len(aIds)
            oSub := oModel:GetModel(aIds[nI])
            If oSub:HasField("RA_MAT") .And. !Empty(oSub:GetValue("RA_MAT"))
                cMat := oSub:GetValue("RA_MAT")
                If oSub:HasField("RA_FILIAL")
                    cFil := oSub:GetValue("RA_FILIAL")
                EndIf
                Exit
            EndIf
        Next nI
    EndIf

    If Empty(cMat)
        cMat := SRA->RA_MAT
    EndIf
    If Empty(cFil)
        cFil := SRA->RA_FILIAL
    EndIf
Return
