#include "totvs.ch"
#include "fwmvcdef.ch"

/*/{Protheus.doc} GPEA020
Ponto de entrada MVC do cadastro de Dependentes (modelo GPEA020). Depois da
gravação (MODELCOMMITNTTS) chama U_CBXAUXP, que grava o histórico tipo 09
(auxílio creche/financeiro) de cada dependente que mudou. Se o ambiente já tiver
um User Function GPEA020, acrescentar só o bloco do MODELCOMMITNTTS no fonte
existente (outro fonte com a mesma função dá "Duplicated function").
@type user function
@author João Victor Guimarães Alves
@since 17/11/2026
@return logical, .T.
/*/
User Function GPEA020()
    Local aParam := PARAMIXB
    Local xRet   := .T.

    If aParam <> Nil .And. aParam[2] == "MODELCOMMITNTTS" .And. FindFunction("U_CBXAUXP")
        U_CBXAUXP(aParam[1])
    EndIf
Return xRet
