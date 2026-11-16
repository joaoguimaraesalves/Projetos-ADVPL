#include "totvs.ch"
#include "fwmvcdef.ch"

// O que mudou na alteração em andamento (montado na validação, gravado no log)
Static cHisDetAlt := ""

/*/{Protheus.doc} CBGPEA21
Históricos do Funcionário (tabela ZHF) — browse com todos os funcionários.
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
/*/
User Function CBGPEA21()
    Local oBrowse := Nil as Object

    oBrowse := MntBrowse("")
    oBrowse:Activate()
Return

/*/{Protheus.doc} CBGPA21F
Históricos do funcionário posicionado na SRA. Chamado pela opção
"Históricos" do Cadastro de Funcionários (ponto de entrada GPE10OPC).
Enquanto a tela está aberta, a filial corrente vira a filial do funcionário:
assim a busca do funcionário/dependente, a sequência e a filial gravada na
ZHF batem com ele mesmo quando o usuário entrou em outra filial (v3, 11/11/2026).
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
/*/
User Function CBGPA21F()
    Local oBrowse  := Nil as Object
    Local aAreaSRA := SRA->(GetArea()) as Array
    Local cFiltro  := "" as Character
    Local cFilOrig := cFilAnt as Character
    Private cHisMatCtx := SRA->RA_MAT
    Private aRotina    := MenuDef()

    If SRA->(Eof())
        Help(,, "CBGPEA21",, "Posicione um funcionário antes de abrir os históricos.", 1, 0,,,,,, {"Selecione o funcionário no Cadastro de Funcionários e abra Outras Ações > Históricos."})
        Return
    EndIf

    cFilAnt := SRA->RA_FILIAL
    cFiltro := "ZHF_FILIAL == '" + xFilial("ZHF") + "' .And. ZHF_MAT == '" + SRA->RA_MAT + "'"

    oBrowse := MntBrowse(cFiltro)
    oBrowse:SetDescription("Históricos - " + AllTrim(SRA->RA_MAT) + " " + AllTrim(SRA->RA_NOME))
    oBrowse:Activate()

    cFilAnt := cFilOrig
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
    Local nOrdInc := 0 as Numeric

    // Abre na ordem de gravação (alteração mais recente por último), quando o índice existe
    nOrdInc := OrdemInc()
    If nOrdInc > 0
        ZHF->(DbSetOrder(nOrdInc))
    EndIf

    oBrowse := FWMBrowse():New()
    oBrowse:SetAlias("ZHF")
    oBrowse:SetMenuDef("CBGPEA21")
    oBrowse:SetDescription("Históricos do Funcionário")
    oBrowse:AddLegend("ZHF_ORIGEM == '1'", "GREEN",  "Manual")
    oBrowse:AddLegend("ZHF_ORIGEM == '2'", "BLUE",   "Automática (cadastro)")
    oBrowse:AddLegend("ZHF_ORIGEM == '3'", "YELLOW", "Carga inicial")

    // Coluna com a descrição por extenso (pedido do cliente 16/11/2026). Quando o campo
    // virtual ZHF_DESCR existe no dicionário, ele já aparece na posição certa (depois
    // do Tipo); sem ele, a coluna é incluída aqui (fica no começo da lista).
    If Empty(GetSX3Cache("ZHF_DESCR", "X3_CAMPO"))
        oBrowse:SetColumns({ColDescr()})
    EndIf
    If !Empty(cFiltro)
        oBrowse:SetFilterDefault(cFiltro)
    EndIf
Return oBrowse

/*/{Protheus.doc} OrdemInc
Número do índice da ZHF por data/hora de gravação
(ZHF_FILIAL+ZHF_MAT+DTOS(ZHF_DTINC)+ZHF_HRINC); 0 quando não existe.
@type static function
@author João Victor Guimarães Alves
@since 16/11/2026
@return numeric, número do índice
/*/
Static Function OrdemInc() as Numeric
    Local nOrd  := 0 as Numeric
    Local nCont := 0 as Numeric
    Local aArea := SIX->(GetArea()) as Array

    SIX->(DbSetOrder(1))
    SIX->(DbSeek("ZHF"))
    While !SIX->(Eof()) .And. AllTrim(SIX->INDICE) == "ZHF"
        nCont++
        If "ZHF_DTINC" $ Upper(SIX->CHAVE)
            nOrd := nCont
            Exit
        EndIf
        SIX->(DbSkip())
    EndDo
    RestArea(aArea)
Return nOrd

/*/{Protheus.doc} ColDescr
Coluna "Descrição" do browse: valor novo do histórico por extenso (descrição da
opção do campo, da função gratificada etc.), igual ao campo "Valor novo (texto)".
@type static function
@author João Victor Guimarães Alves
@since 16/11/2026
@return object, FWBrwColumn
/*/
Static Function ColDescr() as Object
    Local oCol  := FWBrwColumn():New() as Object
    Local aMapa := U_CBXHISM() as Array

    oCol:SetTitle("Descrição")
    oCol:SetType("C")
    oCol:SetSize(40)
    oCol:SetData({|| DescrBrw(aMapa)})
Return oCol

/*/{Protheus.doc} DescrBrw
Texto da coluna "Descrição" para a linha posicionada da ZHF.
@type static function
@author João Victor Guimarães Alves
@since 16/11/2026
@param aMapa, array, mapa tipo x campo (U_CBXHISM)
@return character, valor novo por extenso
/*/
Static Function DescrBrw(aMapa as Array) as Character
Return U_CBXHISE(aMapa)

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
    aAdd(aMenu, {"Visualizar",    "VIEWDEF.CBGPEA21",  0, 2, 0, Nil})
    aAdd(aMenu, {"Incluir",       "VIEWDEF.CBGPEA21",  0, 3, 0, Nil})
    aAdd(aMenu, {"Alterar",       "VIEWDEF.CBGPEA21",  0, 4, 0, Nil})
    aAdd(aMenu, {"Excluir",       "VIEWDEF.CBGPEA21",  0, 5, 0, Nil})
    aAdd(aMenu, {"Auditoria",     "U_CBGPA21L",       0, 2, 0, Nil})
    aAdd(aMenu, {"Legenda",       "U_CBGPA21G",      0, 2, 0, Nil})
    aAdd(aMenu, {"Relatório",     "U_CBGPER20",        0, 7, 0, Nil})
    aAdd(aMenu, {"Carga inicial", "U_CBGPEM13",        0, 7, 0, Nil})
Return aMenu

/*/{Protheus.doc} CBGPA21G
Legenda das cores do browse de históricos (origem de cada histórico).
@type user function
@author João Victor Guimarães Alves
@since 13/11/2026
/*/
User Function CBGPA21G()
    Local aLegenda := {} as Array

    aAdd(aLegenda, {"BR_VERDE",   "Manual - incluído pela tela de Históricos"})
    aAdd(aLegenda, {"BR_AZUL",    "Automática - gravado ao salvar o Cadastro ou a Gestão de Funcionários"})
    aAdd(aLegenda, {"BR_AMARELO", "Carga inicial - situação do funcionário registrada na implantação"})
    BrwLegenda("Históricos do Funcionário", "Origem do histórico", aLegenda)
Return

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
    If oStruct:HasField("ZHF_DESCR")
        oStruct:RemoveField("ZHF_DESCR") // campo só do browse
    EndIf

    // Campos que abrem conforme o tipo e a origem da linha
    aWhen := {"ZHF_MAT", "ZHF_TIPO", "ZHF_DATA", "ZHF_DTFIM", "ZHF_SITUAC", "ZHF_PENAL", "ZHF_TPAUX", "ZHF_DEPEND", "ZHF_PROCES", "ZHF_VLNOV"}
    For nI := 1 To Len(aWhen)
        oStruct:SetProperty(aWhen[nI], MODEL_FIELD_WHEN, {|oMdl, cFld| U_CBGPA21W(cFld, oMdl)})
    Next nI

    // Matrícula precisa existir na SRA (validação no modelo, sem variável de memória)
    oStruct:SetProperty("ZHF_MAT", MODEL_FIELD_VALID, {|oMdl, cFld, xVal| ExistCpo("SRA", xVal)})

    // Data Inicial obrigatória; Data Final e Processo opcionais (cliente, 10/11/2026)
    oStruct:SetProperty("ZHF_DATA", MODEL_FIELD_OBRIGAT, .T.)
    oStruct:SetProperty("ZHF_DTFIM", MODEL_FIELD_VALID, {|oMdl, cFld, xVal| DataFimOk(oMdl, xVal)})

    // Campos preenchidos pelo sistema
    aFixos := {"ZHF_SEQ", "ZHF_VLANT", "ZHF_ORIGEM", "ZHF_USER", "ZHF_DTINC", "ZHF_HRINC", ;
        "ZHF_CODUSR", "ZHF_USRALT", "ZHF_CODALT", "ZHF_DTALT", "ZHF_HRALT"}
    For nI := 1 To Len(aFixos)
        If oStruct:HasField(aFixos[nI])
            oStruct:SetProperty(aFixos[nI], MODEL_FIELD_WHEN, {|| .F.})
        EndIf
    Next nI

    // Valor anterior/novo em texto (ex.: "1 - 50/50"), só para exibição (16/11/2026)
    oStruct:AddField("Desc.Val.Ant", "Valor anterior por extenso", "ZHF_DSCANT", "C", 80, 0, Nil, {|| .F.}, Nil, .F., ;
        {|oMdl| TxtValor(oMdl, "ZHF_VLANT")}, .F., .T., .T.)
    oStruct:AddField("Desc.Val.Novo", "Valor novo por extenso", "ZHF_DSCNOV", "C", 80, 0, Nil, {|| .F.}, Nil, .F., ;
        {|oMdl| TxtValor(oMdl, "ZHF_VLNOV")}, .F., .T., .T.)

    oModel := MPFormModel():New("CBGPA21M", /*bPre*/, {|oMdl| PosValida(oMdl)}, {|oMdl| Grava(oMdl)})
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

    oModel  := FWLoadModel("CBGPEA21")
    oStruct := FWFormStruct(2, "ZHF")
    If oStruct:HasField("ZHF_DESCR")
        oStruct:RemoveField("ZHF_DESCR") // campo só do browse
    EndIf

    oStruct:AddField("ZHF_DSCANT", OrdemApos(oStruct, "ZHF_VLANT"), "Valor ant. (texto)", "Valor anterior por extenso", Nil, "C", "", Nil, "", .F., Nil, Nil, Nil, Nil, Nil, .T.)
    oStruct:AddField("ZHF_DSCNOV", OrdemApos(oStruct, "ZHF_VLNOV"), "Valor novo (texto)", "Valor novo por extenso", Nil, "C", "", Nil, "", .F., Nil, Nil, Nil, Nil, Nil, .T.)

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
    Local aUsr     := {} as Array
    Local cSimNao  := U_CBXHISL("SIMNAO") as Character
    Local cCampos  := U_CBXHISL("CAMPO") as Character

    nOper := oModel:GetOperation()
    oCab  := oModel:GetModel("ZHFMASTER")
    cHisDetAlt := ""

    If nOper == MODEL_OPERATION_DELETE
        If oCab:GetValue("ZHF_ORIGEM") <> "1"
            Help(,, "CBGPEA21",, "Linhas gravadas automaticamente não podem ser excluídas.", 1, 0,,,,,, {"Só históricos incluídos pela tela (legenda verde) podem ser excluídos. Para corrigir um histórico automático ou da carga inicial, use Alterar (Data Inicial, Data Final e Processo)."})
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

    // Datas valem para qualquer origem (manual, automática ou carga)
    If Empty(oCab:GetValue("ZHF_DATA"))
        cErro := "Informe a Data Inicial."
    ElseIf !Empty(oCab:GetValue("ZHF_DTFIM")) .And. oCab:GetValue("ZHF_DTFIM") < oCab:GetValue("ZHF_DATA")
        cErro := "A Data Final não pode ser anterior à Data Inicial."
    EndIf
    If !Empty(cErro)
        Help(,, "CBGPEA21",, cErro, 1, 0,,,,,, {"Corrija a informação indicada e confirme novamente."})
        Return .F.
    EndIf

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
        Help(,, "CBGPEA21",, cErro, 1, 0,,,,,, {"Corrija a informação indicada e confirme novamente."})
        Return .F.
    EndIf

    aUsr := U_CBXHISU()
    If nOper == MODEL_OPERATION_INSERT
        oCab:LoadValue("ZHF_SEQ", U_CBXHISS(xFilial("ZHF"), cMat, cTipo))
        oCab:LoadValue("ZHF_ORIGEM", "1")
        oCab:LoadValue("ZHF_USER", aUsr[2])
        oCab:LoadValue("ZHF_DTINC", Date())
        oCab:LoadValue("ZHF_HRINC", Time())
        PoeValor(oCab, "ZHF_CODUSR", aUsr[1])
        PoeValor(oCab, "ZHF_MATINC", aUsr[3])
    Else
        // Alteração: guarda o que mudou e quem alterou (auditoria)
        cHisDetAlt := Diferencas(oCab)
        If !Empty(cHisDetAlt)
            PoeValor(oCab, "ZHF_CODALT", aUsr[1])
            PoeValor(oCab, "ZHF_USRALT", aUsr[2])
            PoeValor(oCab, "ZHF_MATALT", aUsr[3])
            PoeValor(oCab, "ZHF_DTALT", Date())
            PoeValor(oCab, "ZHF_HRALT", Time())
        EndIf
    EndIf
Return lRet

/*/{Protheus.doc} Grava
Gravação do modelo. Na inclusão, fecha o histórico anterior do mesmo tipo
(Data Final vazia recebe a Data Inicial do novo). Inclusão, alteração e
exclusão entram no log de auditoria (ZHG).
@type static function
@author João Victor Guimarães Alves
@since 10/11/2026
@param oModel, object, modelo ativo
@return logical, .T. quando gravou
/*/
Static Function Grava(oModel as Object) as Logical
    Local lRet  := .T. as Logical
    Local oCab  := oModel:GetModel("ZHFMASTER") as Object
    Local nOper := oModel:GetOperation() as Numeric
    Local cMat  := oCab:GetValue("ZHF_MAT") as Character
    Local cTipo := oCab:GetValue("ZHF_TIPO") as Character
    Local cSeq  := oCab:GetValue("ZHF_SEQ") as Character
    Local dIni  := oCab:GetValue("ZHF_DATA") as Date
    Local cFil  := xFilial("ZHF") as Character
    Local cDet  := "" as Character

    If nOper == MODEL_OPERATION_DELETE
        cDet := "Excluído: " + AllTrim(U_CBXHIST(cTipo)) + ", Data Inicial " + U_CBXHISB(dIni) + ;
            IIf(Empty(oCab:GetValue("ZHF_DTFIM")), "", ", Data Final " + U_CBXHISB(oCab:GetValue("ZHF_DTFIM"))) + ;
            IIf(Empty(oCab:GetValue("ZHF_PROCES")), "", ", Processo " + AllTrim(oCab:GetValue("ZHF_PROCES"))) + ;
            IIf(Empty(oCab:GetValue("ZHF_VLNOV")), "", ", Valor " + AllTrim(oCab:GetValue("ZHF_VLNOV")))
    ElseIf nOper == MODEL_OPERATION_INSERT
        cDet := "Incluído manualmente: " + AllTrim(U_CBXHIST(cTipo)) + ", Data Inicial " + U_CBXHISB(dIni) + ;
            IIf(Empty(oCab:GetValue("ZHF_DTFIM")), "", ", Data Final " + U_CBXHISB(oCab:GetValue("ZHF_DTFIM"))) + ;
            IIf(Empty(oCab:GetValue("ZHF_PROCES")), "", ", Processo " + AllTrim(oCab:GetValue("ZHF_PROCES")))
    Else
        cDet := cHisDetAlt
    EndIf

    lRet := FWFormCommit(oModel)

    If lRet
        If !Empty(cDet)
            U_CBXHISA(cFil, cMat, cTipo, cSeq, IIf(nOper == MODEL_OPERATION_INSERT, "1", IIf(nOper == MODEL_OPERATION_DELETE, "3", "2")), cDet)
        EndIf
        If nOper == MODEL_OPERATION_INSERT
            U_CBXHISF(cFil, cMat, cTipo, cSeq, dIni)
        EndIf
    EndIf
    cHisDetAlt := ""
Return lRet

/*/{Protheus.doc} Diferencas
Lista os campos alterados na tela (valor antigo -> novo) para o log de auditoria.
@type static function
@author João Victor Guimarães Alves
@since 11/11/2026
@param oCab, object, submodelo ZHFMASTER
@return character, "Campo: antigo -> novo; ..." (vazio se nada mudou)
/*/
Static Function Diferencas(oCab as Object) as Character
    Local cDet   := "" as Character
    Local aCpos  := {"ZHF_DATA", "ZHF_DTFIM", "ZHF_SITUAC", "ZHF_PENAL", "ZHF_TPAUX", "ZHF_DEPEND", "ZHF_PROCES", "ZHF_VLNOV"} as Array
    Local nI     := 0 as Numeric
    Local nRec   := oCab:GetDataId() as Numeric
    Local xAnt   := Nil as Variant
    Local xNov   := Nil as Variant
    Local aArea  := ZHF->(GetArea()) as Array

    If ValType(nRec) == "N" .And. nRec > 0
        ZHF->(DbGoTo(nRec))
    EndIf

    For nI := 1 To Len(aCpos)
        xAnt := ZHF->(FieldGet(FieldPos(aCpos[nI])))
        xNov := oCab:GetValue(aCpos[nI])
        If ValType(xAnt) == "C"
            xAnt := AllTrim(xAnt)
            xNov := AllTrim(xNov)
        EndIf
        If !(xAnt == xNov)
            cDet += AllTrim(GetSX3Cache(aCpos[nI], "X3_TITULO")) + ": " + TextoLog(xAnt) + " -> " + TextoLog(xNov) + "; "
        EndIf
    Next nI

    ZHF->(RestArea(aArea))
Return cDet

/*/{Protheus.doc} TextoLog
Texto de um valor para o log (data em dd/mm/aaaa, vazio como "vazio").
@type static function
@author João Victor Guimarães Alves
@since 11/11/2026
@param xValor, variant, valor
@return character, texto
/*/
Static Function TextoLog(xValor as Variant) as Character
    Local cTexto := "" as Character

    If ValType(xValor) == "D"
        cTexto := U_CBXHISB(xValor)
    ElseIf ValType(xValor) == "C"
        cTexto := AllTrim(xValor)
    Else
        cTexto := AllTrim(cValToChar(xValor))
    EndIf
    If Empty(cTexto)
        cTexto := "vazio"
    EndIf
Return cTexto

/*/{Protheus.doc} PoeValor
LoadValue só se o campo existir no modelo (dicionário pode estar sem a v3).
@type static function
@author João Victor Guimarães Alves
@since 11/11/2026
@param oCab, object, submodelo
@param cCampo, character, campo
@param xValor, variant, valor
/*/
Static Function PoeValor(oCab as Object, cCampo as Character, xValor as Variant)
    If oCab:GetStruct():HasField(cCampo)
        oCab:LoadValue(cCampo, xValor)
    EndIf
Return

/*/{Protheus.doc} CBGPA21L
Auditoria dos históricos: mostra quem incluiu, alterou ou excluiu históricos
do funcionário (log da tabela ZHG), inclusive os já excluídos.
@type user function
@author João Victor Guimarães Alves
@since 11/11/2026
/*/
User Function CBGPA21L()
    Local aDados := {} as Array
    Local cFil   := "" as Character
    Local cMat   := "" as Character
    Local cNome  := "" as Character
    Local oDlg   := Nil as Object
    Local oBrw   := Nil as Object
    Local aArea  := GetArea() as Array

    If !FWAliasInDic("ZHG")
        Help(,, "CBGPEA21",, "Tabela de auditoria ZHG não existe no dicionário.", 1, 0,,,,,, {"Execute o compatibilizador UPDZHF01 para criar a tabela ZHG."})
        Return
    EndIf

    If !ZHF->(Eof())
        cFil := ZHF->ZHF_FILIAL
        cMat := ZHF->ZHF_MAT
    ElseIf Type("cHisMatCtx") == "C"
        cFil := xFilial("ZHF")
        cMat := &("cHisMatCtx")
    EndIf
    If Empty(cMat)
        Help(,, "CBGPEA21",, "Posicione um histórico do funcionário.", 1, 0,,,,,, {"Selecione um histórico no browse antes de abrir a Auditoria."})
        Return
    EndIf
    cNome := AllTrim(Posicione("SRA", 1, xFilial("SRA", cFil) + cMat, "RA_NOME"))

    ZHG->(DbSetOrder(1)) // ZHG_FILIAL+ZHG_MAT+DTOS(ZHG_DATA)+ZHG_HORA
    ZHG->(DbSeek(cFil + cMat))
    While !ZHG->(Eof()) .And. ZHG->(ZHG_FILIAL + ZHG_MAT) == cFil + cMat
        aAdd(aDados, {U_CBXHISB(ZHG->ZHG_DATA), ZHG->ZHG_HORA, ;
            IIf(ZHG->ZHG_OPER == "1", "Inclusão", IIf(ZHG->ZHG_OPER == "3", "Exclusão", "Alteração")), ;
            AllTrim(U_CBXHIST(ZHG->ZHG_TIPO)), ZHG->ZHG_SEQ, ZHG->ZHG_CODUSR, AllTrim(ZHG->ZHG_USER), ;
            IIf(ZHG->(FieldPos("ZHG_MATUSR")) > 0, ZHG->(FieldGet(FieldPos("ZHG_MATUSR"))), ""), ;
            AllTrim(ZHG->ZHG_ROTINA), AllTrim(ZHG->ZHG_DETALH)})
        ZHG->(DbSkip())
    EndDo
    RestArea(aArea)

    If Empty(aDados)
        MsgInfo("Nenhum registro de auditoria para " + AllTrim(cMat) + " " + cNome + ".", "Auditoria")
        Return
    EndIf

    DEFINE MSDIALOG oDlg TITLE "Auditoria dos históricos - " + AllTrim(cMat) + " " + cNome FROM 0, 0 TO 450, 1100 PIXEL
    oBrw := TWBrowse():New(5, 5, 542, 195, , ;
        {"Data", "Hora", "Operação", "Tipo", "Seq.", "Cód. usuário", "Usuário", "Matrícula usuário", "Rotina", "O que mudou"}, ;
        {40, 35, 45, 80, 20, 45, 70, 55, 45, 400}, oDlg, , , , , , , , , , , , .F., , .T., , .F.)
    oBrw:SetArray(aDados)
    oBrw:bLine := {|| aDados[oBrw:nAt]}
    TButton():New(205, 497, "Fechar", oDlg, {|| oDlg:End()}, 50, 14, , , , .T.)
    ACTIVATE MSDIALOG oDlg CENTERED
Return

/*/{Protheus.doc} DataFimOk
Valida a Data Final digitada: vazia ou igual/depois da Data Inicial.
@type static function
@author João Victor Guimarães Alves
@since 10/11/2026
@param oMdl, variant, submodelo ZHFMASTER (ou Nil: usa o modelo ativo)
@param dFim, date, Data Final digitada
@return logical, .T. quando é válida
/*/
Static Function DataFimOk(oMdl as Object, dFim as Date) as Logical
    Local lRet := .T. as Logical

    If !Empty(dFim) .And. !Empty(oMdl:GetValue("ZHF_DATA")) .And. dFim < oMdl:GetValue("ZHF_DATA")
        Help(,, "CBGPEA21",, "A Data Final não pode ser anterior à Data Inicial.", 1, 0,,,,,, {"Informe uma Data Final igual ou posterior à Data Inicial, ou deixe em branco."})
        lRet := .F.
    EndIf
Return lRet

/*/{Protheus.doc} CBGPA21W
Regra de edição (WHEN) dos campos da ZHF na tela de Históricos.
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
@param cCampo, character, nome do campo
@param oMdl, variant, submodelo ZHFMASTER (ou Nil: usa o modelo ativo) (vem do bloco WHEN)
@return logical, .T. quando o campo pode ser editado
/*/
User Function CBGPA21W(cCampo, oMdl)
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
        // Linha gravada automaticamente: só as datas e o processo podem mudar
        lRet := (cCampo == "ZHF_DATA" .Or. cCampo == "ZHF_DTFIM" .Or. cCampo == "ZHF_PROCES")
    ElseIf cCampo == "ZHF_SITUAC"
        lRet := (cTipo $ U_CBXHISL("SIMNAO"))
    ElseIf cCampo == "ZHF_PENAL"
        lRet := (cTipo == "04")
    ElseIf cCampo == "ZHF_TPAUX" .Or. cCampo == "ZHF_DEPEND"
        lRet := (cTipo == "09")
    ElseIf cCampo == "ZHF_VLNOV"
        lRet := (cTipo $ U_CBXHISL("CAMPO"))
    EndIf
Return lRet

/*/{Protheus.doc} TxtValor
Texto do valor anterior/novo de um histórico para exibir na tela: código +
descrição (ex.: "1 - 50/50"; função: código + descrição da SZA). Na inclusão
fica vazio (o valor ainda não existe).
@type static function
@author João Victor Guimarães Alves
@since 16/11/2026
@param oMdl, variant, submodelo ZHFMASTER (ou Nil: usa o modelo ativo)
@param cCampo, character, ZHF_VLANT ou ZHF_VLNOV
@return character, texto para exibir
/*/
Static Function TxtValor(oMdl as Variant, cCampo as Character) as Character
    Local cValor := "" as Character
    Local cTexto := "" as Character

    If ValType(oMdl) <> "O"
        oMdl := FWModelActive()
    EndIf
    If ValType(oMdl) == "O" .And. oMdl:GetOperation() == MODEL_OPERATION_INSERT
        Return cTexto
    EndIf
    If ZHF->(Eof()) .Or. ZHF->(FieldPos(cCampo)) == 0
        Return cTexto
    EndIf

    cValor := AllTrim(ZHF->(FieldGet(FieldPos(cCampo))))
    If Empty(cValor)
        Return cTexto
    EndIf

    cTexto := AllTrim(U_CBXHISV(ZHF->ZHF_TIPO, cValor, U_CBXHISM()))
    If !(cTexto == cValor) .And. !(Left(cTexto, Len(cValor) + 1) == cValor + " ")
        cTexto := cValor + " - " + cTexto
    EndIf
Return cTexto

/*/{Protheus.doc} OrdemApos
Ordem de tela logo depois de um campo da estrutura (para os campos virtuais).
@type static function
@author João Victor Guimarães Alves
@since 16/11/2026
@param oStruct, object, estrutura de tela (FWFormStruct 2)
@param cCampo, character, campo de referência
@return character, ordem
/*/
Static Function OrdemApos(oStruct as Object, cCampo as Character) as Character
    Local cOrdem := "99" as Character

    If oStruct:HasField(cCampo)
        cOrdem := AllTrim(oStruct:GetProperty(cCampo, MVC_VIEW_ORDEM)) + "1"
    EndIf
Return cOrdem
