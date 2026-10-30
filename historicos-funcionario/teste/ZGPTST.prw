#include "totvs.ch"
#include "fwmvcdef.ch"

// FONTE SÓ DE TESTE (base local). Não compilar no cliente.

/*/{Protheus.doc} ZGPTST
Dispara os testes em job (sem interface) e mostra o resultado.
@type user function
/*/
User Function ZGPTST()
    Local cRes := "" as Character

    StartJob("U_ZGPTSTJ", GetEnvServer(), .T.)
    cRes := MemoRead("\zgptst_resultado.txt")
    MsgInfo(cRes, "ZGPTST")
Return

/*/{Protheus.doc} ZGPTSTJ
Testes automáticos dos Históricos do Funcionário.
@type user function
/*/
User Function ZGPTSTJ()
    Local cLog   := "" as Character
    Local oError := Nil as Object
    Local bErro  := Nil

    RpcSetType(3)
    RpcSetEnv("99", "01", , , "GPE")

    MemoWrite("\zgptst_resultado.txt", "")
    bErro := ErrorBlock({|e| oError := e, Break(e)})
    Begin Sequence
        cLog := Testes()
    Recover
        cLog := MemoRead("\zgptst_resultado.txt") + CRLF + "ERRO GERAL: " + oError:Description + CRLF + oError:ErrorStack
    End Sequence
    ErrorBlock(bErro)

    MemoWrite("\zgptst_resultado.txt", cLog)
    RpcClearEnv()
Return

Static Function Testes() as Character
    Local cLog    := "" as Character
    Local oModel  := Nil as Object
    Local cMat    := "" as Character
    Local cPeriOr := "" as Character
    Local cNovo   := "" as Character
    Local nGrav   := 0 as Numeric
    Local nRecAut := 0 as Numeric
    Local lOk     := .F. as Logical
    Local aMapa   := {} as Array

    DbSelectArea("ZHF")
    cLog += Linha("T0 tabela ZHF aberta", Select("ZHF") > 0, RetSqlName("ZHF"))

    // Funcionário de teste: primeiro ativo da filial
    SRA->(DbSetOrder(1))
    SRA->(DbSeek(xFilial("SRA")))
    While !SRA->(Eof()) .And. SRA->RA_FILIAL == xFilial("SRA") .And. SRA->RA_SITFOLH == "D"
        SRA->(DbSkip())
    EndDo
    cMat := SRA->RA_MAT
    cLog += "Funcionario de teste: " + cMat + " " + AllTrim(SRA->RA_NOME) + CRLF

    // T1: tipo 02 sem Situação deve bloquear
    oModel := NovoModelo(MODEL_OPERATION_INSERT)
    cLog += "Campos apos Activate: " + TiposCpo(oModel) + CRLF
    MemoWrite("\zgptst_resultado.txt", cLog)
    oModel:SetValue("ZHFMASTER", "ZHF_MAT", cMat)
    oModel:SetValue("ZHFMASTER", "ZHF_TIPO", "02")
    oModel:SetValue("ZHFMASTER", "ZHF_DATA", dDataBase)
    lOk := oModel:VldData()
    cLog += Linha("T1 tipo 02 sem Situacao bloqueia", !lOk, Erro(oModel))

    // T2: campo Penalidade fechado no tipo 02
    lOk := oModel:SetValue("ZHFMASTER", "ZHF_PENAL", "1")
    cLog += Linha("T2 Penalidade fechada no tipo 02", !lOk, "")

    // T3: tipo 02 completo grava
    oModel:SetValue("ZHFMASTER", "ZHF_SITUAC", "1")
    oModel:SetValue("ZHFMASTER", "ZHF_PROCES", "PROC-TESTE-02")
    lOk := oModel:VldData() .And. oModel:CommitData()
    cLog += Linha("T3 tipo 02 completo grava", lOk, Erro(oModel) + " seq=" + ZHF->ZHF_SEQ + " origem=" + ZHF->ZHF_ORIGEM + " user=" + AllTrim(ZHF->ZHF_USER))
    oModel:DeActivate()

    // T4: tipo 04 TAC grava
    oModel := NovoModelo(MODEL_OPERATION_INSERT)
    oModel:SetValue("ZHFMASTER", "ZHF_MAT", cMat)
    oModel:SetValue("ZHFMASTER", "ZHF_TIPO", "04")
    oModel:SetValue("ZHFMASTER", "ZHF_DATA", dDataBase)
    oModel:SetValue("ZHFMASTER", "ZHF_PENAL", "3")
    oModel:SetValue("ZHFMASTER", "ZHF_PROCES", "PROC-TAC")
    lOk := oModel:VldData() .And. oModel:CommitData()
    cLog += Linha("T4 tipo 04 TAC grava", lOk, Erro(oModel))
    oModel:DeActivate()

    // T5: tipo 09 com dependente inexistente bloqueia
    oModel := NovoModelo(MODEL_OPERATION_INSERT)
    oModel:SetValue("ZHFMASTER", "ZHF_MAT", cMat)
    oModel:SetValue("ZHFMASTER", "ZHF_TIPO", "09")
    oModel:SetValue("ZHFMASTER", "ZHF_DATA", dDataBase)
    oModel:SetValue("ZHFMASTER", "ZHF_TPAUX", "1")
    oModel:SetValue("ZHFMASTER", "ZHF_DEPEND", "99")
    lOk := oModel:VldData()
    cLog += Linha("T5 tipo 09 dependente 99 bloqueia", !lOk, Erro(oModel))
    oModel:DeActivate()

    // T6: gravação automática (simula a alteração do cadastro)
    aMapa := U_ZGPX010M()
    cLog += "Mapa MV_ZHFCPOS: " + TxtMapa(aMapa) + CRLF
    SRA->(DbSeek(xFilial("SRA") + cMat))
    cPeriOr := SRA->RA_ADCPERI
    nGrav := U_ZGPX010G("2", aMapa)
    cLog += Linha("T6a primeira gravacao automatica", nGrav >= 0, cValToChar(nGrav) + " linha(s)")

    If cPeriOr == "2"
        cNovo := "1"
    Else
        cNovo := "2"
    EndIf
    RecLock("SRA", .F.)
    SRA->RA_ADCPERI := cNovo
    SRA->(MsUnlock())
    nGrav := U_ZGPX010G("2", aMapa)
    nRecAut := UltimaLinha(xFilial("ZHF") + cMat + "05")
    ZHF->(DbGoTo(nRecAut))
    cLog += Linha("T6b mudou periculosidade grava 1 linha", nGrav == 1 .And. ZHF->ZHF_ORIGEM == "2", "anterior=" + AllTrim(ZHF->ZHF_VLANT) + " novo=" + AllTrim(ZHF->ZHF_VLNOV) + " tipo=" + ZHF->ZHF_TIPO + " seq=" + ZHF->ZHF_SEQ + " origem=" + ZHF->ZHF_ORIGEM)

    nGrav := U_ZGPX010G("2", aMapa)
    cLog += Linha("T6c sem mudanca nao grava", nGrav == 0, cValToChar(nGrav) + " linha(s)")

    // T7: linha automática protegida
    ZHF->(DbGoTo(nRecAut))
    oModel := NovoModelo(MODEL_OPERATION_DELETE)
    lOk := oModel:VldData()
    cLog += Linha("T7a excluir linha automatica bloqueia", !lOk, Erro(oModel))
    oModel:DeActivate()

    ZHF->(DbGoTo(nRecAut))
    oModel := NovoModelo(MODEL_OPERATION_UPDATE)
    lOk := oModel:SetValue("ZHFMASTER", "ZHF_VLNOV", "X")
    cLog += Linha("T7b valor novo fechado na linha automatica", !lOk, "")
    lOk := oModel:SetValue("ZHFMASTER", "ZHF_PROCES", "PROC-AUTO") .And. oModel:VldData() .And. oModel:CommitData()
    cLog += Linha("T7c processo editavel na linha automatica", lOk, Erro(oModel))
    oModel:DeActivate()

    // T8: carga inicial duas vezes
    nGrav := U_ZGPM010J()
    cLog += Linha("T8a carga inicial (1a vez)", nGrav >= 0, cValToChar(nGrav) + " linha(s)")
    nGrav := U_ZGPM010J()
    cLog += Linha("T8b carga inicial (2a vez) grava zero", nGrav == 0, cValToChar(nGrav) + " linha(s)")

    // Restaura o funcionário de teste
    SRA->(DbSetOrder(1))
    SRA->(DbSeek(xFilial("SRA") + cMat))
    RecLock("SRA", .F.)
    SRA->RA_ADCPERI := cPeriOr
    SRA->(MsUnlock())
    cLog += "RA_ADCPERI restaurado para '" + cPeriOr + "'" + CRLF
    cLog += "ExistBlock GPE10OPC=" + cValToChar(ExistBlock("GPE10OPC")) + " GP010AGRV=" + cValToChar(ExistBlock("GP010AGRV")) + " FindFunction U_GPE10OPC=" + cValToChar(FindFunction("U_GPE10OPC")) + CRLF
    cLog += "MenuDef GPEA010: " + TxtMenu() + CRLF
    cLog += "Combo tipo 10: " + U_ZGPX010T("10") + " | situacao 04/3: " + U_ZGPX010D("04", "", "3", "") + CRLF
Return cLog

Static Function TiposCpo(oModel as Object) as Character
    Local cTxt := "" as Character
    Local aCpos := {} as Array
    Local nI := 0 as Numeric
    Local xVal := Nil as Variant

    aCpos := oModel:GetModel("ZHFMASTER"):GetStruct():GetFields()
    For nI := 1 To Len(aCpos)
        xVal := oModel:GetValue("ZHFMASTER", aCpos[nI][3])
        cTxt += aCpos[nI][3] + "=" + ValType(xVal) + " "
    Next nI
Return cTxt

Static Function TxtMenu()
    Local aMenu := FWLoadMenuDef("GPEA010")
    Local cTxt  := ""
    Local nI    := 0

    If ValType(aMenu) == "A"
        For nI := 1 To Len(aMenu)
            If ValType(aMenu[nI][1]) == "C"
                cTxt += aMenu[nI][1] + " | "
            EndIf
        Next nI
    Else
        cTxt := "FWLoadMenuDef retornou " + ValType(aMenu)
    EndIf
Return cTxt

Static Function UltimaLinha(cChave)
    Local nRec := 0

    ZHF->(DbSetOrder(1))
    ZHF->(DbSeek(cChave + "ZZZ", .T.))
    ZHF->(DbSkip(-1))
    If ZHF->(ZHF_FILIAL + ZHF_MAT + ZHF_TIPO) == cChave
        nRec := ZHF->(Recno())
    EndIf
Return nRec

Static Function NovoModelo(nOper as Numeric) as Object
    Local oModel := FWLoadModel("ZGPA010") as Object

    oModel:SetOperation(nOper)
    oModel:Activate()
Return oModel

Static Function Erro(oModel as Object) as Character
    Local aErr := oModel:GetErrorMessage() as Array
    Local cErr := "" as Character

    If ValType(aErr) == "A" .And. Len(aErr) >= 6 .And. ValType(aErr[6]) == "C"
        cErr := AllTrim(aErr[6])
    EndIf
Return cErr

Static Function Linha(cNome as Character, lPassou as Logical, cDet as Character) as Character
    Local cRes := "" as Character

    If lPassou
        cRes := "[OK]    "
    Else
        cRes := "[FALHA] "
    EndIf
Return cRes + cNome + " | " + cDet + CRLF

Static Function TxtMapa(aMapa as Array) as Character
    Local cTxt := "" as Character
    Local nI   := 0 as Numeric

    For nI := 1 To Len(aMapa)
        cTxt += aMapa[nI][1] + "=" + aMapa[nI][2] + " "
    Next nI
Return cTxt
