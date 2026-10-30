#include "totvs.ch"

/*/{Protheus.doc} GPE10MENU
Ponto de entrada — inclui a opção "Históricos" no aRotina do Cadastro de
Funcionários (GPEA010). Usado em ambientes cujo GPEA010 ainda não chama o
GPE10OPC; se a opção já veio pelo GPE10OPC, não duplica.
Documentação: https://tdn.totvs.com/pages/releaseview.action?pageId=6079250
@type user function
@author João Victor Guimarães Alves
@since 29/10/2026
@obs Se o ambiente já tiver um GPE10MENU, juntar o bloco abaixo ao fonte existente.
@see GPEA010
/*/
User Function GPE10MENU()
    If Type("aRotina") == "A"
        If aScan(aRotina, {|x| ValType(x[2]) == "C" .And. Upper(AllTrim(x[2])) == "U_ZGPA010F"}) == 0
            aAdd(aRotina, {"Históricos", "U_ZGPA010F", 0, 7, 0, Nil})
        EndIf
    EndIf
Return Nil
