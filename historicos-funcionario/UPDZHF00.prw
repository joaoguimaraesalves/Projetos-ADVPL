#include "totvs.ch"

// Empresa/filial usadas quando o programa é chamado como Programa Inicial (sem ambiente aberto)
#Define HIS_EMP "01"
#Define HIS_FIL "01"

/*/{Protheus.doc} UPDZHF00
Compatibilizador do dicionário dos Históricos do Funcionário (v1 + v2):
cria a tabela ZHF (SX2), os campos (SX3), os índices (SIX) e o gatilho da matrícula (SX7).
Depois dele, rodar o UPDZHF01 (campos da v3: auditoria, aba Adicionais e tabela ZHG).

Segurança:
- SIMULAR mostra tudo o que seria feito e os problemas encontrados, sem gravar nada;
- só ACRESCENTA: o que já existe não é alterado (só é avisado);
- se já existir uma ZHF que não seja a dos Históricos (ou uma tabela ZHF no banco
  sem dicionário), PARA e não grava nada; ZHF da v1 já implantada: só acrescenta o
  que falta (ex.: Data Final da v2) e avisa o que está diferente;
- a ZHF usa o mesmo compartilhamento (filial/unidade/empresa) da SRA;
- pode ser executado de novo: o que já existe é ignorado;
- o resultado fica salvo em \system\updzhf00_AAAAMMDD_HHMMSS.log.

Uso: SmartClient/WebApp com Programa Inicial U_UPDZHF00 (empresa HIS_EMP/filial HIS_FIL),
ou chamado de dentro do sistema já logado na empresa desejada.
@type user function
@author João Victor Guimarães Alves
@since 13/11/2026
/*/
User Function UPDZHF00()
    Local nOpc    := 0 as Numeric
    Local lSimula := .T. as Logical
    Local lAbriu  := .F. as Logical
    Local cLog    := "" as Character

    nOpc := Aviso("Históricos do Funcionário - dicionário (v1 + v2)", ;
        "Cria no dicionário a tabela ZHF (Históricos do Funcionário), com campos, índices e gatilho. Depois rode o UPDZHF01." + CRLF + CRLF + ;
        "SIMULAR: só mostra o que seria feito. Não grava nada." + CRLF + ;
        "EXECUTAR: grava. Antes faça backup do banco.", ;
        {"Simular", "Executar", "Cancelar"}, 3)
    If nOpc <> 1 .And. nOpc <> 2
        Return
    EndIf
    lSimula := (nOpc == 1)

    If !lSimula .And. !MsgYesNo("Confirma a EXECUÇÃO? O backup do banco foi feito?", "Confirmação")
        Return
    EndIf

    If Type("cEmpAnt") <> "C" .Or. Empty(cEmpAnt)
        RpcSetType(3)
        If !RpcSetEnv(HIS_EMP, HIS_FIL)
            MsgStop("Não foi possível abrir a empresa " + HIS_EMP + " / filial " + HIS_FIL + ".", "UPDZHF00")
            Return
        EndIf
        lAbriu := .T.
    EndIf

    FWMsgRun(, {|| cLog := U_UPDZHF0X(lSimula)}, "UPDZHF00", IIf(lSimula, "Simulando...", "Atualizando o dicionário..."))
    MostraLog(cLog)

    If lAbriu
        RpcClearEnv()
    EndIf
Return

/*/{Protheus.doc} UPDZHF0X
Faz a conferência e (fora da simulação) grava o dicionário da ZHF. Precisa do
ambiente aberto (RpcSetEnv ou sistema logado).
@type user function
@author João Victor Guimarães Alves
@since 13/11/2026
@param lSimula, logical, .T. = só mostra o que seria feito
@return character, relatório do que foi feito
/*/
User Function UPDZHF0X(lSimula as Logical) as Character
    Local cLog     := "" as Character
    Local aErros   := {} as Array
    Local aCampos  := {} as Array
    Local aGat     := Gatilhos() as Array
    Local aIdx     := Indices() as Array
    Local aFazCpo  := {} as Array
    Local aFazGat  := {} as Array
    Local aFazIdx  := {} as Array
    Local lSX2     := .F. as Logical
    Local lNova    := .F. as Logical
    Local cOrdem   := "" as Character
    Local nI       := 0 as Numeric
    Local aModelos := {} as Array
    Local aRef     := {"RA_FILIAL", "RA_MAT", "RA_NOME"} as Array

    Default lSimula := .T.

    cLog += "UPDZHF00 - dicionário dos Históricos do Funcionário (ZHF, v1 + v2)" + CRLF
    cLog += "Data: " + DToC(Date()) + " " + Time() + "  Empresa: " + cEmpAnt + "  Filial: " + cFilAnt + CRLF
    cLog += "Modo: " + IIf(lSimula, "SIMULAÇÃO (nada é gravado)", "EXECUÇÃO") + CRLF + Replicate("-", 70) + CRLF

    // ---------------- 1) Conferências (não grava nada) ----------------
    For nI := 1 To Len(aRef)
        If RecCampo(aRef[nI]) == 0
            aAdd(aErros, "Campo " + aRef[nI] + " não encontrado no dicionário (usado de referência).")
        EndIf
    Next nI
    If !Empty(aErros)
        Return Problemas(cLog, aErros)
    EndIf
    aCampos := Campos()

    SX2->(DbSetOrder(1))
    lSX2 := SX2->(DbSeek("ZHF"))
    If lSX2
        // Só continua se a ZHF existente for a dos Históricos (v1 já implantada)
        If RecCampo("ZHF_TIPO") == 0 .Or. RecCampo("ZHF_SEQ") == 0 .Or. RecCampo("ZHF_VLNOV") == 0
            aAdd(aErros, "Já existe uma tabela ZHF no dicionário que NÃO é a dos Históricos (" + ;
                AllTrim(SX2->X2_NOME) + "). Nada será feito: verificar antes.")
        Else
            Diferencas(@cLog)
        EndIf
    Else
        lNova := .T.
        If TCCanOpen("ZHF" + cEmpAnt + "0")
            aAdd(aErros, "A tabela ZHF" + cEmpAnt + "0 já existe no banco, mas não está no dicionário. Verificar antes.")
        EndIf
    EndIf
    SX2->(DbSeek("SRA"))

    // Modelos de registro (copiados com X3_USADO/X3_RESERV de campo de usuário comum)
    aModelos := {{"C", Modelo("C")}, {"D", Modelo("D")}}
    For nI := 1 To Len(aModelos)
        If aModelos[nI][2] == 0
            aAdd(aErros, "Não achei campo de usuário do tipo " + aModelos[nI][1] + " no dicionário para usar de modelo.")
        EndIf
    Next nI
    SX7->(DbGoTop())
    If SX7->(Eof())
        aAdd(aErros, "SX7 vazio: sem registro modelo para os gatilhos.")
    EndIf

    // O que falta criar
    For nI := 1 To Len(aCampos)
        aAdd(aFazCpo, {IIf(RecCampo(aCampos[nI][1]) > 0, "JA", "CRIAR"), aCampos[nI]})
    Next nI
    SIX->(DbSetOrder(1))
    For nI := 1 To Len(aIdx)
        aAdd(aFazIdx, {IIf(SIX->(DbSeek("ZHF" + aIdx[nI][1])), "JA", "CRIAR"), aIdx[nI]})
    Next nI
    SX7->(DbSetOrder(1))
    For nI := 1 To Len(aGat)
        aAdd(aFazGat, {IIf(SX7->(DbSeek(PadR(aGat[nI][1], Len(SX7->X7_CAMPO)) + aGat[nI][2])), "JA", "CRIAR"), aGat[nI]})
    Next nI

    // Campo novo numa ZHF que já existe: precisa da tabela livre
    If !lSimula .And. Empty(aErros) .And. !lNova .And. aScan(aFazCpo, {|x| x[1] == "CRIAR"}) > 0 .And. !Exclusiva("ZHF")
        aAdd(aErros, "A tabela ZHF está em uso. Tire todos da rotina de Históricos e do Cadastro de Funcionários e tente de novo.")
    EndIf

    // Relatório do plano
    cLog += "Tabela ZHF: " + IIf(lNova, "será criada (compartilhamento igual ao da SRA: " + ;
        SX2->X2_MODO + SX2->X2_MODOUN + SX2->X2_MODOEMP + ")", "já existe no dicionário") + CRLF + CRLF
    cLog += "CAMPOS:" + CRLF
    For nI := 1 To Len(aFazCpo)
        cLog += IIf(aFazCpo[nI][1] == "JA", "  JÁ EXISTE (não mexe)  ", "  CRIAR                 ") + ;
            PadR(aFazCpo[nI][2][1], 11) + aFazCpo[nI][2][2] + " " + PadL(cValToChar(aFazCpo[nI][2][3]), 3) + "  " + aFazCpo[nI][2][5] + CRLF
    Next nI
    cLog += "ÍNDICES:" + CRLF
    For nI := 1 To Len(aFazIdx)
        cLog += IIf(aFazIdx[nI][1] == "JA", "  JÁ EXISTE (não mexe)  ", "  CRIAR                 ") + ;
            aFazIdx[nI][2][1] + "  " + aFazIdx[nI][2][2] + CRLF
    Next nI
    cLog += "GATILHOS:" + CRLF
    For nI := 1 To Len(aFazGat)
        cLog += IIf(aFazGat[nI][1] == "JA", "  JÁ EXISTE (não mexe)  ", "  CRIAR                 ") + ;
            PadR(aFazGat[nI][2][1], 11) + aFazGat[nI][2][2] + " -> " + aFazGat[nI][2][3] + CRLF
    Next nI

    If !Empty(aErros)
        Return Problemas(cLog, aErros)
    EndIf
    If lSimula
        cLog += CRLF + "Simulação concluída sem problemas. Nada foi gravado." + CRLF
        Return Salva(cLog)
    EndIf

    // ---------------- 2) Gravação do dicionário ----------------
    cLog += CRLF + "GRAVAÇÃO:" + CRLF
    If lNova
        CriaSX2()
        cLog += "  ZHF criada no SX2." + CRLF
    EndIf
    cOrdem := ProxOrdem()
    For nI := 1 To Len(aFazCpo)
        If aFazCpo[nI][1] == "CRIAR"
            CriaSX3(aFazCpo[nI][2], cOrdem, aGat)
            cLog += "  " + aFazCpo[nI][2][1] + " criado na ordem " + cOrdem + CRLF
            cOrdem := Soma1(cOrdem)
        EndIf
    Next nI
    For nI := 1 To Len(aFazIdx)
        If aFazIdx[nI][1] == "CRIAR"
            CriaSIX(aFazIdx[nI][2])
            cLog += "  índice " + aFazIdx[nI][2][1] + " criado." + CRLF
        EndIf
    Next nI
    For nI := 1 To Len(aFazGat)
        If aFazGat[nI][1] == "CRIAR"
            CriaSX7(aFazGat[nI][2])
            cLog += "  gatilho " + AllTrim(aFazGat[nI][2][1]) + "/" + aFazGat[nI][2][2] + " criado." + CRLF
        EndIf
    Next nI

    // ---------------- 3) Tabela física ----------------
    cLog += CRLF + "TABELA NO BANCO:" + CRLF
    If Select("ZHF") > 0
        ZHF->(DbCloseArea())
    EndIf
    __SetX31Mode(.F.)
    X31UpdTable("ZHF")
    If __GetX31Error()
        cLog += "  ERRO ao atualizar ZHF: " + __GetX31Trace() + CRLF
    Else
        DbSelectArea("ZHF")
        cLog += "  ZHF criada/atualizada." + CRLF
    EndIf
    cLog += CRLF + "Concluído. Próximo passo: rodar o compatibilizador UPDZHF01 (v3)." + CRLF
Return Salva(cLog)

/*/{Protheus.doc} Campos
Campos da ZHF (v1 + v2), na ordem da tela. Iguais aos da base de desenvolvimento.
@type static function
@return array, {cCampo, cTipo, nTam, cTitulo, cDescr, cPicture, cValid, cCbox, cBrowse, cVisual, cF3, cGrpSXG,
    cRelacao, cIniBrw, cContexto}
/*/
Static Function Campos() as Array
    Local aRet := {} as Array
    Local aMat := InfoCpo("RA_MAT") as Array
    Local aNom := InfoCpo("RA_NOME") as Array
    Local aFil := InfoCpo("RA_FILIAL") as Array

    aAdd(aRet, {"ZHF_FILIAL", "C", aFil[1], "Filial", "Filial do Sistema", "", "", "", "N", "A", "", "", "", "", "R"})
    aAdd(aRet, {"ZHF_MAT", "C", aMat[1], "Matricula", "Matricula do funcionario", "@!", "", "", "S", "A", "SRA", aMat[3], "U_CBXHISI()", "", "R"})
    aAdd(aRet, {"ZHF_NOME", "C", aNom[1], "Nome", "Nome do funcionario", "@!", "", "", "S", "V", "", "", "U_CBXHISN()", ;
        "Posicione('SRA',1,ZHF->ZHF_FILIAL+ZHF->ZHF_MAT,'RA_NOME')", "V"})
    aAdd(aRet, {"ZHF_TIPO", "C", 2, "Tipo Hist.", "Tipo do historico", "@!", "", "#U_CBXHISC()", "S", "A", "", "", "", "", "R"})
    aAdd(aRet, {"ZHF_SEQ", "C", 3, "Sequencia", "Sequencia do historico", "@!", "", "", "S", "V", "", "", "", "", "R"})
    aAdd(aRet, {"ZHF_DATA", "D", 8, "Data Inicial", "Data inicial do historico", "", "", "", "S", "A", "", "", "dDataBase", "", "R"})
    aAdd(aRet, {"ZHF_DTFIM", "D", 8, "Data Final", "Data final do historico", "", "", "", "S", "A", "", "", "", "", "R"})
    aAdd(aRet, {"ZHF_SITUAC", "C", 1, "Situacao", "Situacao Sim/Nao", "@!", "", "1=Sim;2=Não", "S", "A", "", "", "", "", "R"})
    aAdd(aRet, {"ZHF_PENAL", "C", 1, "Penalidade", "Tipo de penalidade", "@!", "", "1=Advertência;2=Suspensão;3=TAC", "S", "A", "", "", "", "", "R"})
    aAdd(aRet, {"ZHF_TPAUX", "C", 1, "Tipo Auxilio", "Tipo de auxilio", "@!", "", "1=Creche;2=Creche judicial;3=Financeiro;4=Financeiro judicial", "S", "A", "", "", "", "", "R"})
    aAdd(aRet, {"ZHF_DEPEND", "C", 2, "Dependente", "Seq. do dependente", "@!", "", "", "N", "A", "", "", "", "", "R"})
    aAdd(aRet, {"ZHF_PROCES", "C", 22, "Processo", "Numero do processo", "", "", "", "S", "A", "", "", "", "", "R"})
    aAdd(aRet, {"ZHF_VLANT", "C", 60, "Valor ant.", "Valor anterior", "", "", "", "S", "V", "", "", "", "", "R"})
    aAdd(aRet, {"ZHF_VLNOV", "C", 60, "Valor novo", "Valor novo", "", "", "", "S", "A", "", "", "", "", "R"})
    aAdd(aRet, {"ZHF_ORIGEM", "C", 1, "Origem", "Origem do registro", "@!", "", "1=Manual;2=Automática;3=Carga inicial", "S", "V", "", "", "'1'", "", "R"})
    aAdd(aRet, {"ZHF_USER", "C", 25, "Usuario", "Usuario que gravou", "", "", "", "S", "V", "", "", "", "", "R"})
    aAdd(aRet, {"ZHF_DTINC", "D", 8, "Dt. Inclusao", "Data da gravacao", "", "", "", "N", "V", "", "", "", "", "R"})
    aAdd(aRet, {"ZHF_HRINC", "C", 8, "Hr. Inclusao", "Hora da gravacao", "", "", "", "N", "V", "", "", "", "", "R"})
Return aRet

/*/{Protheus.doc} Indices
Índices da ZHF.
@type static function
@return array, {cOrdem, cChave, cDescricao}
/*/
Static Function Indices() as Array
Return {{"1", "ZHF_FILIAL+ZHF_MAT+ZHF_TIPO+ZHF_SEQ", "Matricula + Tipo + Seq."}, ;
    {"2", "ZHF_FILIAL+ZHF_TIPO+DTOS(ZHF_DATA)", "Tipo + Data"}}

/*/{Protheus.doc} Gatilhos
Gatilho da ZHF: a matrícula traz o nome do funcionário.
@type static function
@return array, {cCampo, cSequenc, cDestino, cRegra, cSeek, cAlias, nOrdem, cChave}
/*/
Static Function Gatilhos() as Array
Return {{"ZHF_MAT", "001", "ZHF_NOME", "SRA->RA_NOME", "S", "SRA", 1, "xFilial('SRA')+FwFldGet('ZHF_MAT')"}}

/*/{Protheus.doc} CriaSX2
Cria a ZHF no SX2 copiando a SRA (mesmo compartilhamento).
@type static function
/*/
Static Function CriaSX2()
    Local nRec := 0 as Numeric

    SX2->(DbSetOrder(1))
    SX2->(DbSeek("SRA"))
    nRec := SX2->(Recno())
    CopiaReg("SX2", nRec, { ;
        {"X2_CHAVE", "ZHF"}, {"X2_ARQUIVO", StrTran(SX2->X2_ARQUIVO, "SRA", "ZHF")}, ;
        {"X2_NOME", "Historicos Funcionario"}, {"X2_NOMESPA", "Historicos Funcionario"}, ;
        {"X2_NOMEENG", "Employee History"}, {"X2_UNICO", "ZHF_FILIAL+ZHF_MAT+ZHF_TIPO+ZHF_SEQ"}, {"X2_ROTINA", ""}, ;
        {"X2_DISPLAY", ""}, {"X2_SYSOBJ", ""}, {"X2_USROBJ", ""}, {"X2_PYME", "S"}})
Return

/*/{Protheus.doc} CriaSX3
Cria o campo copiando um campo modelo (mesmo tipo) e trocando as propriedades.
A filial copia o RA_FILIAL (mesmo tamanho e grupo de campos).
@type static function
/*/
Static Function CriaSX3(aCpo as Array, cOrdem as Character, aGat as Array)
    Local aTroca := {} as Array
    Local cTrig  := IIf(aScan(aGat, {|x| AllTrim(x[1]) == aCpo[1]}) > 0, "S", "") as Character

    If aCpo[1] == "ZHF_FILIAL"
        CopiaReg("SX3", RecCampo("RA_FILIAL"), {{"X3_ARQUIVO", "ZHF"}, {"X3_ORDEM", cOrdem}, ;
            {"X3_CAMPO", "ZHF_FILIAL"}, {"X3_PROPRI", "U"}, {"X3_TRIGGER", ""}, {"X3_VALID", ""}, ;
            {"X3_VLDUSER", ""}, {"X3_RELACAO", ""}, {"X3_F3", ""}, {"X3_WHEN", ""}, {"X3_INIBRW", ""}})
        Return
    EndIf

    aTroca := { ;
        {"X3_ARQUIVO", "ZHF"}, {"X3_ORDEM", cOrdem}, {"X3_CAMPO", aCpo[1]}, {"X3_TIPO", aCpo[2]}, ;
        {"X3_TAMANHO", aCpo[3]}, {"X3_DECIMAL", 0}, ;
        {"X3_TITULO", aCpo[4]}, {"X3_TITSPA", aCpo[4]}, {"X3_TITENG", aCpo[4]}, ;
        {"X3_DESCRIC", aCpo[5]}, {"X3_DESCSPA", aCpo[5]}, {"X3_DESCENG", aCpo[5]}, ;
        {"X3_PICTURE", aCpo[6]}, {"X3_VALID", aCpo[7]}, {"X3_VLDUSER", ""}, {"X3_WHEN", ""}, ;
        {"X3_CBOX", aCpo[8]}, {"X3_CBOXSPA", aCpo[8]}, {"X3_CBOXENG", aCpo[8]}, ;
        {"X3_BROWSE", aCpo[9]}, {"X3_VISUAL", aCpo[10]}, {"X3_FOLDER", ""}, ;
        {"X3_F3", aCpo[11]}, {"X3_GRPSXG", aCpo[12]}, {"X3_TRIGGER", cTrig}, ;
        {"X3_RELACAO", aCpo[13]}, {"X3_INIBRW", aCpo[14]}, {"X3_PICTVAR", ""}, ;
        {"X3_CONTEXT", aCpo[15]}, {"X3_PROPRI", "U"}, {"X3_OBRIGAT", ""}, {"X3_AGRUP", ""}, ;
        {"X3_CHKSQL", ""}, {"X3_CONDSQL", ""}}
    CopiaReg("SX3", Modelo(aCpo[2]), aTroca)
Return

/*/{Protheus.doc} CriaSIX
Cria um índice da ZHF copiando o índice 1 da SRA.
@type static function
/*/
Static Function CriaSIX(aIdx as Array)
    Local nRec := 0 as Numeric

    SIX->(DbSetOrder(1))
    SIX->(DbSeek("SRA1"))
    nRec := SIX->(Recno())
    CopiaReg("SIX", nRec, { ;
        {"INDICE", "ZHF"}, {"ORDEM", aIdx[1]}, {"CHAVE", aIdx[2]}, ;
        {"DESCRICAO", aIdx[3]}, {"DESCSPA", aIdx[3]}, {"DESCENG", aIdx[3]}, ;
        {"NICKNAME", ""}, {"F3", ""}, {"SHOWPESQ", "S"}, {"PROPRI", "U"}})
Return

/*/{Protheus.doc} CriaSX7
Cria um gatilho copiando o primeiro registro do SX7 e trocando as propriedades.
@type static function
/*/
Static Function CriaSX7(aGat as Array)
    SX7->(DbGoTop())
    CopiaReg("SX7", SX7->(Recno()), { ;
        {"X7_CAMPO", aGat[1]}, {"X7_SEQUENC", aGat[2]}, {"X7_REGRA", aGat[4]}, {"X7_CDOMIN", aGat[3]}, ;
        {"X7_TIPO", "P"}, {"X7_SEEK", aGat[5]}, {"X7_ALIAS", aGat[6]}, {"X7_ORDEM", aGat[7]}, {"X7_CHAVE", aGat[8]}, ;
        {"X7_CONDIC", ""}, {"X7_PROPRI", "U"}})
Return

/*/{Protheus.doc} CopiaReg
Inclui um registro novo copiando todos os campos de outro registro e trocando os
indicados (só os que existem na estrutura).
@type static function
/*/
Static Function CopiaReg(cAlias as Character, nRecMod as Numeric, aTroca as Array)
    Local aVal := {} as Array
    Local nI   := 0 as Numeric
    Local nPos := 0 as Numeric

    (cAlias)->(DbGoTo(nRecMod))
    For nI := 1 To (cAlias)->(FCount())
        aAdd(aVal, (cAlias)->(FieldGet(nI)))
    Next nI

    RecLock(cAlias, .T.)
    For nI := 1 To Len(aVal)
        (cAlias)->(FieldPut(nI, aVal[nI]))
    Next nI
    For nI := 1 To Len(aTroca)
        nPos := (cAlias)->(FieldPos(aTroca[nI][1]))
        If nPos > 0
            (cAlias)->(FieldPut(nPos, aTroca[nI][2]))
        EndIf
    Next nI
    (cAlias)->(MsUnlock())
Return

/*/{Protheus.doc} Modelo
Recno de um campo para servir de modelo: campo de usuário do tipo pedido, usado,
contexto real e não obrigatório (primeiro na SRA, depois em qualquer tabela).
@type static function
@return numeric, recno no SX3 (0 quando não acha)
/*/
Static Function Modelo(cTipo as Character) as Numeric
    Local nRec  := 0 as Numeric
    Local aArea := SX3->(GetArea()) as Array

    SX3->(DbSetOrder(1))
    SX3->(DbSeek("SRA"))
    While !SX3->(Eof()) .And. SX3->X3_ARQUIVO == "SRA"
        If ModeloOk(cTipo)
            nRec := SX3->(Recno())
            Exit
        EndIf
        SX3->(DbSkip())
    EndDo
    If nRec == 0
        SX3->(DbGoTop())
        While !SX3->(Eof())
            If ModeloOk(cTipo)
                nRec := SX3->(Recno())
                Exit
            EndIf
            SX3->(DbSkip())
        EndDo
    EndIf
    RestArea(aArea)
Return nRec

/*/{Protheus.doc} ModeloOk
Indica se o registro posicionado no SX3 serve de modelo para o tipo.
@type static function
/*/
Static Function ModeloOk(cTipo as Character) as Logical
Return SX3->X3_TIPO == cTipo .And. SX3->X3_PROPRI == "U" .And. SX3->X3_CONTEXT <> "V" .And. ;
    !("_FILIAL" $ SX3->X3_CAMPO) .And. X3Uso(SX3->X3_USADO) .And. !X3Obrigat(SX3->X3_CAMPO)

/*/{Protheus.doc} InfoCpo
Tamanho, consulta (F3) e grupo de campos (SXG) de um campo de referência.
@type static function
@return array, {nTam, cF3, cGrpSXG}
/*/
Static Function InfoCpo(cCampo as Character) as Array
    Local aRet  := {0, "", ""} as Array
    Local aArea := SX3->(GetArea()) as Array

    SX3->(DbSetOrder(2))
    If SX3->(DbSeek(PadR(cCampo, 10)))
        aRet := {SX3->X3_TAMANHO, AllTrim(SX3->X3_F3), AllTrim(SX3->X3_GRPSXG)}
    EndIf
    RestArea(aArea)
Return aRet

/*/{Protheus.doc} RecCampo
Recno de um campo no SX3 (0 quando não existe).
@type static function
/*/
Static Function RecCampo(cCampo as Character) as Numeric
    Local nRec  := 0 as Numeric
    Local aArea := SX3->(GetArea()) as Array

    SX3->(DbSetOrder(2))
    If SX3->(DbSeek(PadR(cCampo, 10)))
        nRec := SX3->(Recno())
    EndIf
    RestArea(aArea)
Return nRec

/*/{Protheus.doc} ProxOrdem
Próxima ordem livre da ZHF no SX3.
@type static function
/*/
Static Function ProxOrdem() as Character
    Local cMaior := "00" as Character
    Local aArea  := SX3->(GetArea()) as Array

    SX3->(DbSetOrder(1))
    SX3->(DbSeek("ZHF"))
    While !SX3->(Eof()) .And. SX3->X3_ARQUIVO == "ZHF"
        If SX3->X3_ORDEM > cMaior
            cMaior := SX3->X3_ORDEM
        EndIf
        SX3->(DbSkip())
    EndDo
    RestArea(aArea)
Return Soma1(cMaior)

/*/{Protheus.doc} Diferencas
ZHF já existente (v1): avisa no relatório o que está diferente da v2 (não altera).
@type static function
@param cLog, character, relatório (por referência)
/*/
Static Function Diferencas(cLog as Character)
    Local aInfo := {} as Array

    aInfo := InfoCpo("ZHF_PROCES")
    If aInfo[1] > 0 .And. aInfo[1] <> 22
        cLog += "AVISO: ZHF_PROCES tem tamanho " + cValToChar(aInfo[1]) + " (na v2 é 22). Ajustar no Configurador se quiser." + CRLF
    EndIf
    SX3->(DbSetOrder(2))
    If SX3->(DbSeek(PadR("ZHF_DATA", 10))) .And. !("INICIAL" $ Upper(SX3->X3_TITULO))
        cLog += "AVISO: título do ZHF_DATA é '" + AllTrim(SX3->X3_TITULO) + "' (na v2 é 'Data Inicial'). Ajustar no Configurador se quiser." + CRLF
    EndIf
Return

/*/{Protheus.doc} Exclusiva
Tenta abrir a tabela em modo exclusivo para saber se alguém está usando.
@type static function
/*/
Static Function Exclusiva(cArq as Character) as Logical
    Local lRet := .F. as Logical

    If Select(cArq) > 0
        (cArq)->(DbCloseArea())
    EndIf
    DbUseArea(.T., "TOPCONN", RetSqlName(cArq), "HISEXC", .F., .F.)
    lRet := Select("HISEXC") > 0
    If lRet
        HISEXC->(DbCloseArea())
    EndIf
Return lRet

/*/{Protheus.doc} Problemas
Acrescenta os problemas ao relatório e salva (nada foi gravado).
@type static function
/*/
Static Function Problemas(cLog as Character, aErros as Array) as Character
    Local nI := 0 as Numeric

    cLog += CRLF + "PROBLEMAS ENCONTRADOS - NADA FOI GRAVADO:" + CRLF
    For nI := 1 To Len(aErros)
        cLog += "  - " + aErros[nI] + CRLF
    Next nI
Return Salva(cLog)

/*/{Protheus.doc} Salva
Grava o relatório em \system e devolve o texto.
@type static function
/*/
Static Function Salva(cLog as Character) as Character
    Local cArq := "\system\updzhf00_" + DToS(Date()) + "_" + StrTran(Time(), ":", "") + ".log" as Character

    MemoWrite(cArq, cLog)
Return cLog + CRLF + "Relatório salvo em " + cArq + CRLF

/*/{Protheus.doc} MostraLog
Mostra o relatório em uma janela.
@type static function
/*/
Static Function MostraLog(cLog as Character)
    Local oDlg := Nil as Object

    DEFINE MSDIALOG oDlg TITLE "UPDZHF00 - resultado" FROM 0, 0 TO 520, 820 PIXEL
    TMultiGet():New(5, 5, {|u| IIf(PCount() > 0, cLog := u, cLog)}, oDlg, 400, 230, , , , , , .T., , , , , , .T.)
    TButton():New(240, 355, "Fechar", oDlg, {|| oDlg:End()}, 50, 14, , , , .T.)
    ACTIVATE MSDIALOG oDlg CENTERED
Return
