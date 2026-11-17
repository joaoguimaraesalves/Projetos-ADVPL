#include "totvs.ch"

/*/{Protheus.doc} CBGPEM13
Carga inicial dos Históricos do Funcionário: grava o valor atual dos campos
monitorados (parâmetro MV_ZHFCPOS) e o auxílio creche/financeiro dos dependentes
(tipo 09, U_CBXAUXG) de todos os funcionários não demitidos da
filial corrente que ainda não têm histórico daquele tipo. Rodar uma vez por filial.
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
/*/
User Function CBGPEM13()
    Local nGrav := 0 as Numeric

    If !MsgYesNo("Gravar a carga inicial dos históricos da filial " + AllTrim(cFilAnt) + "?" + CRLF + ;
            "Só entram funcionários não demitidos que ainda não têm histórico do tipo.", "Carga inicial")
        Return
    EndIf

    Processa({|| nGrav := Carga()}, "Carga inicial", "Gravando históricos...", .F.)

    MsgInfo("Carga concluída: " + cValToChar(nGrav) + " linha(s) gravada(s).", "Carga inicial")
Return

/*/{Protheus.doc} CBGPM13J
Carga inicial sem interface (para rodar como job ou pelo Schedule).
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
@return numeric, linhas gravadas
/*/
User Function CBGPM13J() as Numeric
Return Carga()

/*/{Protheus.doc} Carga
Percorre a SRA da filial e grava a carga inicial.
@type static function
@author João Victor Guimarães Alves
@since 29/10/2026
@return numeric, linhas gravadas
/*/
Static Function Carga() as Numeric
    Local nGrav  := 0 as Numeric
    Local aArea  := GetArea() as Array
    Local aMapa  := U_CBXHISM() as Array
    Local cFilRA := xFilial("SRA") as Character

    ProcRegua(SRA->(RecCount()))

    SRA->(DbSetOrder(1)) // RA_FILIAL+RA_MAT+RA_NOME
    SRA->(DbSeek(cFilRA))
    While !SRA->(Eof()) .And. SRA->RA_FILIAL == cFilRA
        IncProc("Matrícula " + SRA->RA_MAT)
        If SRA->RA_SITFOLH <> "D"
            nGrav += U_CBXHISG("3", aMapa)
            // Auxílio creche/financeiro dos dependentes (tipo 09), 17/11/2026
            If FindFunction("U_CBXAUXG")
                nGrav += U_CBXAUXG("3", SRA->RA_FILIAL, SRA->RA_MAT)
            EndIf
        EndIf
        SRA->(DbSkip())
    EndDo

    FWLogMsg("INFO", , "CBGPEM13", "Carga", , "01", "Carga inicial ZHF filial " + cFilRA + ": " + cValToChar(nGrav) + " linha(s).", 0, 0, {})

    RestArea(aArea)
Return nGrav
