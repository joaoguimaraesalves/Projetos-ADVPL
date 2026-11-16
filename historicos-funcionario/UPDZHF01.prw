#include "totvs.ch"

// Empresa/filial usadas quando o programa é chamado como Programa Inicial (sem ambiente aberto)
#Define HIS_EMP "01"
#Define HIS_FIL "01"

/*/{Protheus.doc} UPDZHF01
Compatibilizador do dicionário da v3 dos Históricos do Funcionário:
- SRA: prazo e datas de início/fim da periculosidade e insalubridade (aba Adicionais);
- ZHF: auditoria (código, login e matrícula de quem incluiu/alterou, data e hora);
- ZHG: tabela nova de log de auditoria (campos e índices).

Segurança:
- SIMULAR mostra tudo o que seria feito e os problemas encontrados, sem gravar nada;
- só ACRESCENTA: campo que já existe não é alterado (só é avisado); a única mudança
  em campo existente é deixar o ZHF_USER visível na lista (campo da própria customização);
- antes de gravar confere: fontes v3 compilados, ZHF já implantada, aba "Adicionais"
  existente e SRA/ZHF livres (ninguém usando). Se algo falhar, NÃO grava nada;
- a ordem dos campos novos é a próxima livre de cada tabela (não reaproveita ordem de
  campo existente), na sequência Prazo, Início e Fim de cada adicional;
- pode ser executado de novo: o que já existe é ignorado;
- o resultado fica salvo em \system\updzhf01_AAAAMMDD_HHMMSS.log.

Uso: SmartClient/WebApp com Programa Inicial U_UPDZHF01 (empresa HIS_EMP/filial HIS_FIL),
ou chamado de dentro do sistema já logado na empresa desejada.
@type user function
@author João Victor Guimarães Alves
@since 11/11/2026
/*/
User Function UPDZHF01()
    Local nOpc    := 0 as Numeric
    Local lSimula := .T. as Logical
    Local lAbriu  := .F. as Logical
    Local cLog    := "" as Character

    nOpc := Aviso("Históricos do Funcionário - dicionário v3", ;
        "Cria no dicionário os campos da v3: prazo e datas dos adicionais (SRA, aba Adicionais), " + ;
        "auditoria na ZHF e a tabela de log ZHG." + CRLF + CRLF + ;
        "SIMULAR: só mostra o que seria feito. Não grava nada." + CRLF + ;
        "EXECUTAR: grava. Antes faça backup do banco e tire os usuários do sistema.", ;
        {"Simular", "Executar", "Cancelar"}, 3)
    If nOpc <> 1 .And. nOpc <> 2
        Return
    EndIf
    lSimula := (nOpc == 1)

    If !lSimula .And. !MsgYesNo("Confirma a EXECUÇÃO? O backup do banco foi feito e não há usuários usando o sistema?", "Confirmação")
        Return
    EndIf

    If Type("cEmpAnt") <> "C" .Or. Empty(cEmpAnt)
        RpcSetType(3)
        If !RpcSetEnv(HIS_EMP, HIS_FIL)
            MsgStop("Não foi possível abrir a empresa " + HIS_EMP + " / filial " + HIS_FIL + ".", "UPDZHF01")
            Return
        EndIf
        lAbriu := .T.
    EndIf

    FWMsgRun(, {|| cLog := U_UPDZHF1X(lSimula)}, "UPDZHF01", IIf(lSimula, "Simulando...", "Atualizando o dicionário..."))
    MostraLog(cLog)

    If lAbriu
        RpcClearEnv()
    EndIf
Return

/*/{Protheus.doc} UPDZHF1X
Faz a conferência e (fora da simulação) grava o dicionário da v3. Precisa do ambiente
aberto (RpcSetEnv ou sistema logado).
@type user function
@author João Victor Guimarães Alves
@since 11/11/2026
@param lSimula, logical, .T. = só mostra o que seria feito
@return character, relatório do que foi feito
/*/
User Function UPDZHF1X(lSimula as Logical) as Character
    Local cLog    := "" as Character
    Local aErros  := {} as Array
    Local aFazer  := {} as Array
    Local aCampos := Campos() as Array
    Local cPasta  := "" as Character
    Local cOrdSRA := "" as Character
    Local cOrdZHF := "" as Character
    Local lZHG    := .F. as Logical
    Local lUser   := .F. as Logical
    Local aFontes := {"U_CBXHISK", "U_CBXHISW", "U_CBXHISR", "U_CBXHISA", "U_CBGPA21L", "U_CBXHISE"} as Array
    Local nI      := 0 as Numeric
    Local cArq    := "" as Character
    Local aAtuTab := {} as Array
    Local lIdxInc := .F. as Logical

    Default lSimula := .T.

    cLog += "UPDZHF01 - dicionário v3 dos Históricos do Funcionário" + CRLF
    cLog += "Data: " + DToC(Date()) + " " + Time() + "  Empresa: " + cEmpAnt + "  Filial: " + cFilAnt + CRLF
    cLog += "Modo: " + IIf(lSimula, "SIMULAÇÃO (nada é gravado)", "EXECUÇÃO") + CRLF + Replicate("-", 70) + CRLF

    // ---------------- 1) Conferências (não grava nada) ----------------
    For nI := 1 To Len(aFontes)
        If !FindFunction(aFontes[nI])
            aAdd(aErros, "Fonte da v3 não compilado no RPO: " + aFontes[nI] + " (compilar CBGPEX01.tlpp e CBGPEA21.prw antes).")
        EndIf
    Next nI

    SX2->(DbSetOrder(1))
    If !SX2->(DbSeek("ZHF"))
        aAdd(aErros, "Tabela ZHF não existe no dicionário: implantar a v1/v2 dos Históricos antes.")
    EndIf
    lZHG := SX2->(DbSeek("ZHG"))

    cPasta := PastaSRA("ADICIONAIS")
    If Empty(cPasta)
        aAdd(aErros, "Aba 'Adicionais' do Cadastro de Funcionários não encontrada na SXA.")
    EndIf

    cOrdSRA := ProxOrdem("SRA")
    cOrdZHF := ProxOrdem("ZHF")

    // O que falta criar
    For nI := 1 To Len(aCampos)
        cArq := aCampos[nI][1]
        If cArq == "ZHG" .And. lZHG .And. ExisteCpo(aCampos[nI][2])
            aAdd(aFazer, {"JA", aCampos[nI]})
        ElseIf ExisteCpo(aCampos[nI][2])
            aAdd(aFazer, {"JA", aCampos[nI]})
        Else
            aAdd(aFazer, {"CRIAR", aCampos[nI]})
        EndIf
    Next nI
    lIdxInc := (IdxInc() == 0) // índice 3 da ZHF (ordem de gravação) ainda não existe
    lUser := ExisteCpo("ZHF_USER") .And. AllTrim(Posicione("SX3", 2, PadR("ZHF_USER", 10), "X3_BROWSE")) <> "S"

    // Modelos de registro para copiar (X3_USADO/X3_RESERV corretos para campo de usuário)
    If Empty(Modelo("SRA", "C")) .Or. Empty(Modelo("SRA", "D"))
        aAdd(aErros, "Não achei campo de usuário (C e D) na SRA para usar de modelo.")
    EndIf
    If Empty(Modelo("ZHF", "C")) .Or. Empty(Modelo("ZHF", "D"))
        aAdd(aErros, "Não achei campos C e D na ZHF para usar de modelo.")
    EndIf

    // Tabelas livres (só na execução: a criação das colunas precisa de acesso exclusivo)
    If !lSimula .And. Empty(aErros)
        If PrecisaTab(aFazer, "SRA") .And. !Exclusiva("SRA")
            aAdd(aErros, "A tabela SRA está em uso (usuários, jobs ou serviços). Tire todos do sistema e tente de novo.")
        EndIf
        If (PrecisaTab(aFazer, "ZHF") .Or. lUser .Or. lIdxInc) .And. !Exclusiva("ZHF")
            aAdd(aErros, "A tabela ZHF está em uso. Tire todos do sistema e tente de novo.")
        EndIf
    EndIf

    // Relatório do plano
    cLog += "Aba Adicionais da SRA: " + IIf(Empty(cPasta), "NÃO ENCONTRADA", "código " + cPasta) + CRLF
    cLog += "Próxima ordem livre: SRA " + cOrdSRA + " / ZHF " + cOrdZHF + CRLF
    cLog += "Tabela ZHG: " + IIf(lZHG, "já existe no dicionário", "será criada") + CRLF + CRLF
    For nI := 1 To Len(aFazer)
        cLog += IIf(aFazer[nI][1] == "JA", "JÁ EXISTE (não mexe)  ", "CRIAR                 ") + ;
            PadR(aFazer[nI][2][2], 11) + " " + aFazer[nI][2][3] + " " + PadL(cValToChar(aFazer[nI][2][4]), 3) + "  " + aFazer[nI][2][5] + CRLF
    Next nI
    If lUser
        cLog += "ALTERAR               ZHF_USER    mostrar na lista (Browse = Sim)" + CRLF
    EndIf
    If !lZHG
        cLog += "CRIAR                 ZHG (tabela) e índices 1 e 2" + CRLF
    EndIf
    If lIdxInc
        cLog += "CRIAR                 ZHF índice Matricula + Dt.Inclusao + Hora (ordem da tela)" + CRLF
    EndIf

    If !Empty(aErros)
        cLog += CRLF + "PROBLEMAS ENCONTRADOS - NADA FOI GRAVADO:" + CRLF
        For nI := 1 To Len(aErros)
            cLog += "  - " + aErros[nI] + CRLF
        Next nI
        Return Salva(cLog)
    EndIf

    If lSimula
        cLog += CRLF + "Simulação concluída sem problemas. Nada foi gravado." + CRLF
        Return Salva(cLog)
    EndIf

    // ---------------- 2) Gravação do dicionário ----------------
    cLog += CRLF + "GRAVAÇÃO:" + CRLF
    If !lZHG
        CriaSX2ZHG()
        CriaSIXZHG()
        cLog += "  ZHG criada no SX2 e SIX." + CRLF
    EndIf
    For nI := 1 To Len(aFazer)
        If aFazer[nI][1] == "CRIAR"
            cArq := aFazer[nI][2][1]
            If cArq == "SRA"
                CriaSX3(aFazer[nI][2], cOrdSRA, cPasta)
                cLog += "  " + aFazer[nI][2][2] + " criado na ordem " + cOrdSRA + " (aba " + cPasta + ")" + CRLF
                cOrdSRA := Soma1(cOrdSRA)
            ElseIf cArq == "ZHF"
                CriaSX3(aFazer[nI][2], cOrdZHF, "")
                If AllTrim(aFazer[nI][2][2]) == "ZHF_DESCR"
                    cLog += "  ZHF_DESCR criado (virtual) na ordem " + AjustaDescr() + ", logo depois do Nome" + CRLF
                Else
                    cLog += "  " + aFazer[nI][2][2] + " criado na ordem " + cOrdZHF + CRLF
                EndIf
                cOrdZHF := Soma1(cOrdZHF)
            Else
                CriaSX3(aFazer[nI][2], aFazer[nI][2][13], "")
                cLog += "  " + aFazer[nI][2][2] + " criado" + CRLF
            EndIf
            If aScan(aAtuTab, cArq) == 0
                aAdd(aAtuTab, cArq)
            EndIf
        EndIf
    Next nI
    If lUser
        SX3->(DbSetOrder(2))
        If SX3->(DbSeek(PadR("ZHF_USER", 10)))
            RecLock("SX3", .F.)
            SX3->X3_BROWSE := "S"
            SX3->(MsUnlock())
            cLog += "  ZHF_USER agora aparece na lista." + CRLF
        EndIf
    EndIf
    If lIdxInc
        CriaIdxInc()
        cLog += "  ZHF: índice Matricula + Dt.Inclusao + Hora criado (ordem " + cValToChar(IdxInc()) + ")." + CRLF
        If aScan(aAtuTab, "ZHF") == 0
            aAdd(aAtuTab, "ZHF")
        EndIf
    EndIf

    // ---------------- 3) Tabelas físicas ----------------
    cLog += CRLF + "TABELAS NO BANCO:" + CRLF
    __SetX31Mode(.F.)
    For nI := 1 To Len(aAtuTab)
        If Select(aAtuTab[nI]) > 0
            (aAtuTab[nI])->(DbCloseArea())
        EndIf
        X31UpdTable(aAtuTab[nI])
        If __GetX31Error()
            cLog += "  ERRO ao atualizar " + aAtuTab[nI] + ": " + __GetX31Trace() + CRLF
        Else
            cLog += "  " + aAtuTab[nI] + " atualizada." + CRLF
        EndIf
        DbSelectArea(aAtuTab[nI])
    Next nI
    cLog += CRLF + "Concluído. Conferir a aba Adicionais do Cadastro de Funcionários e os Históricos." + CRLF
Return Salva(cLog)

/*/{Protheus.doc} Campos
Definição dos campos da v3, na ordem em que entram na tela.
@type static function
@return array, {cArq, cCampo, cTipo, nTam, cTitulo, cDescr, cPicture, cValid, cVldUser, cWhen, cCbox, cBrowse, cOrdemFixa(ZHG), cVisual}
/*/
Static Function Campos() as Array
    Local aRet  := {} as Array
    Local cPrz  := "1=Indeterminado;2=Determinado" as Character
    Local cVld  := "U_CBXHISK()" as Character
    Local cOper := "1=Inclusão;2=Alteração;3=Exclusão" as Character

    // SRA - aba Adicionais: Prazo, Início e Fim de cada adicional (nesta ordem)
    aAdd(aRet, {"SRA", "RA_XPERPRZ", "C", 1, "Prazo Peric.", "Prazo da periculosidade", "@!", 'Vazio() .Or. Pertence("12")', cVld, 'U_CBXHISW("RA_XPERPRZ")', cPrz, "N", "", "A"})
    aAdd(aRet, {"SRA", "RA_XPERDTI", "D", 8, "Dt Ini Peric", "Inicio periculosidade", "", "", cVld, 'U_CBXHISW("RA_XPERDTI")', "", "N", "", "A"})
    aAdd(aRet, {"SRA", "RA_XPERDTF", "D", 8, "Dt Fim Peric", "Fim periculosidade", "", "", cVld, 'U_CBXHISW("RA_XPERDTF")', "", "N", "", "A"})
    aAdd(aRet, {"SRA", "RA_XINSPRZ", "C", 1, "Prazo Insal.", "Prazo da insalubridade", "@!", 'Vazio() .Or. Pertence("12")', cVld, 'U_CBXHISW("RA_XINSPRZ")', cPrz, "N", "", "A"})
    aAdd(aRet, {"SRA", "RA_XINSDTI", "D", 8, "Dt Ini Insal", "Inicio insalubridade", "", "", cVld, 'U_CBXHISW("RA_XINSDTI")', "", "N", "", "A"})
    aAdd(aRet, {"SRA", "RA_XINSDTF", "D", 8, "Dt Fim Insal", "Fim insalubridade", "", "", cVld, 'U_CBXHISW("RA_XINSDTF")', "", "N", "", "A"})

    // ZHF - auditoria (somente leitura na tela)
    aAdd(aRet, {"ZHF", "ZHF_CODUSR", "C", 6, "Cod.Usr.Inc.", "Codigo usuario inclusao", "", "", "", "", "", "N", "", "V"})
    aAdd(aRet, {"ZHF", "ZHF_MATINC", "C", 6, "Mat.Usr.Inc.", "Matric. usuario inclusao", "", "", "", "", "", "S", "", "V"})
    aAdd(aRet, {"ZHF", "ZHF_USRALT", "C", 25, "Usr.Alterac.", "Usuario ultima alteracao", "", "", "", "", "", "S", "", "V"})
    aAdd(aRet, {"ZHF", "ZHF_CODALT", "C", 6, "Cod.Usr.Alt.", "Codigo usuario alteracao", "", "", "", "", "", "N", "", "V"})
    aAdd(aRet, {"ZHF", "ZHF_MATALT", "C", 6, "Mat.Usr.Alt.", "Matric. usuario alteracao", "", "", "", "", "", "S", "", "V"})
    aAdd(aRet, {"ZHF", "ZHF_DTALT", "D", 8, "Dt.Alteracao", "Data ultima alteracao", "", "", "", "", "", "S", "", "V"})
    aAdd(aRet, {"ZHF", "ZHF_HRALT", "C", 8, "Hr.Alteracao", "Hora ultima alteracao", "", "", "", "", "", "N", "", "V"})
    // ZHF - coluna Descrição do browse (campo virtual, depois do Nome; 16/11/2026)
    aAdd(aRet, {"ZHF", "ZHF_DESCR", "C", 60, "Descricao", "Descricao por extenso", "", "", "", "", "", "S", "", "V"})

    // ZHG - log de auditoria (tabela nova)
    aAdd(aRet, {"ZHG", "ZHG_FILIAL", "C", Len(xFilial("ZHF")), "Filial", "Filial do Sistema", "", "", "", "", "", "N", "01", "A"})
    aAdd(aRet, {"ZHG", "ZHG_MAT", "C", TamSX3("RA_MAT")[1], "Matricula", "Matricula do funcionario", "", "", "", "", "", "S", "02", "V"})
    aAdd(aRet, {"ZHG", "ZHG_TIPO", "C", 2, "Tipo Hist.", "Tipo do historico", "", "", "", "", "#U_CBXHISC()", "S", "03", "V"})
    aAdd(aRet, {"ZHG", "ZHG_SEQ", "C", 3, "Sequencia", "Sequencia do historico", "", "", "", "", "", "S", "04", "V"})
    aAdd(aRet, {"ZHG", "ZHG_OPER", "C", 1, "Operacao", "Operacao realizada", "", "", "", "", cOper, "S", "05", "V"})
    aAdd(aRet, {"ZHG", "ZHG_CODUSR", "C", 6, "Cod.Usuario", "Codigo usuario Protheus", "", "", "", "", "", "S", "06", "V"})
    aAdd(aRet, {"ZHG", "ZHG_USER", "C", 25, "Usuario", "Login do usuario Protheus", "", "", "", "", "", "S", "07", "V"})
    aAdd(aRet, {"ZHG", "ZHG_DATA", "D", 8, "Data", "Data da operacao", "", "", "", "", "", "S", "08", "V"})
    aAdd(aRet, {"ZHG", "ZHG_HORA", "C", 8, "Hora", "Hora da operacao", "", "", "", "", "", "S", "09", "V"})
    aAdd(aRet, {"ZHG", "ZHG_ROTINA", "C", 10, "Rotina", "Rotina que gravou", "", "", "", "", "", "S", "10", "V"})
    aAdd(aRet, {"ZHG", "ZHG_DETALH", "C", 250, "Detalhe", "O que mudou", "", "", "", "", "", "S", "11", "V"})
    aAdd(aRet, {"ZHG", "ZHG_MATUSR", "C", 6, "Mat.Usuario", "Matric. usuario Protheus", "", "", "", "", "", "S", "12", "V"})
Return aRet

/*/{Protheus.doc} CriaSX3
Cria o campo copiando um campo modelo da mesma tabela (mesmo tipo) e trocando as
propriedades. Campo de usuário, contexto real, não obrigatório.
@type static function
/*/
Static Function CriaSX3(aCpo as Array, cOrdem as Character, cPasta as Character)
    Local cArqMod := IIf(aCpo[1] == "ZHG", "ZHF", aCpo[1]) as Character
    Local nRecMod := Modelo(cArqMod, aCpo[3]) as Numeric
    Local aTroca  := {} as Array

    If aCpo[1] == "ZHG" .And. aCpo[2] == "ZHG_FILIAL"
        nRecMod := RecCampo("ZHF_FILIAL")
    EndIf

    aTroca := { ;
        {"X3_ARQUIVO", aCpo[1]}, {"X3_ORDEM", cOrdem}, {"X3_CAMPO", aCpo[2]}, {"X3_TIPO", aCpo[3]}, ;
        {"X3_TAMANHO", aCpo[4]}, {"X3_DECIMAL", 0}, ;
        {"X3_TITULO", aCpo[5]}, {"X3_TITSPA", aCpo[5]}, {"X3_TITENG", aCpo[5]}, ;
        {"X3_DESCRIC", aCpo[6]}, {"X3_DESCSPA", aCpo[6]}, {"X3_DESCENG", aCpo[6]}, ;
        {"X3_PICTURE", aCpo[7]}, {"X3_VALID", aCpo[8]}, {"X3_VLDUSER", aCpo[9]}, {"X3_WHEN", aCpo[10]}, ;
        {"X3_CBOX", aCpo[11]}, {"X3_CBOXSPA", aCpo[11]}, {"X3_CBOXENG", aCpo[11]}, ;
        {"X3_BROWSE", aCpo[12]}, {"X3_VISUAL", aCpo[14]}, {"X3_FOLDER", cPasta}, ;
        {"X3_RELACAO", ""}, {"X3_F3", ""}, {"X3_TRIGGER", ""}, {"X3_INIBRW", ""}, {"X3_PICTVAR", ""}, ;
        {"X3_CONTEXT", "R"}, {"X3_PROPRI", "U"}, {"X3_OBRIGAT", ""}, {"X3_GRPSXG", ""}, {"X3_AGRUP", ""}, ;
        {"X3_CHKSQL", ""}, {"X3_CONDSQL", ""}}
    If aCpo[2] == "ZHG_FILIAL"
        // filial: mantém tamanho/grupo (SXG) e propriedades do ZHF_FILIAL
        aTroca := {{"X3_ARQUIVO", "ZHG"}, {"X3_ORDEM", cOrdem}, {"X3_CAMPO", "ZHG_FILIAL"}}
    EndIf
    CopiaReg("SX3", nRecMod, aTroca)
Return

/*/{Protheus.doc} AjustaDescr
Deixa o ZHF_DESCR como campo virtual só de browse (Inic. Browse U_CBXHISE()) e o
posiciona logo depois do ZHF_NOME, empurrando uma ordem os campos seguintes.
@type static function
@author João Victor Guimarães Alves
@since 16/11/2026
@return character, ordem final do ZHF_DESCR
/*/
Static Function AjustaDescr() as Character
    Local nRecDsc := RecCampo("ZHF_DESCR") as Numeric
    Local cOrdNom := "" as Character
    Local aRecs   := {} as Array
    Local nI      := 0 as Numeric

    If nRecDsc == 0
        Return ""
    EndIf
    SX3->(DbSetOrder(2))
    If SX3->(DbSeek(PadR("ZHF_NOME", 10)))
        cOrdNom := SX3->X3_ORDEM
    EndIf

    // Campos depois do Nome (guarda os recnos antes de mexer na ordem do índice)
    If !Empty(cOrdNom)
        SX3->(DbSetOrder(1))
        SX3->(DbSeek("ZHF"))
        While !SX3->(Eof()) .And. SX3->X3_ARQUIVO == "ZHF"
            If SX3->X3_ORDEM > cOrdNom .And. SX3->(Recno()) <> nRecDsc
                aAdd(aRecs, SX3->(Recno()))
            EndIf
            SX3->(DbSkip())
        EndDo
        For nI := 1 To Len(aRecs)
            SX3->(DbGoTo(aRecs[nI]))
            RecLock("SX3", .F.)
            SX3->X3_ORDEM := Soma1(SX3->X3_ORDEM)
            SX3->(MsUnlock())
        Next nI
    EndIf

    SX3->(DbGoTo(nRecDsc))
    RecLock("SX3", .F.)
    SX3->X3_CONTEXT := "V"
    SX3->X3_INIBRW  := "U_CBXHISE()"
    SX3->X3_RELACAO := ""
    If !Empty(cOrdNom)
        SX3->X3_ORDEM := Soma1(cOrdNom)
    EndIf
    SX3->(MsUnlock())
Return SX3->X3_ORDEM

/*/{Protheus.doc} CriaSX2ZHG
Cria a ZHG no SX2 copiando a ZHF (mesmo modo de compartilhamento).
@type static function
/*/
Static Function CriaSX2ZHG()
    Local nRec := 0 as Numeric

    SX2->(DbSetOrder(1))
    SX2->(DbSeek("ZHF"))
    nRec := SX2->(Recno())
    CopiaReg("SX2", nRec, { ;
        {"X2_CHAVE", "ZHG"}, {"X2_ARQUIVO", StrTran(SX2->X2_ARQUIVO, "ZHF", "ZHG")}, ;
        {"X2_NOME", "Auditoria Historicos Func."}, {"X2_NOMESPA", "Auditoria Historicos Func."}, ;
        {"X2_NOMEENG", "Employee History Audit"}, {"X2_UNICO", ""}, {"X2_ROTINA", ""}, ;
        {"X2_DISPLAY", ""}, {"X2_SYSOBJ", ""}, {"X2_USROBJ", ""}})
Return

/*/{Protheus.doc} IdxInc
Número do índice da ZHF pela data/hora de gravação (0 quando não existe).
@type static function
@author João Victor Guimarães Alves
@since 16/11/2026
@return numeric, número do índice
/*/
Static Function IdxInc() as Numeric
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

/*/{Protheus.doc} CriaIdxInc
Cria na ZHF o índice ZHF_FILIAL+ZHF_MAT+DTOS(ZHF_DTINC)+ZHF_HRINC (a tela de
Históricos abre nessa ordem: a alteração mais recente fica por último), na
próxima ordem livre, copiando o índice 1.
@type static function
@author João Victor Guimarães Alves
@since 16/11/2026
/*/
Static Function CriaIdxInc()
    Local nRec   := 0 as Numeric
    Local cOrdem := "1" as Character

    SIX->(DbSetOrder(1))
    SIX->(DbSeek("ZHF"))
    nRec := SIX->(Recno())
    While !SIX->(Eof()) .And. AllTrim(SIX->INDICE) == "ZHF"
        cOrdem := Soma1(AllTrim(SIX->ORDEM))
        SIX->(DbSkip())
    EndDo
    CopiaReg("SIX", nRec, { ;
        {"ORDEM", cOrdem}, {"CHAVE", "ZHF_FILIAL+ZHF_MAT+DTOS(ZHF_DTINC)+ZHF_HRINC"}, ;
        {"DESCRICAO", "Matricula + Dt.Inclusao + Hora"}, {"DESCSPA", "Matricula + Dt.Inclusao + Hora"}, ;
        {"DESCENG", "Matricula + Dt.Inclusao + Hora"}, {"NICKNAME", ""}, {"F3", ""}, {"SHOWPESQ", "S"}, {"PROPRI", "U"}})
Return

/*/{Protheus.doc} CriaSIXZHG
Cria os índices da ZHG copiando o índice 1 da ZHF.
@type static function
/*/
Static Function CriaSIXZHG()
    Local nRec  := 0 as Numeric
    Local aIdx  := {} as Array
    Local nI    := 0 as Numeric

    aAdd(aIdx, {"1", "ZHG_FILIAL+ZHG_MAT+DTOS(ZHG_DATA)+ZHG_HORA", "Matricula + Data + Hora"})
    aAdd(aIdx, {"2", "ZHG_FILIAL+ZHG_MAT+ZHG_TIPO+ZHG_SEQ", "Matricula + Tipo + Seq."})

    SIX->(DbSetOrder(1))
    If !SIX->(DbSeek("ZHF1"))
        SIX->(DbSeek("ZHF"))
    EndIf
    nRec := SIX->(Recno())
    For nI := 1 To Len(aIdx)
        CopiaReg("SIX", nRec, { ;
            {"INDICE", "ZHG"}, {"ORDEM", aIdx[nI][1]}, {"CHAVE", aIdx[nI][2]}, ;
            {"DESCRICAO", aIdx[nI][3]}, {"DESCSPA", aIdx[nI][3]}, {"DESCENG", aIdx[nI][3]}, ;
            {"NICKNAME", ""}, {"F3", ""}, {"SHOWPESQ", "S"}, {"PROPRI", "U"}})
    Next nI
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
Recno de um campo para servir de modelo: primeiro campo de usuário da tabela com o
mesmo tipo, contexto real e não obrigatório; senão, qualquer campo do mesmo tipo.
@type static function
@return numeric, recno no SX3 (0 quando não acha)
/*/
Static Function Modelo(cArq as Character, cTipo as Character) as Numeric
    Local nRec   := 0 as Numeric
    Local nOutro := 0 as Numeric
    Local aArea  := SX3->(GetArea()) as Array

    SX3->(DbSetOrder(1))
    SX3->(DbSeek(cArq))
    While !SX3->(Eof()) .And. SX3->X3_ARQUIVO == cArq
        If SX3->X3_TIPO == cTipo .And. SX3->X3_CONTEXT <> "V" .And. !("_FILIAL" $ SX3->X3_CAMPO)
            If SX3->X3_PROPRI == "U" .And. X3Uso(SX3->X3_USADO) .And. !X3Obrigat(SX3->X3_CAMPO)
                nRec := SX3->(Recno())
                Exit
            ElseIf nOutro == 0 .And. X3Uso(SX3->X3_USADO)
                nOutro := SX3->(Recno())
            EndIf
        EndIf
        SX3->(DbSkip())
    EndDo
    RestArea(aArea)
Return IIf(nRec > 0, nRec, nOutro)

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

/*/{Protheus.doc} ExisteCpo
Indica se o campo já existe no SX3.
@type static function
/*/
Static Function ExisteCpo(cCampo as Character) as Logical
Return RecCampo(cCampo) > 0

/*/{Protheus.doc} ProxOrdem
Próxima ordem livre de uma tabela no SX3 (depois da maior ordem usada).
@type static function
/*/
Static Function ProxOrdem(cArq as Character) as Character
    Local cMaior := "00" as Character
    Local aArea  := SX3->(GetArea()) as Array

    SX3->(DbSetOrder(1))
    SX3->(DbSeek(cArq))
    While !SX3->(Eof()) .And. SX3->X3_ARQUIVO == cArq
        If SX3->X3_ORDEM > cMaior
            cMaior := SX3->X3_ORDEM
        EndIf
        SX3->(DbSkip())
    EndDo
    RestArea(aArea)
Return Soma1(cMaior)

/*/{Protheus.doc} PastaSRA
Código da aba (SXA) da SRA pela descrição.
@type static function
/*/
Static Function PastaSRA(cDescr as Character) as Character
    Local cPasta := "" as Character
    Local aArea  := SXA->(GetArea()) as Array

    SXA->(DbSetOrder(1))
    SXA->(DbSeek("SRA"))
    While !SXA->(Eof()) .And. SXA->XA_ALIAS == "SRA"
        If Upper(AllTrim(SXA->XA_DESCRIC)) == cDescr .And. (SXA->(FieldPos("XA_TIPO")) == 0 .Or. SXA->XA_TIPO <> "2")
            cPasta := SXA->XA_ORDEM
            Exit
        EndIf
        SXA->(DbSkip())
    EndDo
    RestArea(aArea)
Return cPasta

/*/{Protheus.doc} PrecisaTab
Indica se há campo a criar na tabela.
@type static function
/*/
Static Function PrecisaTab(aFazer as Array, cArq as Character) as Logical
Return aScan(aFazer, {|x| x[1] == "CRIAR" .And. x[2][1] == cArq}) > 0

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
    DbSelectArea(cArq)
Return lRet

/*/{Protheus.doc} Salva
Grava o relatório em \system e devolve o texto.
@type static function
/*/
Static Function Salva(cLog as Character) as Character
    Local cArq := "\system\updzhf01_" + DToS(Date()) + "_" + StrTran(Time(), ":", "") + ".log" as Character

    MemoWrite(cArq, cLog)
Return cLog + CRLF + "Relatório salvo em " + cArq + CRLF

/*/{Protheus.doc} MostraLog
Mostra o relatório em uma janela.
@type static function
/*/
Static Function MostraLog(cLog as Character)
    Local oDlg  := Nil as Object
    Local oMemo := Nil as Object

    DEFINE MSDIALOG oDlg TITLE "UPDZHF01 - resultado" FROM 0, 0 TO 520, 820 PIXEL
    oMemo := TMultiGet():New(5, 5, {|u| IIf(PCount() > 0, cLog := u, cLog)}, oDlg, 400, 230, , , , , , .T., , , , , , .T.)
    TButton():New(240, 355, "Fechar", oDlg, {|| oDlg:End()}, 50, 14, , , , .T.)
    ACTIVATE MSDIALOG oDlg CENTERED
Return
