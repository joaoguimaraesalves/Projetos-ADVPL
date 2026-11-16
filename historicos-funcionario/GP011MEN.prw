#include "totvs.ch"

/*/{Protheus.doc} GP011MEN
Ponto de entrada da Gestão de Funcionários (GPEA011): inclui a opção
"Históricos" no menu Funcionários, igual à do Cadastro de Funcionários
(GPE10OPC). Abre os históricos (ZHF) do funcionário posicionado.
Documentação: https://tdn.totvs.com/pages/releaseview.action?pageId=6079100
@type user function
@author João Victor Guimarães Alves
@since 11/11/2026
@return array, aFuncion (opções do menu Funcionários) com a opção nova
@obs Se o ambiente já tiver um GP011MEN, juntar o aAdd abaixo ao fonte existente.
@see GPEA011
/*/
User Function GP011MEN() as Array
    Local aOpcoes := {} as Array

    If Type("aFuncion") == "A"
        aOpcoes := aClone(&("aFuncion"))
    EndIf

    aAdd(aOpcoes, {"Históricos", "U_CBGPA21F", 0, 7, 0, Nil})
Return aOpcoes
