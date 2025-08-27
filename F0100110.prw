#INCLUDE 'PROTHEUS.CH'    // Inclui defini��es padr�o do Protheus
#INCLUDE 'FWMVCDEF.CH'    // Inclui defini��es para o framework MVC
#INCLUDE 'FWMBROWSE.CH'   // Inclui defini��es para o FWmBrowse
#INCLUDE 'TOTVS.CH'
#INCLUDE 'FILEIO.CH'

/*/ function F0100110
Exemplo de um cadastro simples de Regi�es utilizando o framework MVC.
O fonte utiliza a tabela ZA6 - Criada por mim para testes e modifica��es do cadastros de clientes.

@author Jo�o Victor Guimar�es Alves
@since 26/06/2025
/*/
User Function F0100110()

	Local oBrowse

	oBrowse := FWmBrowse():New()
	oBrowse:SetAlias( 'ZA6' )
	oBrowse:SetDescription( 'Cadastro de Regi�es' )
	oBrowse:Activate()

Return NIL


/*/ function MenuDef
	Cria��o de menu da rotina de cadastro de regi�es.

	@author Jo�o Victor Guimar�es Alves
	@since 26/06/2025
/*/
Static Function MenuDef()

	Local aRotina := {}

	ADD OPTION aRotina Title 'Visualizar' Action 'VIEWDEF.F0100110'     OPERATION 2     ACCESS 0
	ADD OPTION aRotina Title 'Incluir'    Action 'VIEWDEF.F0100110'     OPERATION 3     ACCESS 0
	ADD OPTION aRotina Title 'Alterar'    Action 'VIEWDEF.F0100110'     OPERATION 4     ACCESS 0
	ADD OPTION aRotina Title 'Excluir'    Action 'VIEWDEF.F0100110'     OPERATION 5     ACCESS 0
	ADD OPTION aRotina Title 'Imprimir'   Action 'VIEWDEF.F0100110'     OPERATION 8     ACCESS 0
	ADD OPTION aRotina Title 'Copiar'     Action 'VIEWDEF.F0100110'     OPERATION 9     ACCESS 0
	ADD OPTION aRotina Title 'Importar'   Action 'U_TNPexemp()'         OPERATION 10    ACCESS 0
	ADD OPTION aRotina Title 'Importar 2' Action 'U_TNPexe02()'         OPERATION 11    ACCESS 0
	ADD OPTION aRotina Title 'Importar 3' Action 'U_F01IMPRT()'        	OPERATION 12    ACCESS 0
	//MODEL_OPERATION_INSERT
Return aRotina


/*/ function ModelDef
	Cria��o de medelo da roina de cadastro de regi�es.

	@author Jo�o Victor Guimar�es Alves
	@since 26/06/2025
/*/
Static Function ModelDef()

	// Cria a estrutura a ser usada no Modelo de Dados
	Local oStruZA6 := FWFormStruct( 1, 'ZA6', /*bAvalCampo*/, /*lViewUsado*/ )
	Local oModel


	// Cria o objeto do Modelo de Dados
	//oModel := MPFormModel():New('M0100110', /*bPreValidacao*/, /*bPosValidacao*/, /*bCommit*/, /*bCancel*/ )
	// A valida��o de exclus�o ser� feita via bPosValidacao.
	oModel := MPFormModel():New( 'M0100110', /*bPreValidacao*/ , { | oMdl | ModelPosVd( oMdl ) } , /*bCommit*/ , /*bCancel*/ )

	// Adiciona ao modelo uma estrutura de formul�rio de edi��o por campo (ZA6MASTER)
	oModel:AddFields( 'ZA6MASTER', /*cOwner*/, oStruZA6 )

	// Define chave prim�ria
	oModel:SetPrimaryKey( {"ZA6_FILIAL", "ZA6_CDREG"} )

	// Adiciona a descri��o do Modelo de Dados
	oModel:SetDescription( 'Modelo de Cadastro de Regi�es' )

	// Adiciona a descri��o do Componente do Modelo de Dados (ZA6MASTER)
	oModel:GetModel( 'ZA6MASTER' ):SetDescription( 'Dados da Regi�o' )

Return oModel


/*/ function ViewDef
	Cria��o do view da rotina de cadastro de regi�es.
	@author Jo�o Victor Guimar�es Alves
	@since 26/06/2025
/*/
Static Function ViewDef()

	// Cria um objeto de Modelo de Dados baseado no ModelDef do fonte informado
	Local oStruZA6 := FWFormStruct( 2, 'ZA6' ) // Estrutura para visualiza��o

	// Cria a estrutura a ser usada na View
	Local oModel := FWLoadModel( 'F0100110' )
	Local oView

	// Cria o objeto de View
	oView := FWFormView():New()

	// Define qual o Modelo de dados ser� utilizado
	oView:SetModel( oModel )

	// Adiciona no nosso View um controle do tipo FormFields para ZA6
	oView:AddField( 'VIEW_ZA6', oStruZA6, 'ZA6MASTER' )

	// Criar um "box" horizontal para receber algum elemento da view
	oView:CreateHorizontalBox( 'SUPERIOR', 100 ) // Ocupa 100% pois n�o h� grid inferior

	// Relaciona o ID da View com o "box" para exibi��o
	oView:SetOwnerView( 'VIEW_ZA6', 'SUPERIOR' )

Return oView


/*/ function ModelPosVd
	Cria��o de modelo de pos valida��o na a��o de exclus�o de regi�es.
	A fun��o � utilizada para validar a exclus�o de regi�es, impedindo a exclus�o de regi�es que est�o sendo utilizadas por clientes.
	@author Jo�o Victor Guimar�es Alves
	@since 26/06/2025
/*/
Static Function ModelPosVd( oModel )
// Fun��o de pos-valida��o do modelo, utilizada para validar a exclus�o de regi�es.
	Local lRet        := .T.    // Vari�vel de retorno da fun��o (True = permite, False = impede)
	Local nOperation  := oModel:GetOperation()      // Obt�m a opera��o atual
	Local cCodReg     := ZA6->ZA6_CDREG
	Local cMsgPro     := ""
	Local cMsgSol     := ""

	if nOperation == MODEL_OPERATION_DELETE
		SA1->(dbsetorder(14))
		If SA1->(DbSeek(XFILIAL("SA1") + cCodReg))
			lRet := .F.
			cMsgPro := "A regi�o '" + cCodReg + "' est� sendo utilizada por clientes e n�o pode ser exclu�da."
			cMsgSol := "Cancele a opera��o de exclus�o e verifique o cadastro de clientes."
			Help( Nil, Nil, 'F0100110', Nil, cMsgPro, 1, 0, Nil, Nil, Nil, Nil, Nil, {cMsgSol})

		EndIf

	Endif
Return lRet


 /*/ User Function TNPexemp
	Cria��o de uma tela de processamento, separada por janelas onde visualiza-se a importa��o de clinetes de um CSV e o log de processamento.
	@author Joao Victor Guimar�es Alves
	@since 02/07/2025
/*/

User Function TNPexemp()
	Local aArea      := FWGetArea()
	Local bBlocoExec := {|oSelf| ImprtCSV(oSelf)}

	//Cria a tela de processamento
	TNewProcess():New("ImprtCSV" , "Importa��o CSV", bBlocoExec, "Importa��o de arquivos CSV", /*cPerg*/, /*aInfoCustom*/, /*lPanelAux*/, /*nSizePanelAux*/, /*cDescriAux*/,.T.)

	FWRestArea(aArea)
Return



/*/ Static Function ImprtCSV
	Fonte modificado utilizado para importar REGISTROS DE CLIENTES, atrav�s do arquivo TXT/CSV
	@author Joao Victor Guimar�es Alves
	@since 02/07/2025
/*/
Static Function ImprtCSV()

	Local cDiret
	Local cLinha  := ""
	Local lPrimlin   := .T.
	Local aCampos := {}
	Local aDados  := {}
	Local i		  := {}
	Private aErro := {}

	cDiret :=  cGetFile( 'Arquivo CSV|*.csv| Arquivo TXT|*.txt| Arquivo XML|*.xml',; //[ cMascara],
	'Selecao de Arquivos',;                  //[ cTitulo],
	0,;                                      //[ nMascpadrao],
	'C:',;                                   //[ cDirinicial],
	.F.,;                                    //[ lSalvar],
	GETF_LOCALHARD  + GETF_NETWORKDRIVE,;    //[ nOpcoes],
	.T.)

	FT_FUSE(cDiret)  //Abre e fecha um arquivo texto para disponibilizar �s fun��es FT_F*.
	ProcRegua(FT_FLASTREC()) //L� e retorna o n�mero total de linhas do arquivo texto aberto pela fun��o FT_FUse().
	FT_FGOTOP()  //Posiciona no in�cio do arquivo texto aberto pela fun��o FT_FUse().
	While !FT_FEOF() //Move o ponteiro, que indica a leitura do arquivo texto, para a posi��o absoluta especificada no par�metro .

		IncProc("Lendo arquivo texto...")

		cLinha := FT_FREADLN()  //L� e retorna uma linha de texto do arquivo aberto pela fun��o FT_FUse().

		If lPrimlin
			aCampos := Separa(cLinha,";",.T.)
			lPrimlin := .F.
		Else
			AADD(aDados,Separa(cLinha,";",.T.))
		EndIf

		FT_FSKIP()  //Move o ponteiro, do arquivo texto aberto pela fun��o FT_FUse(), para uma nova posi��o.
	EndDo

	ProcRegua(Len(aDados))
	For i:=1 to Len(aDados)

		IncProc("Importando Registros...")

		dbSelectArea("ZA6")
		dbSetOrder(1)   //Indice
		dbGoTop()
		If !dbSeek(xFilial("ZA6")+ aDados[i,1])
			Reclock("ZA6",.T.)  // Permite a inclus�o de um novo registro - Reclock == Insert
			ZA6->ZA6_FILIAL := xFilial("ZA6")
			ZA6->ZA6_CDREG := aDados[i,1]
		else
			Reclock("ZA6",.F.)  // Permite a altera��o de um registro
		Endif
		ZA6->ZA6_DSREG := aDados[i,2]
		// caso haja mais campos a serem importados, descomente esta parte
		//For j:=1 to Len(aCampos)
		//   cCampo  := "ZA6->" + aCampos[j] //ZA6->ZA6_CDREG
		//   &cCampo := aDados[i,j] //ZA6->ZA6_CDREG := 000001   ZA6->ZA6_DSREG := AGUAS CLARAS
		//Next j
		ZA6->(MsUnlock())
	Next i
	ApMsgInfo("Importa��o conclu�da com sucesso!","Sucesso!")

Return


/*/ User Function TNPexe02 (TNewProcess)
	Cria��o de uma tela de processamento, separada por janelas onde visualiza-se a importa��o de clinetes de um CSV e o log de processamento.
	@author Joao Victor Guimar�es Alves
	@since 08/07/2025
/*/
User Function TNPexe02()
	Local aArea      := FWGetArea()
	Local bBlocoExec := {|oSelf| ImprtCSV2(oSelf) }

	//Cria a tela de processamento
	TNewProcess():New("ImprtCSV2" , "Importa��o CSV 2", bBlocoExec, "Importa��o de arquivos CSV 2", /*cPerg*/, /*aInfoCustom*/, /*lPanelAux*/, /*nSizePanelAux*/, /*cDescriAux*/, .T.)

	FWRestArea(aArea)
Return

/*/ Static Function ImprtCSV2
	Fonte utilizado para importar REGISTROS DE CLIENTES, atrav�s do arquivo TXT/CSV, por uma rotina execauto
	@author Joao Victor Guimar�es Alves
	@since 30/07/2025
/*/
Static Function ImprtCSV2()

	Local aArea := FWGetArea()
	Local cArqSel := ''

	cArqSel :=  cGetFile( 	'Arquivo CSV|*.csv| Arquivo TXT|*.txt| Arquivo XML|*.xml',; //[ cMascara],
							'Selecao de Arquivos',;                  					//[ cTitulo],
							0,;                                      					//[ nMascpadrao],
							'C:',;                              						//[ cDirinicial],
							.F.,;                                    					//[ lSalvar],
							GETF_LOCALHARD,;    										//[ nOpcoes],
							.F.)

	//Se tiver o arquivo selecionado e ele existir
	If !Empty(cArqSel) .And. File(cArqSel)
		Processa({|| fImporta(cArqSel) }, 'Importando...')
	EndIf

	FWRestArea(aArea)
Return

/*/ Static Function fImporta
	Fun��o que processa o arquivo e realiza a importa��o para o sistema
	@author Jo�o Victor Guimar�es Alves
	@since 30/07/2025
/*/
Static Function fImporta(cArqSel)

	Local 	cDir    		:= Left(cArqSel, RAt("\", cArqSel))		// Pega todos os caracteres at� a ultima "\";  Ex: (C:\ImportJV\)
	Local 	cLinAtu    		:= ''
	Local 	nLinhaAtu  		:= 0
	Local 	aLinha     		:= {}
	Local 	oArquivo
	Local 	cArqErr 		:= ""
	Local 	nHandle 		:= ""
	Local 	aErrosGerais 	:= {}
	Local 	nX 				:= 0
	Local   cMsgErro        := ""
	Local  	lRet      		:= .T.
	Local	aErro			:= {}
	Local 	cCodigoTratado 	:=	""
	Private aDados2         := {} // Ser� usado para a importa��o de cada linha
	Private cSeparador   	:= ';'
	Private aRotina      	:= FWLoadMenuDef('MATA010')
	Private oModel       	:= Nil

	//Abre as tabelas que ser�o usadas
	DbSelectArea('ZA6')
	ZA6->(DbSetOrder(1)) // ZA6_FILIAL + ZA6_CDREG
	ZA6->(DbGoTop())

	oArquivo := FWFileReader():New(cArqSel)

	If (oArquivo:Open())

		ProcRegua(0)
		// La�o da importa��o
		While (oArquivo:HasLine())

			nLinhaAtu++ 	// Incrementa o contador da linha atual
			cLinAtu := AllTrim(oArquivo:GetLine())	// Pega a linha atual e tenta transform�-la em array
			aLinha  := Separa(cLinAtu, cSeparador)

			oModel := FWLoadModel('F0100110')
			oModel:SetOperation( MODEL_OPERATION_INSERT )
			lRet := oModel:Activate()

			If nLinhaAtu > 1    // Pula a primeira linha do arquivo(cabe�alho)

				cCodigoTratado := AllTrim(aLinha[1]) // Pega o c�digo do arquivo e remove espa�os
				If Len(cCodigoTratado) <> GetSx3Cache("ZA6_CDREG", "X3_TAMANHO")	//Verifica se o c�digo tem o tamanho incorreto (maior que 6)
					// Se for inv�lido, gera um erro, adiciona ao log e pula para a pr�xima linha do arquivo
					cMsgErro := "Linha " + cValToChar(nLinhaAtu) + ": " + cLinAtu + " | Motivo: O c�digo deve ter " + cValToChar(GetSx3Cache("ZA6_CDREG", "X3_TAMANHO")) + " d�gitos."
					AAdd(aErrosGerais, {cArqSel, .T., cMsgErro, "", 0,0})
				Else
					// Verifica se nao existe o registro
					If !dbSeek(xFilial("ZA6") + cCodigoTratado)

						// Instanciamos apenas a parte do modelo referente aos dados de cabe�alho
						oAux    := oModel:GetModel( 'ZA6MASTER' )
						// Obtemos a estrutura de dados do cabe�alho
						oStruct := oAux:GetStruct()
						aAux	:= oStruct:GetFields()

						If lRet

							lRet := oModel:SetValue("ZA6MASTER",'ZA6_CDREG',cCodigoTratado)
							lRet := oModel:SetValue("ZA6MASTER",'ZA6_DSREG',AllTrim(aLinha[2]))

							If lRet
								If ( lRet := oModel:VldData() )	// neste momento os dados n�o s�o gravados, s�o somente validados.
									lRet := oModel:CommitData()	// Se o dados foram validados faz-se a grava��o efetiva dos dados (commit)
								EndIf
							EndIf
						Endif
						If !lRet
							// Se os dados n�o foram validados obtemos a descri��o do erro para gerar LOG ou mensagem de aviso
							aErro   := oModel:GetErrorMessage()
							//Se a vari�vel aErro n�o estiver vazia e o tipo da vari�vel aErro for um Array.
							If !Empty(aErro) .And. ValType(aErro) == 'A'
								//FWAlertInfo( aErro[6] + CRLF + aErro[7], "Erro na Linha " + cValToChar(nLinhaAtu) )
								cMsgErro := "Linha " + cValToChar(nLinhaAtu) + ": " + cLinAtu + " | Motivo: " + aErro[6]
								// Verifica se existe uma mensagem de solu��o e a concatena
								If !Empty(aErro[7])
									cMsgErro += " | Solu��o: " + aErro[7]
								EndIf

								aAdd(aErrosGerais, {cArqSel, "", cMsgErro, "", 0,0})
							Endif
						Endif

						oModel:DeActivate() // Desativa o modelo ap�s o uso

					Else
						//MsgAlert("O C�digo (" + aDados2[1][2] + ") n�o foi importado, pois j� existe no banco de dados!", "Aten��o")
						cMsgErro    := "Linha " + cValToChar(nLinhaAtu) + ": " + cLinAtu + " | Motivo: Registro j� existe no banco de dados."
						aAdd(aErrosGerais, {cArqSel, "", cMsgErro, "", 0,0}) 
					EndIf
				EndIf
				
			EndIf

		EndDo

		oArquivo:Close()

		If Len(aErrosGerais) > 0

			// Este bloco ser� executado se houver erros gerais
			If MsgYesNo("Importa��o n�o efetuada ou com erros. Deseja ver os detalhes encontrados?", "Aten��o")
				cArqErr := "ERROS_GERAIS_" + DTOS(Date()) + "_" + StrTran(Time(), ":", "") + ".txt"
				nHandle := FCREATE(cDir+cArqErr)
				If nHandle <> -1
					For nX := 1 to Len(aErrosGerais)
						// aErrosGerais[nX] � um array: {N�mero da linha, Houve erro, Mensagem de erro}
						If aErrosGerais[nX][3] <> "" 
							FWrite(nHandle, "- Erro: " + aErrosGerais[nX][3] + CRLF )
						EndIf
					Next nX
					FClose(nHandle)

					MsgInfo("Foi gerado o arquivo " + cDir + cArqErr + " com o log de erros.", "Aten��o")
				Else
					MsgAlert("N�o foi poss�vel criar o arquivo com o log de erros gerais.", "Aten��o")
				EndIf
			EndIf
		Else
			MsgInfo("Importa��o conclu�da!", "Aten��o")
		EndIf
	Else
		FWAlertError('Arquivo n�o pode ser aberto! Verifique permiss�es ou se o arquivo existe.', 'Aten��o')
	EndIf

Return
