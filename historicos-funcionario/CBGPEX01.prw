#include "totvs.ch"
#include "fwmvcdef.ch"

// Tipos de histórico do funcionário (tabela ZHF)
#Define HIS_TPSN "02|03|08|11|12|13"
#Define HIS_TPCPO  "01|05|06|07|10"
#Define HIS_OPCAUX  "1=Creche;2=Creche judicial;3=Financeiro;4=Financeiro judicial"
#Define HIS_MAPPAD  "01=RA_XCODFUN;05=RA_ADCPERI;06=RA_ADCINS;07=RA_XPERELE;10=RA_XOPTICK"
// Datas de início/fim e prazo (1=Indeterminado;2=Determinado) do adicional na SRA (aba Adicionais)
// por tipo de histórico (v3, 11/11/2026). O 3º campo (prazo) é opcional.
#Define HIS_MAPDT   "05=RA_XPERDTI,RA_XPERDTF,RA_XPERPRZ;06=RA_XINSDTI,RA_XINSDTF,RA_XINSPRZ"

// Cache do mapa tipo x campo para a coluna Descrição do browse (U_CBXHISE)
Static aMapaDesc := Nil

/*/{Protheus.doc} CBXHISC
Lista de opções do campo ZHF_TIPO (usada no X3_CBOX como #U_CBXHISC()).
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
@return character, opções no formato "01=Descrição;02=Descrição"
/*/
User Function CBXHISC() as Character
    Local cOpcoes := "" as Character

    cOpcoes := "01=Função gratificada;"
    cOpcoes += "02=Horário reduzido;"
    cOpcoes += "03=Licença sem vencimento;"
    cOpcoes += "04=Penalidade/TAC;"
    cOpcoes += "05=Periculosidade;"
    cOpcoes += "06=Insalubridade;"
    cOpcoes += "07=Periculosidade judicial;"
    cOpcoes += "08=Comissão;"
    cOpcoes += "09=Auxílio creche/financeiro;"
    cOpcoes += "10=Ticket;"
    cOpcoes += "11=Condutor;"
    cOpcoes += "12=Elogio;"
    cOpcoes += "13=Licença paternidade"
Return cOpcoes

/*/{Protheus.doc} CBXHIST
Descrição de um tipo de histórico.
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
@param cTipo, character, código do tipo (ZHF_TIPO)
@return character, descrição do tipo
/*/
User Function CBXHIST(cTipo as Character) as Character
Return OpcaoCombo(U_CBXHISC(), cTipo)

/*/{Protheus.doc} CBXHISI
Inicializador padrão do ZHF_MAT: traz a matrícula do funcionário quando a tela
foi aberta pelo Cadastro de Funcionários (variável cHisMatCtx).
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
@return character, matrícula ou vazio
/*/
User Function CBXHISI() as Character
    Local cMat := "" as Character

    If Type("cHisMatCtx") == "C"
        cMat := &("cHisMatCtx")
    EndIf
Return cMat

/*/{Protheus.doc} CBXHISN
Inicializador do campo virtual ZHF_NOME (nome do funcionário).
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
@return character, nome do funcionário
/*/
User Function CBXHISN() as Character
    Local cNome  := "" as Character
    Local oModel := Nil as Object
    Local cMat   := "" as Character
    Local cFil   := "" as Character

    oModel := FWModelActive()
    If oModel <> Nil .And. oModel:GetOperation() == MODEL_OPERATION_INSERT
        cMat := U_CBXHISI()
        cFil := xFilial("SRA")
    Else
        cMat := ZHF->ZHF_MAT
        cFil := ZHF->ZHF_FILIAL
    EndIf

    If !Empty(cMat)
        cNome := Posicione("SRA", 1, cFil + cMat, "RA_NOME")
    EndIf
Return cNome

/*/{Protheus.doc} CBXHISS
Próxima sequência do histórico para filial + matrícula + tipo.
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
@param cFil, character, filial da ZHF
@param cMat, character, matrícula
@param cTipo, character, tipo do histórico
@return character, sequência (3 posições)
/*/
User Function CBXHISS(cFil as Character, cMat as Character, cTipo as Character) as Character
    Local cSeq    := "001" as Character
    Local aArea   := GetArea() as Array
    Local aAreaZH := ZHF->(GetArea()) as Array

    If UltimoHist(cFil, cMat, cTipo)
        cSeq := Soma1(ZHF->ZHF_SEQ)
    EndIf

    RestArea(aAreaZH)
    RestArea(aArea)
Return cSeq

/*/{Protheus.doc} CBXHISM
Lê o parâmetro MV_ZHFCPOS e devolve o mapa tipo x campo da SRA monitorado.
Chamar fora de laços e repassar o resultado para CBXHISG.
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
@return array, {{cTipo, cCampo}, ...}
/*/
User Function CBXHISM() as Array
    Local aMapa  := {} as Array
    Local aItens := {} as Array
    Local aPar   := {} as Array
    Local cPar   := "" as Character
    Local nI     := 0 as Numeric

    cPar   := AllTrim(GetNewPar("MV_ZHFCPOS", HIS_MAPPAD))
    aItens := StrTokArr(cPar, ";")

    For nI := 1 To Len(aItens)
        aPar := StrTokArr(aItens[nI] + " ", "=")
        If Len(aPar) >= 2 .And. !Empty(aPar[2])
            aAdd(aMapa, {PadR(AllTrim(aPar[1]), 2), Upper(AllTrim(aPar[2]))})
        EndIf
    Next nI
Return aMapa

/*/{Protheus.doc} CBXHISG
Compara os campos monitorados do funcionário posicionado na SRA com o último
histórico de cada tipo e grava uma linha nova na ZHF quando o valor mudou.
Na gravação pelo cadastro (origem "2") com tela, pede Data Inicial, Data Final
e Número do processo de cada mudança antes de gravar. Em rotina automática
(ExecAuto, job) e na carga inicial não abre tela: usa a data padrão.
Ao gravar, fecha o histórico anterior do mesmo tipo (Data Final vazia recebe a
Data Inicial do novo).
Periculosidade e insalubridade (v3): as datas de início/fim do cadastro (aba
Adicionais) viram a sugestão de Data Inicial/Final; se só a data de fim mudar no
cadastro, a Data Final do último histórico é atualizada. Toda gravação entra no
log de auditoria (ZHG).
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
@param cOrigem, character, "2" = automática (cadastro), "3" = carga inicial
@param aMapa, array, mapa de CBXHISM (opcional; lido do parâmetro se vazio)
@param dDataFix, date, data informada pela rotina chamadora (opcional; ex.: data da
transferência). Com ela não abre a janela de datas e o histórico usa essa data (16/11/2026).
@param cMotivo, character, texto da auditoria (opcional; ex.: "Transferência de local de trabalho")
@return numeric, quantidade de linhas gravadas
/*/
User Function CBXHISG(cOrigem as Character, aMapa as Array, dDataFix as Date, cMotivo as Character) as Numeric
    Local nGrav    := 0 as Numeric
    Local nI       := 0 as Numeric
    Local nPos     := 0 as Numeric
    Local aArea    := GetArea() as Array
    Local aAreaZH  := ZHF->(GetArea()) as Array
    Local cFilZHF  := "" as Character
    Local cMat     := "" as Character
    Local cTipo    := "" as Character
    Local cCampo   := "" as Character
    Local cValor   := "" as Character
    Local cAnt     := "" as Character
    Local cSeq     := "" as Character
    Local lTemHist := .F. as Logical
    Local lTela    := .F. as Logical
    Local dData    := CToD("") as Date
    Local dFim     := CToD("") as Date
    Local cProc    := "" as Character
    Local aMuda    := {} as Array
    Local aInfo    := {} as Array
    Local aDatas   := MapaDatas() as Array
    Local aDtSRA   := {} as Array
    Local aSinc    := {} as Array
    Local aUsr     := U_CBXHISU() as Array
    Local dFimSug  := CToD("") as Date
    Local dFimAnt  := CToD("") as Date
    Local cDet     := "" as Character

    If Empty(aMapa)
        aMapa := U_CBXHISM()
    EndIf

    If SRA->(Eof()) .Or. Empty(aMapa)
        Return nGrav
    EndIf

    cFilZHF := xFilial("ZHF", SRA->RA_FILIAL)
    cMat    := SRA->RA_MAT
    lTela   := (cOrigem == "2" .And. Empty(dDataFix) .And. TemTela())

    // Adicional 1=Não: prazo e datas dele não valem e são limpos no cadastro
    If cOrigem == "2"
        LimpaInativo(aMapa, aDatas)
    EndIf

    // 1) Levanta o que mudou (sem gravar ainda)
    For nI := 1 To Len(aMapa)
        cTipo  := aMapa[nI][1]
        cCampo := aMapa[nI][2]
        nPos   := SRA->(FieldPos(cCampo))

        If nPos == 0
            Loop
        EndIf

        cValor   := ValorTexto(SRA->(FieldGet(nPos)))
        lTemHist := UltimoHist(cFilZHF, cMat, cTipo)
        cAnt     := ""
        cSeq     := "001"

        If lTemHist
            cAnt := AllTrim(ZHF->ZHF_VLNOV)
            cSeq := Soma1(ZHF->ZHF_SEQ)
        EndIf

        If cOrigem == "3" .And. lTemHist
            Loop
        EndIf

        If !lTemHist .And. Empty(cValor)
            Loop
        EndIf

        // Datas do adicional no cadastro (só periculosidade/insalubridade, quando há adicional)
        aDtSRA := {}
        If AdcAtivo(cValor)
            aDtSRA := DatasSRA(cTipo, aDatas)
        EndIf

        If lTemHist .And. cAnt == cValor
            // Valor igual, mas a data de fim do adicional mudou no cadastro: acerta o último histórico
            // (ou o prazo passou a Indeterminado: a Data Final do último histórico fica vazia)
            If cOrigem == "2" .And. !Empty(aDtSRA) .And. aDtSRA[2] <> ZHF->ZHF_DTFIM .And. (!Empty(aDtSRA[2]) .Or. aDtSRA[3] == "1")
                aAdd(aSinc, {ZHF->(Recno()), aDtSRA[2]})
            EndIf
            Loop
        EndIf

        dData   := dDataBase
        dFimSug := CToD("")
        If cTipo == "01"
            dData := DataFuncao(Empty(cValor), dData)
        EndIf
        If !Empty(aDtSRA)
            If !Empty(aDtSRA[1])
                dData := aDtSRA[1]
            EndIf
            dFimSug := aDtSRA[2]
        EndIf
        // Data informada pela rotina chamadora (ex.: data da transferência)
        If !Empty(dDataFix)
            dData   := dDataFix
            dFimSug := CToD("")
        EndIf

        aAdd(aMuda, {cTipo, cSeq, cAnt, cValor, dData, dFimSug})
    Next nI

    // 2) Pede Data Inicial, Data Final e Processo de cada mudança e grava
    For nI := 1 To Len(aMuda)
        cTipo  := aMuda[nI][1]
        cSeq   := aMuda[nI][2]
        cAnt   := aMuda[nI][3]
        cValor := aMuda[nI][4]
        dData  := aMuda[nI][5]
        dFim   := aMuda[nI][6]
        cProc  := ""

        If lTela
            aInfo := PedeDados(cTipo, cAnt, cValor, dData, dFim, aMapa)
            dData := aInfo[1]
            dFim  := aInfo[2]
            cProc := aInfo[3]
        EndIf

        RecLock("ZHF", .T.)
        ZHF->ZHF_FILIAL := cFilZHF
        ZHF->ZHF_MAT    := cMat
        ZHF->ZHF_TIPO   := cTipo
        ZHF->ZHF_SEQ    := cSeq
        ZHF->ZHF_DATA   := dData
        ZHF->ZHF_DTFIM  := dFim
        ZHF->ZHF_PROCES := cProc
        ZHF->ZHF_VLANT  := cAnt
        ZHF->ZHF_VLNOV  := cValor
        ZHF->ZHF_ORIGEM := cOrigem
        ZHF->ZHF_USER   := aUsr[2]
        ZHF->ZHF_DTINC  := Date()
        ZHF->ZHF_HRINC  := Time()
        GravaCampo("ZHF_CODUSR", aUsr[1])
        GravaCampo("ZHF_MATINC", aUsr[3])
        ZHF->(MsUnlock())

        cDet := IIf(cOrigem == "3", "Carga inicial. ", IIf(Empty(cMotivo), "Alteração no cadastro do funcionário. ", AllTrim(cMotivo) + ". ")) + ;
            "Valor: " + IIf(Empty(cAnt), "vazio", cAnt) + " -> " + IIf(Empty(cValor), "vazio", cValor) + ;
            ". Data Inicial " + U_CBXHISB(dData) + IIf(Empty(dFim), "", ", Data Final " + U_CBXHISB(dFim)) + ;
            IIf(Empty(cProc), "", ", Processo " + cProc)
        U_CBXHISA(cFilZHF, cMat, cTipo, cSeq, "1", cDet)

        U_CBXHISF(cFilZHF, cMat, cTipo, cSeq, dData)
        nGrav++
    Next nI

    // 3) Prazo do adicional alterado no cadastro: Data Final do último histórico
    For nI := 1 To Len(aSinc)
        ZHF->(DbGoTo(aSinc[nI][1]))
        dFimAnt := ZHF->ZHF_DTFIM
        RecLock("ZHF", .F.)
        ZHF->ZHF_DTFIM := aSinc[nI][2]
        U_CBXHISZ(aUsr)
        ZHF->(MsUnlock())
        U_CBXHISA(ZHF->ZHF_FILIAL, ZHF->ZHF_MAT, ZHF->ZHF_TIPO, ZHF->ZHF_SEQ, "2", ;
            "Data Final: " + U_CBXHISB(dFimAnt) + " -> " + U_CBXHISB(aSinc[nI][2]) + ;
            IIf(Empty(aSinc[nI][2]), " (adicional passou a tempo indeterminado no cadastro do funcionário)", ;
            " (data de fim do adicional alterada no cadastro do funcionário)"))
    Next nI

    RestArea(aAreaZH)
    RestArea(aArea)
Return nGrav

/*/{Protheus.doc} CBXHISF
Fecha o histórico anterior do mesmo tipo: quando a Data Final dele está vazia,
recebe a Data Inicial do histórico novo (pedido da CAESB em 10/11/2026).
Não mexe se o anterior já tem Data Final ou começa depois do novo.
@type user function
@author João Victor Guimarães Alves
@since 10/11/2026
@param cFil, character, filial da ZHF
@param cMat, character, matrícula
@param cTipo, character, tipo do histórico
@param cSeqNova, character, sequência do histórico novo
@param dIni, date, Data Inicial do histórico novo
@return logical, .T. quando fechou o anterior
/*/
User Function CBXHISF(cFil as Character, cMat as Character, cTipo as Character, cSeqNova as Character, dIni as Date) as Logical
    Local lFechou := .F. as Logical
    Local aArea   := GetArea() as Array
    Local aAreaZH := ZHF->(GetArea()) as Array
    Local cChave  := cFil + cMat + cTipo as Character

    If Empty(dIni)
        Return lFechou
    EndIf

    ZHF->(DbSetOrder(1)) // ZHF_FILIAL+ZHF_MAT+ZHF_TIPO+ZHF_SEQ
    ZHF->(DbSeek(cChave + cSeqNova, .T.))
    ZHF->(DbSkip(-1))

    If !ZHF->(Bof()) .And. !ZHF->(Eof()) .And. ZHF->(ZHF_FILIAL + ZHF_MAT + ZHF_TIPO) == cChave ;
        .And. ZHF->ZHF_SEQ < cSeqNova .And. Empty(ZHF->ZHF_DTFIM) .And. ZHF->ZHF_DATA <= dIni
        RecLock("ZHF", .F.)
        ZHF->ZHF_DTFIM := dIni
        U_CBXHISZ()
        ZHF->(MsUnlock())
        lFechou := .T.
        U_CBXHISA(ZHF->ZHF_FILIAL, ZHF->ZHF_MAT, ZHF->ZHF_TIPO, ZHF->ZHF_SEQ, "2", ;
            "Data Final: vazio -> " + U_CBXHISB(dIni) + " (fechado pelo histórico novo, sequência " + cSeqNova + ")")
    EndIf

    RestArea(aAreaZH)
    RestArea(aArea)
Return lFechou

/*/{Protheus.doc} TemTela
Indica se há usuário na tela (não é job nem rotina automática/ExecAuto).
@type static function
@author João Victor Guimarães Alves
@since 10/11/2026
@return logical, .T. quando pode abrir janela
/*/
Static Function TemTela() as Logical
    Local lTela := !IsBlind() as Logical

    If lTela .And. Type("lMsHelpAuto") == "L" .And. &("lMsHelpAuto")
        lTela := .F.
    EndIf
Return lTela

/*/{Protheus.doc} PedeDados
Janela que pede Data Inicial (obrigatória), Data Final e Número do processo
de uma mudança gravada pelo cadastro. Cancelar mantém os valores sugeridos.
Guarda e devolve MV_PAR01..03 para não atrapalhar o Cadastro de Funcionários.
@type static function
@author João Victor Guimarães Alves
@since 10/11/2026
@param cTipo, character, tipo do histórico
@param cAnt, character, valor anterior
@param cValor, character, valor novo
@param dSugere, date, Data Inicial sugerida
@param dFimSug, date, Data Final sugerida (vazia = sem prazo)
@param aMapa, array, mapa de CBXHISM
@return array, {dInicial, dFinal, cProcesso}
/*/
Static Function PedeDados(cTipo as Character, cAnt as Character, cValor as Character, dSugere as Date, dFimSug as Date, aMapa as Array) as Array
    Local aRet    := {dSugere, dFimSug, ""} as Array
    Local aPergs  := {} as Array
    Local aResp   := {} as Array
    Local aGuarda := {} as Array
    Local nTamPrc := TamSX3("ZHF_PROCES")[1] as Numeric
    Local cTitulo := "" as Character
    Local cVar    := "" as Character
    Local nI      := 0 as Numeric

    For nI := 1 To 3
        cVar := "MV_PAR" + StrZero(nI, 2)
        If Type(cVar) <> "U"
            aAdd(aGuarda, {cVar, &(cVar)})
        EndIf
    Next nI

    cTitulo := "Histórico: " + U_CBXHIST(cTipo) + " (" + ;
        IIf(Empty(cAnt), "vazio", U_CBXHISV(cTipo, cAnt, aMapa)) + " -> " + ;
        IIf(Empty(cValor), "vazio", U_CBXHISV(cTipo, cValor, aMapa)) + ")"

    aAdd(aPergs, {1, "Data Inicial",       dSugere,         "", "", "", "", 50, .T.})
    aAdd(aPergs, {1, "Data Final",         dFimSug,         "", "", "", "", 50, .F.})
    aAdd(aPergs, {1, "Número do processo", Space(nTamPrc),  "", "", "", "", 90, .F.})

    If ParamBox(aPergs, Left(cTitulo, 100), @aResp, {|| ValidaDatas()}, , , , , , , .F., .F.)
        If !Empty(aResp[1])
            aRet[1] := aResp[1]
        EndIf
        aRet[2] := aResp[2]
        aRet[3] := AllTrim(aResp[3])
    EndIf

    For nI := 1 To Len(aGuarda)
        &(aGuarda[nI][1]) := aGuarda[nI][2]
    Next nI
Return aRet

/*/{Protheus.doc} ValidaDatas
Confirmação da janela PedeDados: Data Inicial obrigatória e Data Final não
pode ser anterior à inicial.
@type static function
@author João Victor Guimarães Alves
@since 10/11/2026
@return logical, .T. quando pode confirmar
/*/
Static Function ValidaDatas() as Logical
    Local lRet := .T. as Logical

    If Empty(MV_PAR01)
        Help(,, "CBGPEX01",, "Informe a Data Inicial.", 1, 0,,,,,, {"Preencha a Data Inicial do histórico e confirme."})
        lRet := .F.
    ElseIf !Empty(MV_PAR02) .And. MV_PAR02 < MV_PAR01
        Help(,, "CBGPEX01",, "A Data Final não pode ser anterior à Data Inicial.", 1, 0,,,,,, {"Informe uma Data Final igual ou posterior à Data Inicial, ou deixe em branco."})
        lRet := .F.
    EndIf
Return lRet

/*/{Protheus.doc} CBXHISD
Descrição da situação de uma linha do histórico (Sim/Não, penalidade ou
tipo de auxílio), usada no relatório.
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
@param cTipo, character, tipo do histórico
@param cSituac, character, conteúdo de ZHF_SITUAC
@param cPenal, character, conteúdo de ZHF_PENAL
@param cTpAux, character, conteúdo de ZHF_TPAUX
@return character, descrição
/*/
User Function CBXHISD(cTipo as Character, cSituac as Character, cPenal as Character, cTpAux as Character) as Character
    Local cDesc := "" as Character

    If cTipo == "04"
        cDesc := OpcaoCombo("1=Advertência;2=Suspensão;3=TAC", cPenal)
    ElseIf cTipo == "09"
        cDesc := OpcaoCombo(HIS_OPCAUX, cTpAux)
    ElseIf cTipo $ HIS_TPSN
        cDesc := OpcaoCombo("1=Sim;2=Não", cSituac)
    EndIf
Return cDesc

/*/{Protheus.doc} CBXHISE
Descrição por extenso da linha posicionada da ZHF, para a coluna "Descrição" do
browse (inicializador de browse do campo virtual ZHF_DESCR): valor novo com a
descrição (ex.: Ticket "1 - 100 A", função "código - descrição") ou, nos tipos sem
valor, a situação/penalidade/tipo de auxílio (ex.: "Sim", "Advertência").
@type user function
@author João Victor Guimarães Alves
@since 16/11/2026
@param aMapa, array, mapa tipo x campo (U_CBXHISM); opcional
@return character, descrição
/*/
User Function CBXHISE(aMapa as Array) as Character
    Local cValor := "" as Character
    Local cTexto := "" as Character

    If ZHF->(Eof())
        Return cTexto
    EndIf
    If Empty(aMapa)
        If aMapaDesc == Nil
            aMapaDesc := U_CBXHISM()
        EndIf
        aMapa := aMapaDesc
    EndIf

    cValor := AllTrim(ZHF->ZHF_VLNOV)
    If !Empty(cValor)
        cTexto := AllTrim(U_CBXHISV(ZHF->ZHF_TIPO, cValor, aMapa))
        If !(cTexto == cValor) .And. !(Left(cTexto, Len(cValor) + 1) == cValor + " ")
            cTexto := cValor + " - " + cTexto
        EndIf
    Else
        cTexto := AllTrim(U_CBXHISD(ZHF->ZHF_TIPO, ZHF->ZHF_SITUAC, ZHF->ZHF_PENAL, ZHF->ZHF_TPAUX))
    EndIf
Return cTexto

/*/{Protheus.doc} CBXHISL
Indica se o tipo usa o campo Sim/Não, Penalidade, Auxílio ou Valor.
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
@param cGrupo, character, "SIMNAO" ou "CAMPO"
@return character, códigos separados por |
/*/
User Function CBXHISL(cGrupo as Character) as Character
    Local cTipos := "" as Character

    If cGrupo == "SIMNAO"
        cTipos := HIS_TPSN
    ElseIf cGrupo == "CAMPO"
        cTipos := HIS_TPCPO
    EndIf
Return cTipos

/*/{Protheus.doc} CBXHISV
Texto de um valor gravado no histórico (ZHF_VLANT/ZHF_VLNOV), usado no relatório.
Função gratificada (RA_XCODFUN): código + descrição da tabela SZA.
Campo com lista de opções (X3_CBOX): a descrição da opção.
Demais campos: o próprio valor.
@type user function
@author João Victor Guimarães Alves
@since 30/10/2026
@param cTipo, character, tipo do histórico
@param cValor, character, valor gravado
@param aMapa, array, mapa de CBXHISM (ler uma vez, fora do laço)
@return character, texto para exibir
/*/
User Function CBXHISV(cTipo as Character, cValor as Character, aMapa as Array) as Character
    Local cTexto := AllTrim(cValor) as Character
    Local cCampo := "" as Character
    Local cCombo := "" as Character
    Local cDesc  := "" as Character
    Local nPos   := 0 as Numeric

    If Empty(cTexto) .Or. Empty(aMapa)
        Return cTexto
    EndIf

    nPos := aScan(aMapa, {|x| x[1] == cTipo})
    If nPos == 0
        Return cTexto
    EndIf
    cCampo := aMapa[nPos][2]

    If cCampo == "RA_XCODFUN"
        If FWAliasInDic("SZA")
            cDesc := AllTrim(Posicione("SZA", 1, xFilial("SZA") + PadR(cTexto, TamSX3("ZA_XCODFUN")[1]), "ZA_XDESFUN"))
        EndIf
    Else
        cCombo := AllTrim(GetSX3Cache(cCampo, "X3_CBOX"))
        If !Empty(cCombo) .And. Left(cCombo, 1) <> "#"
            cDesc := OpcaoCombo(cCombo, cTexto)
            If !Empty(cDesc)
                cTexto := cDesc
                cDesc  := ""
            EndIf
        EndIf
    EndIf

    If !Empty(cDesc)
        cTexto := cTexto + " - " + cDesc
    EndIf
Return cTexto

/*/{Protheus.doc} DataFuncao
Data do histórico da função gratificada: na retirada da função usa a data de
destituição (RA_DTDESTI); na designação ou troca, a data de designação
(RA_DTDESIG). Se o campo não existir ou estiver vazio, usa a data padrão.
@type static function
@author João Victor Guimarães Alves
@since 30/10/2026
@param lRetirada, logical, .T. quando o código da função ficou vazio
@param dPadrao, date, data usada quando não há data no cadastro
@return date, data do histórico
/*/
Static Function DataFuncao(lRetirada as Logical, dPadrao as Date) as Date
    Local dData  := dPadrao as Date
    Local cCampo := "RA_DTDESIG" as Character
    Local nPos   := 0 as Numeric

    If lRetirada
        cCampo := "RA_DTDESTI"
    EndIf

    nPos := SRA->(FieldPos(cCampo))
    If nPos > 0 .And. !Empty(SRA->(FieldGet(nPos)))
        dData := SRA->(FieldGet(nPos))
    EndIf
Return dData

/*/{Protheus.doc} UltimoHist
Posiciona a ZHF no último histórico de filial + matrícula + tipo.
@type static function
@author João Victor Guimarães Alves
@since 29/10/2026
@param cFil, character, filial
@param cMat, character, matrícula
@param cTipo, character, tipo
@return logical, .T. quando existe histórico (ZHF posicionada nele)
/*/
Static Function UltimoHist(cFil as Character, cMat as Character, cTipo as Character) as Logical
    Local lAchou := .F. as Logical
    Local cChave := "" as Character

    cChave := cFil + cMat + cTipo

    ZHF->(DbSetOrder(1)) // ZHF_FILIAL+ZHF_MAT+ZHF_TIPO+ZHF_SEQ
    ZHF->(DbSeek(cChave + "ZZZ", .T.))
    ZHF->(DbSkip(-1))

    If !ZHF->(Bof()) .And. !ZHF->(Eof())
        lAchou := (ZHF->(ZHF_FILIAL + ZHF_MAT + ZHF_TIPO) == cChave)
    EndIf
Return lAchou

/*/{Protheus.doc} ValorTexto
Converte o conteúdo de um campo em texto para gravar no histórico.
@type static function
@author João Victor Guimarães Alves
@since 29/10/2026
@param xValor, variant, conteúdo do campo
@return character, texto
/*/
Static Function ValorTexto(xValor as Variant) as Character
    Local cTexto := "" as Character
    Local cTipo  := ValType(xValor) as Character

    If cTipo == "C"
        cTexto := AllTrim(xValor)
    ElseIf cTipo == "D"
        If !Empty(xValor)
            cTexto := DToC(xValor)
        EndIf
    ElseIf cTipo == "N"
        // Zero conta como vazio: sem isso todo funcionário ganharia uma linha "0"
        If xValor <> 0
            cTexto := AllTrim(cValToChar(xValor))
        EndIf
    ElseIf cTipo == "L"
        If xValor
            cTexto := "S"
        Else
            cTexto := "N"
        EndIf
    EndIf
Return Left(cTexto, 60)

/*/{Protheus.doc} OpcaoCombo
Devolve a descrição de um código numa lista "1=A;2=B".
@type static function
@author João Victor Guimarães Alves
@since 29/10/2026
@param cLista, character, lista de opções
@param cCodigo, character, código procurado
@return character, descrição (vazio se não achar)
/*/
Static Function OpcaoCombo(cLista as Character, cCodigo as Character) as Character
    Local cDesc  := "" as Character
    Local aItens := {} as Array
    Local nI     := 0 as Numeric
    Local nPos   := 0 as Numeric
    Local cCod   := AllTrim(cCodigo) as Character

    If Empty(cCod)
        Return cDesc
    EndIf

    aItens := StrTokArr(cLista, ";")
    For nI := 1 To Len(aItens)
        nPos := At("=", aItens[nI])
        If nPos > 0 .And. AllTrim(Left(aItens[nI], nPos - 1)) == cCod
            cDesc := SubStr(aItens[nI], nPos + 1)
            Exit
        EndIf
    Next nI
Return cDesc

/*/{Protheus.doc} CBXHISU
Usuário do Protheus que está gravando: código (ex.: 000123), login e matrícula
do funcionário vinculado a ele (Vínculo Funcional do cadastro de usuários).
Em job sem usuário devolve código vazio e "JOB".
@type user function
@author João Victor Guimarães Alves
@since 11/11/2026
@return array, {cCodigo, cLogin, cMatricula}
/*/
User Function CBXHISU() as Array
    Local cCod  := "" as Character
    Local cNome := "" as Character

    If Type("__cUserId") == "C"
        cCod := AllTrim(&("__cUserId"))
    EndIf
    If Type("cUserName") == "C"
        cNome := AllTrim(&("cUserName"))
    EndIf
    If Empty(cNome) .And. !Empty(cCod)
        cNome := AllTrim(UsrRetName(cCod))
    EndIf
    If Empty(cNome)
        cNome := IIf(IsBlind(), "JOB", "SISTEMA")
    EndIf
Return {cCod, cNome, U_CBXHISR(cCod)}

/*/{Protheus.doc} CBXHISR
Matrícula do funcionário vinculado ao usuário do Protheus. Usa o Vínculo
Funcional do cadastro de usuários (Configurador); se não houver, procura na SRA
um funcionário ativo com o mesmo e-mail do usuário.
@type user function
@author João Victor Guimarães Alves
@since 11/11/2026
@param cCod, character, código do usuário (ex.: 000123)
@return character, matrícula (RA_MAT) ou vazio quando não encontrar
/*/
User Function CBXHISR(cCod as Character) as Character
    Local cMatUsr := "" as Character
    Local cVinc   := "" as Character
    Local cEmail  := "" as Character
    Local cAlias  := "" as Character
    Local nTamMat := TamSX3("RA_MAT")[1] as Numeric
    Local aUsrDad := {} as Array
    Local aArea   := GetArea() as Array

    If Empty(cCod)
        Return cMatUsr
    EndIf

    PswOrder(1)
    If PswSeek(cCod, .T.)
        aUsrDad := PswRet()
        // aUsrDad[1][22] = vínculo funcional: grupo de empresas + filial + matrícula
        If Len(aUsrDad) > 0 .And. Len(aUsrDad[1]) >= 22 .And. ValType(aUsrDad[1][22]) == "C"
            cVinc := AllTrim(aUsrDad[1][22])
            If Len(cVinc) > nTamMat
                cMatUsr := Right(cVinc, nTamMat)
            EndIf
        EndIf
    EndIf

    If Empty(cMatUsr)
        cEmail := Lower(AllTrim(UsrRetMail(cCod)))
        If !Empty(cEmail)
            cAlias := GetNextAlias()
            BeginSql Alias cAlias
                SELECT SRA.RA_MAT
                FROM %Table:SRA% SRA
                WHERE LOWER(SRA.RA_EMAIL) = %Exp:cEmail%
                  AND SRA.RA_SITFOLH <> 'D'
                  AND SRA.%NotDel%
                ORDER BY SRA.RA_ADMISSA DESC
            EndSql
            If !(cAlias)->(Eof())
                cMatUsr := (cAlias)->RA_MAT
            EndIf
            (cAlias)->(DbCloseArea())
        EndIf
    EndIf

    RestArea(aArea)
Return cMatUsr

/*/{Protheus.doc} CBXHISZ
Marca na linha da ZHF (já travada com RecLock) quem fez a última alteração.
@type user function
@author João Victor Guimarães Alves
@since 11/11/2026
@param aUsr, array, retorno de CBXHISU (opcional)
/*/
User Function CBXHISZ(aUsr as Array)
    If Empty(aUsr)
        aUsr := U_CBXHISU()
    EndIf
    GravaCampo("ZHF_CODALT", aUsr[1])
    GravaCampo("ZHF_USRALT", aUsr[2])
    GravaCampo("ZHF_MATALT", aUsr[3])
    GravaCampo("ZHF_DTALT", Date())
    GravaCampo("ZHF_HRALT", Time())
Return

/*/{Protheus.doc} CBXHISA
Grava uma linha no log de auditoria dos históricos (tabela ZHG): quem, quando,
qual rotina e o que mudou. Se a ZHG ainda não existir no dicionário, não faz nada.
@type user function
@author João Victor Guimarães Alves
@since 11/11/2026
@param cFil, character, filial da ZHF
@param cMat, character, matrícula
@param cTipo, character, tipo do histórico
@param cSeq, character, sequência do histórico
@param cOper, character, 1=Inclusão, 2=Alteração, 3=Exclusão
@param cDetalhe, character, o que mudou
@return logical, .T. quando gravou o log
/*/
User Function CBXHISA(cFil as Character, cMat as Character, cTipo as Character, cSeq as Character, cOper as Character, cDetalhe as Character) as Logical
    Local aArea  := GetArea() as Array
    Local aUsr   := {} as Array
    Local cRot   := "" as Character

    If !FWAliasInDic("ZHG")
        Return .F.
    EndIf

    aUsr := U_CBXHISU()
    cRot := AllTrim(FunName())
    If Empty(cRot)
        cRot := "JOB"
    EndIf

    DbSelectArea("ZHG")
    RecLock("ZHG", .T.)
    ZHG->ZHG_FILIAL := cFil
    ZHG->ZHG_MAT    := cMat
    ZHG->ZHG_TIPO   := cTipo
    ZHG->ZHG_SEQ    := cSeq
    ZHG->ZHG_OPER   := cOper
    ZHG->ZHG_CODUSR := aUsr[1]
    ZHG->ZHG_USER   := aUsr[2]
    If ZHG->(FieldPos("ZHG_MATUSR")) > 0
        ZHG->ZHG_MATUSR := aUsr[3]
    EndIf
    ZHG->ZHG_DATA   := Date()
    ZHG->ZHG_HORA   := Time()
    ZHG->ZHG_ROTINA := cRot
    ZHG->ZHG_DETALH := Left(cDetalhe, Len(ZHG->ZHG_DETALH))
    ZHG->(MsUnlock())

    RestArea(aArea)
Return .T.

/*/{Protheus.doc} CBXHISK
Validação dos campos de prazo e de data do adicional no Cadastro de Funcionários
(X3_VLDUSER de RA_XPERPRZ/RA_XINSPRZ e RA_XPERDTI/RA_XPERDTF/RA_XINSDTI/RA_XINSDTF).
Prazo: 1=Indeterminado (limpa as datas) ou 2=Determinado (libera as datas).
Datas: só com prazo Determinado; a de fim não pode ser anterior à de início e só
pode ser informada com o início.
@type user function
@author João Victor Guimarães Alves
@since 11/11/2026
@param cCampo, character, campo validado (opcional; padrão = campo em edição)
@return logical, .T. quando a data é válida
/*/
User Function CBXHISK(cCampo as Character) as Logical
    Local lRet   := .T. as Logical
    Local cVar   := "" as Character
    Local aDatas := MapaDatas() as Array
    Local nPos   := 0 as Numeric
    Local dIni   := CToD("") as Date
    Local dFim   := CToD("") as Date

    If Empty(cCampo)
        cCampo := ReadVar()
    EndIf
    cVar := Upper(AllTrim(StrTran(cCampo, "M->", "")))

    // Campo de prazo: Indeterminado limpa as datas do adicional
    nPos := aScan(aDatas, {|x| !Empty(x[4]) .And. x[4] == cVar})
    If nPos > 0
        If Type("M->" + cVar) == "C" .And. AllTrim(&("M->" + cVar)) <> "2"
            LimpaData(aDatas[nPos][2])
            LimpaData(aDatas[nPos][3])
        EndIf
        Return lRet
    EndIf

    nPos := aScan(aDatas, {|x| x[2] == cVar .Or. x[3] == cVar})
    If nPos == 0 .Or. Type("M->" + aDatas[nPos][2]) <> "D" .Or. Type("M->" + aDatas[nPos][3]) <> "D"
        Return lRet
    EndIf

    dIni := &("M->" + aDatas[nPos][2])
    dFim := &("M->" + aDatas[nPos][3])

    If !Empty(&("M->" + cVar)) .And. !PrazoDet(aDatas[nPos])
        Help(,, "CBGPEX01",, "As datas do adicional só podem ser informadas com o prazo Determinado.", 1, 0,,,,,, {"Altere o prazo do adicional para 2-Determinado ou deixe as datas em branco."})
        lRet := .F.
    ElseIf !Empty(dIni) .And. !Empty(dFim) .And. dFim < dIni
        Help(,, "CBGPEX01",, "A data de fim do adicional não pode ser anterior à data de início.", 1, 0,,,,,, {"Informe uma data de fim igual ou posterior à data de início do adicional."})
        lRet := .F.
    ElseIf cVar == aDatas[nPos][3] .And. !Empty(dFim) .And. Empty(dIni)
        Help(,, "CBGPEX01",, "Informe primeiro a data de início do adicional.", 1, 0,,,,,, {"Preencha a data de início do adicional antes da data de fim."})
        lRet := .F.
    EndIf
Return lRet

/*/{Protheus.doc} CBXHISW
Modo de edição (X3_WHEN) do prazo e das datas do adicional no Cadastro de Funcionários.
Prazo: liberado só quando o funcionário tem o adicional (RA_ADCPERI/RA_ADCINS diferente
de 1=Não; decisão da CAESB em 13/11/2026). Datas: adicional ativo e prazo 2=Determinado.
Sem o campo de prazo no dicionário, as datas dependem só do adicional.
@type user function
@author João Victor Guimarães Alves
@since 11/11/2026
@param cCampo, character, campo de data (ex.: "RA_XPERDTI")
@return logical, .T. quando o campo pode ser editado
/*/
User Function CBXHISW(cCampo as Character) as Logical
    Local aDatas := MapaDatas() as Array
    Local cVar   := Upper(AllTrim(StrTran(cCampo, "M->", ""))) as Character
    Local nPos   := aScan(aDatas, {|x| !Empty(x[4]) .And. x[4] == cVar}) as Numeric

    // Campo de prazo
    If nPos > 0
        Return AdcLiberado(aDatas[nPos])
    EndIf

    // Campo de data
    nPos := aScan(aDatas, {|x| x[2] == cVar .Or. x[3] == cVar})
    If nPos == 0
        Return .T.
    EndIf
Return AdcLiberado(aDatas[nPos]) .And. PrazoDet(aDatas[nPos])

/*/{Protheus.doc} AdcLiberado
Indica se o adicional do item (periculosidade/insalubridade) está ativo na tela em
edição (M->): o campo do adicional vem do mapa MV_ZHFCPOS pelo tipo do histórico.
Sem o campo na tela, libera.
@type static function
@author João Victor Guimarães Alves
@since 13/11/2026
@param aItem, array, item de MapaDatas {cTipo, cInicio, cFim, cPrazo}
@return logical, .T. quando o funcionário tem o adicional
/*/
Static Function AdcLiberado(aItem as Array) as Logical
    Local cCampo := CampoAdc(aItem[1]) as Character

    If Empty(cCampo) .Or. Type("M->" + cCampo) <> "C"
        Return .T.
    EndIf
Return AdcAtivo(&("M->" + cCampo))

/*/{Protheus.doc} CampoAdc
Campo da SRA do adicional para o tipo de histórico (mapa MV_ZHFCPOS).
@type static function
@author João Victor Guimarães Alves
@since 13/11/2026
@param cTipo, character, tipo do histórico (05 periculosidade, 06 insalubridade)
@return character, nome do campo ou vazio
/*/
Static Function CampoAdc(cTipo as Character) as Character
    Local aMapa := U_CBXHISM() as Array
    Local nPos  := aScan(aMapa, {|x| x[1] == PadR(cTipo, 2)}) as Numeric
Return IIf(nPos > 0, aMapa[nPos][2], "")

/*/{Protheus.doc} LimpaInativo
Depois de salvar o funcionário: se o adicional ficou 1=Não, limpa prazo e datas
dele na SRA (não valem sem o adicional; decisão da CAESB em 13/11/2026).
@type static function
@author João Victor Guimarães Alves
@since 13/11/2026
@param aMapa, array, mapa de CBXHISM
@param aDatas, array, retorno de MapaDatas
/*/
Static Function LimpaInativo(aMapa as Array, aDatas as Array)
    Local nI     := 0 as Numeric
    Local nAdc   := 0 as Numeric
    Local nPos   := 0 as Numeric
    Local aCpos  := {} as Array
    Local nC     := 0 as Numeric
    Local aLimpa := {} as Array

    For nI := 1 To Len(aDatas)
        nPos := aScan(aMapa, {|x| x[1] == aDatas[nI][1]})
        nAdc := IIf(nPos > 0, SRA->(FieldPos(aMapa[nPos][2])), 0)
        If nAdc == 0 .Or. AdcAtivo(SRA->(FieldGet(nAdc)))
            Loop
        EndIf
        aCpos := {aDatas[nI][2], aDatas[nI][3], aDatas[nI][4]}
        For nC := 1 To Len(aCpos)
            nPos := IIf(Empty(aCpos[nC]), 0, SRA->(FieldPos(aCpos[nC])))
            If nPos > 0 .And. !Empty(SRA->(FieldGet(nPos)))
                aAdd(aLimpa, nPos)
            EndIf
        Next nC
    Next nI

    If !Empty(aLimpa) .And. SRA->(RecLock("SRA", .F.))
        For nI := 1 To Len(aLimpa)
            If ValType(SRA->(FieldGet(aLimpa[nI]))) == "D"
                SRA->(FieldPut(aLimpa[nI], CToD("")))
            Else
                SRA->(FieldPut(aLimpa[nI], Space(Len(SRA->(FieldGet(aLimpa[nI]))))))
            EndIf
        Next nI
        SRA->(MsUnlock())
    EndIf
Return

/*/{Protheus.doc} PrazoDet
Indica se o prazo do adicional em edição (M->) permite datas: .T. quando é
2=Determinado ou quando o campo de prazo não existe.
@type static function
@author João Victor Guimarães Alves
@since 11/11/2026
@param aItem, array, item de MapaDatas {cTipo, cInicio, cFim, cPrazo}
@return logical, .T. quando as datas podem ser informadas
/*/
Static Function PrazoDet(aItem as Array) as Logical
    If Empty(aItem[4]) .Or. Type("M->" + aItem[4]) <> "C"
        Return .T.
    EndIf
Return AllTrim(&("M->" + aItem[4])) == "2"

/*/{Protheus.doc} LimpaData
Limpa um campo de data em memória (M->) do Cadastro de Funcionários.
@type static function
@author João Victor Guimarães Alves
@since 11/11/2026
@param cCampo, character, nome do campo
/*/
Static Function LimpaData(cCampo as Character)
    If Type("M->" + cCampo) == "D"
        &("M->" + cCampo) := CToD("")
    EndIf
Return

/*/{Protheus.doc} MapaDatas
Lê o parâmetro MV_ZHFDTS (opcional) com as datas de início/fim do adicional
e o prazo na SRA por tipo de histórico. Formato: 05=RA_XPERDTI,RA_XPERDTF,RA_XPERPRZ;06=...
(o campo de prazo é opcional)
@type static function
@author João Victor Guimarães Alves
@since 11/11/2026
@return array, {{cTipo, cCampoInicio, cCampoFim, cCampoPrazo}, ...}
/*/
Static Function MapaDatas() as Array
    Local aMapa  := {} as Array
    Local aItens := {} as Array
    Local aPar   := {} as Array
    Local aCpos  := {} as Array
    Local nI     := 0 as Numeric

    aItens := StrTokArr(AllTrim(GetNewPar("MV_ZHFDTS", HIS_MAPDT)), ";")
    For nI := 1 To Len(aItens)
        aPar := StrTokArr(aItens[nI] + " ", "=")
        If Len(aPar) >= 2
            aCpos := StrTokArr(aPar[2], ",")
            If Len(aCpos) >= 2
                aAdd(aMapa, {PadR(AllTrim(aPar[1]), 2), Upper(AllTrim(aCpos[1])), Upper(AllTrim(aCpos[2])), ;
                    IIf(Len(aCpos) >= 3, Upper(AllTrim(aCpos[3])), "")})
            EndIf
        EndIf
    Next nI
Return aMapa

/*/{Protheus.doc} DatasSRA
Datas de início e fim do adicional do funcionário posicionado na SRA.
@type static function
@author João Victor Guimarães Alves
@since 11/11/2026
@param cTipo, character, tipo do histórico
@param aDatas, array, retorno de MapaDatas
@return array, {dInicio, dFim, cPrazo} ou vazio quando o tipo não tem datas no cadastro
(cPrazo vazio quando o campo de prazo não existe)
/*/
Static Function DatasSRA(cTipo as Character, aDatas as Array) as Array
    Local aRet := {} as Array
    Local nPos := aScan(aDatas, {|x| x[1] == cTipo}) as Numeric
    Local nIni := 0 as Numeric
    Local nFim := 0 as Numeric
    Local nPrz := 0 as Numeric

    If nPos > 0
        nIni := SRA->(FieldPos(aDatas[nPos][2]))
        nFim := SRA->(FieldPos(aDatas[nPos][3]))
        If nIni > 0 .And. nFim > 0
            nPrz := IIf(Empty(aDatas[nPos][4]), 0, SRA->(FieldPos(aDatas[nPos][4])))
            aRet := {SRA->(FieldGet(nIni)), SRA->(FieldGet(nFim)), IIf(nPrz > 0, AllTrim(SRA->(FieldGet(nPrz))), "")}
        EndIf
    EndIf
Return aRet

/*/{Protheus.doc} AdcAtivo
Indica se o valor do campo do adicional significa que o funcionário recebe o
adicional (RA_ADCPERI/RA_ADCINS: "1" = Não).
@type static function
@author João Victor Guimarães Alves
@since 11/11/2026
@param cValor, character, valor do campo
@return logical, .T. quando tem o adicional
/*/
Static Function AdcAtivo(cValor as Character) as Logical
Return !Empty(cValor) .And. AllTrim(cValor) <> "1"

/*/{Protheus.doc} GravaCampo
Grava um campo na ZHF travada só se ele existir (dicionário pode estar sem a v3).
@type static function
@author João Victor Guimarães Alves
@since 11/11/2026
@param cCampo, character, nome do campo
@param xValor, variant, conteúdo
/*/
Static Function GravaCampo(cCampo as Character, xValor as Variant)
    Local nPos := ZHF->(FieldPos(cCampo)) as Numeric

    If nPos > 0
        ZHF->(FieldPut(nPos, xValor))
    EndIf
Return

/*/{Protheus.doc} CBXHISB
Data em texto para o log de auditoria: dd/mm/aaaa, ou "vazio".
@type user function
@author João Victor Guimarães Alves
@since 11/11/2026
@param dData, date, data
@return character, texto
/*/
User Function CBXHISB(dData as Date) as Character
    If Empty(dData)
        Return "vazio"
    EndIf
Return StrZero(Day(dData), 2) + "/" + StrZero(Month(dData), 2) + "/" + StrZero(Year(dData), 4)
