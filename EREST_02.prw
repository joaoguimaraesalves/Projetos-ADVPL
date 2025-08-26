#Include 'TOTVS.ch'
#Include 'FWMVCDEF.ch'
#Include 'RestFul.CH'

/*
@author     João Victor Guimarães
@version    2.0
@date       13/08/2025
@description
    WebService REST para retornar informações de um cliente (tabela SA1)
    buscando pelo seu CPF.
*/
// http://localhost:8012/rest/CLIENTES?CPF="CPF do cliente"

WSRESTFUL CLIENTES DESCRIPTION "Serviço REST para consulta de Clientes"
    WSDATA CPF As String
    WSMETHOD GET DESCRIPTION "Retorna os dados do cliente informado (via CPF) na URL" WSSYNTAX "/CLIENTES/{CPF}"
END WSRESTFUL

//   IMPLEMENTAÇÃO DO MÉTODO GET
WSMETHOD GET WSRECEIVE CPF WSSERVICE CLIENTES

Local cCPF          := Self:CPF      // Pega o valor do CPF vindo da URL
Local lBloqueado    := .F.           // Flag de cliente bloqueado
Local cTipo         := ""            // Tipo de pessoa (Física/Jurídica)
Local jResponse     := JsonObject():New()
Local aEnderecos    := JsonObject():New()
Local aEndereco     := JsonObject():New()
Local aEndCobranca  := JsonObject():New()
Local aEndEntrega   := JsonObject():New()
Local aEndRecebto   := JsonObject():New()

DbSelectArea("SA1")
SA1->( DbSetOrder(3) )

If SA1->( DbSeek( xFilial("SA1") + cCPF ) )

    lBloqueado := (SA1->A1_MSBLQL == "1")
    cTipo      := Iif(SA1->A1_PESSOA == "F", "Física", "Jurídica")
    
    // Estrutura de Endereço PRINCIPAl
    aEndereco['A1_END' ]    := RTrim(SA1->A1_END)
    aEndereco['A1_BAIRRO' ] :=  RTrim(SA1->A1_BAIRRO)
    aEndereco['A1_ESTADO']  := SA1->A1_ESTADO
    aEndereco['A1_EST' ]    := SA1->A1_EST
    aEndereco['A1_CEP'  ]   := SA1->A1_CEP
    aEndereco['A1_MUN' ]    := RTrim(SA1->A1_MUN)
    aEndereco['A1_COD_MUN'] := SA1->A1_COD_MUN
    aEndereco['A1_REGIAO' ] := RTrim(SA1->A1_REGIAO)
    aEndereco['A1_DSCREG' ] := RTrim(SA1->A1_DSCREG)

    //Estrutura de Endereço De COBRANÇA
    aEndCobranca['A1_ENDCOB' ]      := RTrim(SA1->A1_ENDCOB)
    aEndCobranca['A1_BAIRROC' ]     := RTrim(SA1->A1_BAIRROC)
    aEndCobranca['A1_ESTC' ]        := RTrim(SA1->A1_ESTC)
    aEndCobranca['A1_CEPC' ]        := SA1->A1_CEPC
    aEndCobranca['A1_MUNC' ]        := RTrim(SA1->A1_MUNC)

    // Estrutura de Endereço de ENTREGA
    aEndEntrega['A1_ENDENT' ]      := RTrim(SA1->A1_ENDENT)
    aEndEntrega['A1_BAIRROE' ]     := RTrim(SA1->A1_BAIRROE)
    aEndEntrega['A1_ESTE' ]        := RTrim(SA1->A1_ESTE)
    aEndEntrega['A1_CEPE' ]        := SA1->A1_CEPE
    aEndEntrega['A1_MUNE' ]        := RTrim(SA1->A1_MUNE)
    aEndEntrega['A1_CODMUNE' ]     := RTrim(SA1->A1_CODMUNE)

    // Estrutura de Endereço de Recebimento
    aEndRecebto['A1_ENDREC' ]      := RTrim(SA1->A1_ENDREC)

    // Estrutura de Arryas dos endereços
    aEnderecos['ENDERECO PRINCIPAL'] := aEndereco
    aEnderecos['ENDCOBRANCA'] := aEndCobranca
    aEnderecos['ENDENTREGA'] := aEndEntrega
    aEnderecos['ENDRECEBTO'] := aEndRecebto

    // Estrutura final que sera mostrada em formato JSON
    jResponse['A1_COD'] := SA1->A1_COD 
    jResponse['A1_LOJA'] := SA1->A1_LOJA
    jResponse['A1_NOME'] := EncodeUTF8(RTrim(SA1->A1_NOME))
    jResponse['A1_NREDUZ'] := RTrim(SA1->A1_NREDUZ)
    jResponse['A1_CGC'] := SA1->A1_CGC
    jResponse['A1_PESSOA'] := EncodeUTF8(cTipo)
    jResponse['A1_MSBLQL'] :=  lBloqueado
    jResponse['A1_EMAIL'] := RTrim(SA1->A1_EMAIL)
    jResponse['A1_TEL'] := RTrim(SA1->A1_TEL)
    jResponse['ENDERECOS'] := aEnderecos

Else
    // Ajusta a chamada para o caso de erro, passando NIL para os novos campos
    jResponse['Problema'] := EncodeUTF8('Código do CPF não encontrado na tabela ')
    jResponse[EncodeUTF8('Solução')] := EncodeUTF8('Confira novamente o código digitado ou cadastre este cliente no protheus.')
EndIf

    //Define o retorno; Monta o jResponse em um JSON
    Self:SetContentType('application/json')
    Self:SetResponse(jResponse:toJSON())

Return(.T.)

