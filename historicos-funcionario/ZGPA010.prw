#include "totvs.ch"
#include "fwmvcdef.ch"

/*/{Protheus.doc} ZGPA010
Históricos do Funcionário (tabela ZHF) — browse com todos os funcionários.
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
/*/
User Function ZGPA010()
    Local oBrowse := Nil as Object

    oBrowse := MntBrowse("")
    oBrowse:Activate()
Return

/*/{Protheus.doc} ZGPA010F
Históricos do funcionário posicionado na SRA. Chamado pela opção
"Históricos" do Cadastro de Funcionários (ponto de entrada GPE10OPC).
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
/*/
User Function ZGPA010F()
    Local oBrowse  := Nil as Object
    Local aAreaSRA := SRA->(GetArea()) as Array
    Local cFiltro  := "" as Character
    Private cZgpMatCtx := SRA->RA_MAT
    Private aRotina    := MenuDef()

    If SRA->(Eof())
        Help(,, "ZGPA010",, "Posicione um funcionário antes de abrir os históricos.", 1, 0)
        Return
    EndIf

    cFiltro := "ZHF_FILIAL == '" + xFilial("ZHF", SRA->RA_FILIAL) + "' .And. ZHF_MAT == '" + SRA->RA_MAT + "'"

    oBrowse := MntBrowse(cFiltro)
    oBrowse:SetDescription("Históricos - " + AllTrim(SRA->RA_MAT) + " " + AllTrim(SRA->RA_NOME))
    oBrowse:Activate()

    RestArea(aAreaSRA)
Return

/*/{Protheus.doc} MntBrowse
Monta o browse da ZHF.
@type static function
@author João Victor Guimarães Alves
@since 29/10/2026
@param cFiltro, character, filtro padrão (vazio = todos)
@return object, FWMBrowse
/*/
Static Function MntBrowse(cFiltro as Character) as Object
    Local oBrowse := Nil as Object

    oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("ZHF")
    oBrowse:SetMenuDef("ZGPA010")
    oBrowse:SetDescription("Históricos do Funcionário")
    oBrowse:AddLegend("ZHF_ORIGEM == '1'", "GREEN",  "Manual")
    oBrowse:AddLegend("ZHF_ORIGEM == '2'", "BLUE",   "Automática (cadastro)")
    oBrowse:AddLegend("ZHF_ORIGEM == '3'", "YELLOW", "Carga inicial")

    If !Empty(cFiltro)
        oBrowse:SetFilterDefault(cFiltro)
    EndIf
Return oBrowse

/*/{Protheus.doc} MenuDef
Opções do browse de históricos.
@type static function
@author João Victor Guimarães Alves
@since 29/10/2026
@return array, aRotina
/*/
Static Function MenuDef() as Array
    Local aMenu := {} as Array

    aAdd(aMenu, {"Pesquisar",     "PesqBrw",          0, 1, 0, Nil})
    aAdd(aMenu, {"Visualizar",    "VIEWDEF.ZGPA010",  0, 2, 0, Nil})
    aAdd(aMenu, {"Incluir",       "VIEWDEF.ZGPA010",  0, 3, 0, Nil})
    aAdd(aMenu, {"Alterar",       "VIEWDEF.ZGPA010",  0, 4, 0, Nil})
    aAdd(aMenu, {"Excluir",       "VIEWDEF.ZGPA010",  0, 5, 0, Nil})
    aAdd(aMenu, {"Relatório",     "U_ZGPR010",        0, 7, 0, Nil})
    aAdd(aMenu, {"Carga inicial", "U_ZGPM010",        0, 7, 0, Nil})
Return aMenu

/*/{Protheus.doc} ModelDef
Modelo de dados da ZHF.
@type static function
@author João Victor Guimarães Alves
@since 29/10/2026
@return object, MPFormModel
/*/
Static Function ModelDef() as Object
    Local oModel  := Nil as Object
    Local oStruct := Nil as Object
    Local aWhen   := {} as Array
    Local aFixos  := {} as Array
    Local nI      := 0 as Numeric

    oStruct := FWFormStruct(1, "ZHF")

    // Campos que abrem conforme o tipo e a origem da linha
    aWhen := {"ZHF_MAT", "ZHF_TIPO", "ZHF_DATA", "ZHF_SITUAC", "ZHF_PENAL", "ZHF_TPAUX", "ZHF_DEPEND", "ZHF_PROCES", "ZHF_VLNOV"}
    For nI := 1 To Len(aWhen)
        oStruct:SetProperty(aWhen[nI], MODEL_FIELD_WHEN, {|oMdl, cFld| U_ZGPA010W(cFld, oMdl)})
    Next nI

    // Matrícula precisa existir na SRA (validação no modelo, sem variável de memória)
    oStruct:SetProperty("ZHF_MAT", MODEL_FIELD_VALID, {|oMdl, cFld, xVal| ExistCpo("SRA", xVal)})

    // Campos preenchidos pelo sistema
    aFixos := {"ZHF_SEQ", "ZHF_VLANT", "ZHF_ORIGEM", "ZHF_USER", "ZHF_DTINC", "ZHF_HRINC"}
    For nI := 1 To Len(aFixos)
        oStruct:SetProperty(aFixos[nI], MODEL_FIELD_WHEN, {|| .F.})
    Next nI

    oModel := MPFormModel():New("ZGPA010M", /*bPre*/, {|oMdl| PosValida(oMdl)})
    oModel:AddFields("ZHFMASTER", /*cOwner*/, oStruct)
    oModel:SetPrimaryKey({"ZHF_FILIAL", "ZHF_MAT", "ZHF_TIPO", "ZHF_SEQ"})
    oModel:SetDescription("Históricos do Funcionário")
    oModel:GetModel("ZHFMASTER"):SetDescription("Histórico")
Return oModel

/*/{Protheus.doc} ViewDef
Tela da ZHF.
@type static function
@author João Victor Guimarães Alves
@since 29/10/2026
@return object, FWFormView
/*/
Static Function ViewDef() as Object
    Local oView   := Nil as Object
    Local oModel  := Nil as Object
    Local oStruct := Nil as Object

    oModel  := FWLoadModel("ZGPA010")
    oStruct := FWFormStruct(2, "ZHF")

    oView := FWFormView():New()
    oView:SetModel(oModel)
    oView:AddField("VIEW_ZHF", oStruct, "ZHFMASTER")
    oView:CreateHorizontalBox("TELA", 100)
    oView:SetOwnerView("VIEW_ZHF", "TELA")
Return oView

/*/{Protheus.doc} PosValida
Validação da confirmação: regras por tipo, proteção das linhas automáticas e
preenchimento dos campos de controle na inclusão.
@type static function
@author João Victor Guimarães Alves
@since 29/10/2026
@param oModel, object, modelo ativo
@return logical, .T. quando pode gravar
/*/
Static Function PosValida(oModel as Object) as Logical
    Local lRet     := .T. as Logical
    Local oCab     := Nil as Object
    Local nOper    := 0 as Numeric
    Local cTipo    := "" as Character
    Local cMat     := "" as Character
    Local cDep     := "" as Character
    Local cErro    := "" as Character
    Local cSimNao  := U_ZGPX010L("SIMNAO") as Character
    Local cCampos  := U_ZGPX010L("CAMPO") as Character

    nOper := oModel:GetOperation()
    oCab  := oModel:GetModel("ZHFMASTER")

    If nOper == MODEL_OPERATION_DELETE
        If oCab:GetValue("ZHF_ORIGEM") <> "1"
            Help(,, "ZGPA010",, "Linhas gravadas automaticamente não podem ser excluídas.", 1, 0)
            lRet := .F.
        EndIf
        Return lRet
    EndIf

    If nOper <> MODEL_OPERATION_INSERT .And. nOper <> MODEL_OPERATION_UPDATE
        Return lRet
    EndIf

    cTipo := oCab:GetValue("ZHF_TIPO")
    cMat  := oCab:GetValue("ZHF_MAT")
    cDep  := oCab:GetValue("ZHF_DEPEND")

    // Limpa o que não se aplica ao tipo (só em linhas manuais)
    If oCab:GetValue("ZHF_ORIGEM") == "1" .Or. nOper == MODEL_OPERATION_INSERT
        If !(cTipo $ cSimNao)
            oCab:LoadValue("ZHF_SITUAC", "")
        EndIf
        If cTipo <> "04"
            oCab:LoadValue("ZHF_PENAL", "")
        EndIf
        If cTipo <> "09"
            oCab:LoadValue("ZHF_TPAUX", "")
            oCab:LoadValue("ZHF_DEPEND", "")
            cDep := ""
        EndIf
        If !(cTipo $ cCampos)
            oCab:LoadValue("ZHF_VLNOV", "")
        EndIf

        Do Case
            Case cTipo $ cSimNao .And. Empty(oCab:GetValue("ZHF_SITUAC"))
                cErro := "Informe a Situação (Sim/Não) para este tipo de histórico."
            Case cTipo == "04" .And. Empty(oCab:GetValue("ZHF_PENAL"))
                cErro := "Informe a Penalidade (Advertência, Suspensão ou TAC)."
            Case cTipo == "09" .And. Empty(oCab:GetValue("ZHF_TPAUX"))
                cErro := "Informe o Tipo de Auxílio."
            Case cTipo $ cCampos .And. Empty(oCab:GetValue("ZHF_VLNOV"))
                cErro := "Informe o Valor novo para este tipo de histórico."
        EndCase

        If Empty(cErro) .And. !Empty(cDep)
            SRB->(DbSetOrder(1)) // RB_FILIAL+RB_MAT+RB_COD
            If !SRB->(DbSeek(xFilial("SRB") + cMat + cDep))
                cErro := "Dependente " + cDep + " não encontrado para a matrícula " + AllTrim(cMat) + "."
            EndIf
        EndIf
    EndIf

    If !Empty(cErro)
        Help(,, "ZGPA010",, cErro, 1, 0)
        Return .F.
    EndIf

    If nOper == MODEL_OPERATION_INSERT
        oCab:LoadValue("ZHF_SEQ", U_ZGPX010S(xFilial("ZHF"), cMat, cTipo))
        oCab:LoadValue("ZHF_ORIGEM", "1")
        oCab:LoadValue("ZHF_USER", cUserName)
        oCab:LoadValue("ZHF_DTINC", Date())
        oCab:LoadValue("ZHF_HRINC", Time())
    EndIf
Return lRet

/*/{Protheus.doc} ZGPA010W
Regra de edição (WHEN) dos campos da ZHF na tela de Históricos.
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
@param cCampo, character, nome do campo
@param oMdl, object, submodelo ZHFMASTER (vem do bloco WHEN)
@return logical, .T. quando o campo pode ser editado
/*/
User Function ZGPA010W(cCampo, oMdl)
    Local lRet    := .T.
    Local oModel  := FWModelActive()
    Local cTipo   := ""
    Local cOrigem := ""
    Local nOper   := 0

    If oModel == Nil
        Return lRet
    EndIf

    If ValType(oMdl) == "O"
        cTipo   := oMdl:GetValue("ZHF_TIPO")
        cOrigem := oMdl:GetValue("ZHF_ORIGEM")
    Else
        cTipo   := oModel:GetValue("ZHFMASTER", "ZHF_TIPO")
        cOrigem := oModel:GetValue("ZHFMASTER", "ZHF_ORIGEM")
    EndIf
    nOper := oModel:GetOperation()

    If cCampo == "ZHF_MAT" .Or. cCampo == "ZHF_TIPO"
        lRet := (nOper == MODEL_OPERATION_INSERT)
    ElseIf !Empty(cOrigem) .And. cOrigem <> "1"
        // Linha gravada automaticamente: só data e processo podem mudar
        lRet := (cCampo == "ZHF_DATA" .Or. cCampo == "ZHF_PROCES")
    ElseIf cCampo == "ZHF_SITUAC"
        lRet := (cTipo $ U_ZGPX010L("SIMNAO"))
    ElseIf cCampo == "ZHF_PENAL"
        lRet := (cTipo == "04")
    ElseIf cCampo == "ZHF_TPAUX" .Or. cCampo == "ZHF_DEPEND"
        lRet := (cTipo == "09")
    ElseIf cCampo == "ZHF_VLNOV"
        lRet := (cTipo $ U_ZGPX010L("CAMPO"))
    EndIf
Return lRet
