#INCLUDE 'PROTHEUS.CH'    // Inclui definições padrão do Protheus
#INCLUDE 'FWMVCDEF.CH'    // Inclui definições para o framework MVC
#INCLUDE 'FWMBROWSE.CH'   // Inclui definições para o FWmBrowse
#INCLUDE 'TOTVS.CH'
#INCLUDE 'FILEIO.CH'

/*/ function F0100110
Exemplo de um cadastro simples de Regiões utilizando o framework MVC.
O fonte utiliza a tabela ZA6 - Criada por mim para testes e modificações do cadastros de clientes.

@author João Victor Guimarães Alves
@since 26/06/2025
/*/
User Function F0100110()

	Local oBrowse

	oBrowse := FWmBrowse():New()
	oBrowse:SetAlias( 'ZA6' )
	oBrowse:SetDescription( 'Cadastro de Regiões' )
	oBrowse:Activate()

Return NIL


/*/ function MenuDef
	Criação de menu da rotina de cadastro de regiões.

	@author João Victor Guimarães Alves
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
	Criação de medelo da roina de cadastro de regiões.

	@author João Victor Guimarães Alves
	@since 26/06/2025
/*/
Static Function ModelDef()

	// Cria a estrutura a ser usada no Modelo de Dados
	Local oStruZA6 := FWFormStruct( 1, 'ZA6', /*bAvalCampo*/, /*lViewUsado*/ )
	Local oModel


	// Cria o objeto do Modelo de Dados
	//oModel := MPFormModel():New('M0100110', /*bPreValidacao*/, /*bPosValidacao*/, /*bCommit*/, /*bCancel*/ )
	// A validação de exclusão será feita via bPosValidacao.
	oModel := MPFormModel():New( 'M0100110', /*bPreValidacao*/ , { | oMdl | ModelPosVd( oMdl ) } , /*bCommit*/ , /*bCancel*/ )

	// Adiciona ao modelo uma estrutura de formulário de edição por campo (ZA6MASTER)
	oModel:AddFields( 'ZA6MASTER', /*cOwner*/, oStruZA6 )

	// Define chave primária
	oModel:SetPrimaryKey( {"ZA6_FILIAL", "ZA6_CDREG"} )

	// Adiciona a descrição do Modelo de Dados
	oModel:SetDescription( 'Modelo de Cadastro de Regiões' )

	// Adiciona a descrição do Componente do Modelo de Dados (ZA6MASTER)
	oModel:GetModel( 'ZA6MASTER' ):SetDescription( 'Dados da Região' )

Return oModel


/*/ function ViewDef
	Criação do view da rotina de cadastro de regiões.
	@author João Victor Guimarães Alves
	@since 26/06/2025
/*/
Static Function ViewDef()

	// Cria um objeto de Modelo de Dados baseado no ModelDef do fonte informado
	Local oStruZA6 := FWFormStruct( 2, 'ZA6' ) // Estrutura para visualização

	// Cria a estrutura a ser usada na View
	Local oModel := FWLoadModel( 'F0100110' )
	Local oView

	// Cria o objeto de View
	oView := FWFormView():New()

	// Define qual o Modelo de dados será utilizado
	oView:SetModel( oModel )

	// Adiciona no nosso View um controle do tipo FormFields para ZA6
	oView:AddField( 'VIEW_ZA6', oStruZA6, 'ZA6MASTER' )

	// Criar um "box" horizontal para receber algum elemento da view
	oView:CreateHorizontalBox( 'SUPERIOR', 100 ) // Ocupa 100% pois não há grid inferior

	// Relaciona o ID da View com o "box" para exibição
	oView:SetOwnerView( 'VIEW_ZA6', 'SUPERIOR' )

Return oView


/*/ function ModelPosVd
	Criação de modelo de pos validação na ação de exclusão de regiões.
	A função é utilizada para validar a exclusão de regiões, impedindo a exclusão de regiões que estão sendo utilizadas por clientes.
	@author João Victor Guimarães Alves
	@since 26/06/2025
/*/
Static Function ModelPosVd( oModel )
// Função de pos-validação do modelo, utilizada para validar a exclusão de regiões.
	Local lRet        := .T.    // Variável de retorno da função (True = permite, False = impede)
	Local nOperation  := oModel:GetOperation()      // Obtém a operação atual
	Local cCodReg     := ZA6->ZA6_CDREG
	Local cMsgPro     := ""
	Local cMsgSol     := ""

	if nOperation == MODEL_OPERATION_DELETE
		SA1->(dbsetorder(14))
		If SA1->(DbSeek(XFILIAL("SA1") + cCodReg))
			lRet := .F.
			cMsgPro := "A região '" + cCodReg + "' está sendo utilizada por clientes e não pode ser excluída."
			cMsgSol := "Cancele a operação de exclusão e verifique o cadastro de clientes."
			Help( Nil, Nil, 'F0100110', Nil, cMsgPro, 1, 0, Nil, Nil, Nil, Nil, Nil, {cMsgSol})

		EndIf

	Endif
Return lRet


 /*/ User Function TNPexemp
	Criação de uma tela de processamento, separada por janelas onde visualiza-se a importação de clinetes de um CSV e o log de processamento.
	@author Joao Victor Guimarães Alves
	@since 02/07/2025
/*/

User Function TNPexemp()
	Local aArea      := FWGetArea()
	Local bBlocoExec := {|oSelf| ImprtCSV(oSelf)}

	//Cria a tela de processamento
	TNewProcess():New("ImprtCSV" , "Importação CSV", bBlocoExec, "Importação de arquivos CSV", /*cPerg*/, /*aInfoCustom*/, /*lPanelAux*/, /*nSizePanelAux*/, /*cDescriAux*/,.T.)

	FWRestArea(aArea)
Return



/*/ Static Function ImprtCSV
	Fonte modificado utilizado para importar REGISTROS DE CLIENTES, através do arquivo TXT/CSV
	@author Joao Victor Guimarães Alves
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

	FT_FUSE(cDiret)  //Abre e fecha um arquivo texto para disponibilizar às funções FT_F*.
	ProcRegua(FT_FLASTREC()) //Lê e retorna o número total de linhas do arquivo texto aberto pela função FT_FUse().
	FT_FGOTOP()  //Posiciona no início do arquivo texto aberto pela função FT_FUse().
	While !FT_FEOF() //Move o ponteiro, que indica a leitura do arquivo texto, para a posição absoluta especificada no parâmetro .

		IncProc("Lendo arquivo texto...")

		cLinha := FT_FREADLN()  //Lê e retorna uma linha de texto do arquivo aberto pela função FT_FUse().

		If lPrimlin
			aCampos := Separa(cLinha,";",.T.)
			lPrimlin := .F.
		Else
			AADD(aDados,Separa(cLinha,";",.T.))
		EndIf

		FT_FSKIP()  //Move o ponteiro, do arquivo texto aberto pela função FT_FUse(), para uma nova posição.
	EndDo

	ProcRegua(Len(aDados))
	For i:=1 to Len(aDados)

		IncProc("Importando Registros...")

		dbSelectArea("ZA6")
		dbSetOrder(1)   //Indice
		dbGoTop()
		If !dbSeek(xFilial("ZA6")+ aDados[i,1])
			Reclock("ZA6",.T.)  // Permite a inclusão de um novo registro - Reclock == Insert
			ZA6->ZA6_FILIAL := xFilial("ZA6")
			ZA6->ZA6_CDREG := aDados[i,1]
		else
			Reclock("ZA6",.F.)  // Permite a alteração de um registro
		Endif
		ZA6->ZA6_DSREG := aDados[i,2]
		// caso haja mais campos a serem importados, descomente esta parte
		//For j:=1 to Len(aCampos)
		//   cCampo  := "ZA6->" + aCampos[j] //ZA6->ZA6_CDREG
		//   &cCampo := aDados[i,j] //ZA6->ZA6_CDREG := 000001   ZA6->ZA6_DSREG := AGUAS CLARAS
		//Next j
		ZA6->(MsUnlock())
	Next i
	ApMsgInfo("Importação concluída com sucesso!","Sucesso!")

Return


/*/ User Function TNPexe02 (TNewProcess)
	Criação de uma tela de processamento, separada por janelas onde visualiza-se a importação de clinetes de um CSV e o log de processamento.
	@author Joao Victor Guimarães Alves
	@since 08/07/2025
/*/
User Function TNPexe02()
	Local aArea      := FWGetArea()
	Local bBlocoExec := {|oSelf| ImprtCSV2(oSelf) }

	//Cria a tela de processamento
	TNewProcess():New("ImprtCSV2" , "Importação CSV 2", bBlocoExec, "Importação de arquivos CSV 2", /*cPerg*/, /*aInfoCustom*/, /*lPanelAux*/, /*nSizePanelAux*/, /*cDescriAux*/, .T.)

	FWRestArea(aArea)
Return

/*/ Static Function ImprtCSV2
	Fonte utilizado para importar REGISTROS DE CLIENTES, através do arquivo TXT/CSV, por uma rotina execauto
	@author Joao Victor Guimarães Alves
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
	Função que processa o arquivo e realiza a importação para o sistema
	@author João Victor Guimarães Alves
	@since 30/07/2025
/*/
Static Function fImporta(cArqSel)

	Local 	cDir    		:= Left(cArqSel, RAt("\", cArqSel))		// Pega todos os caracteres até a ultima "\";  Ex: (C:\ImportJV\)
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
	Private aDados2         := {} // Será usado para a importação de cada linha
	Private cSeparador   	:= ';'
	Private aRotina      	:= FWLoadMenuDef('MATA010')
	Private oModel       	:= Nil

	//Abre as tabelas que serão usadas
	DbSelectArea('ZA6')
	ZA6->(DbSetOrder(1)) // ZA6_FILIAL + ZA6_CDREG
	ZA6->(DbGoTop())

	oArquivo := FWFileReader():New(cArqSel)

	If (oArquivo:Open())

		ProcRegua(0)
		// Laço da importação
		While (oArquivo:HasLine())

			nLinhaAtu++ 	// Incrementa o contador da linha atual
			cLinAtu := AllTrim(oArquivo:GetLine())	// Pega a linha atual e tenta transformá-la em array
			aLinha  := Separa(cLinAtu, cSeparador)

			oModel := FWLoadModel('F0100110')
			oModel:SetOperation( MODEL_OPERATION_INSERT )
			lRet := oModel:Activate()

			If nLinhaAtu > 1    // Pula a primeira linha do arquivo(cabeçalho)

				cCodigoTratado := AllTrim(aLinha[1]) // Pega o código do arquivo e remove espaços
				If Len(cCodigoTratado) <> GetSx3Cache("ZA6_CDREG", "X3_TAMANHO")	//Verifica se o código tem o tamanho incorreto (maior que 6)
					// Se for inválido, gera um erro, adiciona ao log e pula para a próxima linha do arquivo
					cMsgErro := "Linha " + cValToChar(nLinhaAtu) + ": " + cLinAtu + " | Motivo: O código deve ter " + cValToChar(GetSx3Cache("ZA6_CDREG", "X3_TAMANHO")) + " dígitos."
					AAdd(aErrosGerais, {cArqSel, .T., cMsgErro, "", 0,0})
				Else
					// Verifica se nao existe o registro
					If !dbSeek(xFilial("ZA6") + cCodigoTratado)

						// Instanciamos apenas a parte do modelo referente aos dados de cabeçalho
						oAux    := oModel:GetModel( 'ZA6MASTER' )
						// Obtemos a estrutura de dados do cabeçalho
						oStruct := oAux:GetStruct()
						aAux	:= oStruct:GetFields()

						If lRet

							lRet := oModel:SetValue("ZA6MASTER",'ZA6_CDREG',cCodigoTratado)
							lRet := oModel:SetValue("ZA6MASTER",'ZA6_DSREG',AllTrim(aLinha[2]))

							If lRet
								If ( lRet := oModel:VldData() )	// neste momento os dados não são gravados, são somente validados.
									lRet := oModel:CommitData()	// Se o dados foram validados faz-se a gravação efetiva dos dados (commit)
								EndIf
							EndIf
						Endif
						If !lRet
							// Se os dados não foram validados obtemos a descrição do erro para gerar LOG ou mensagem de aviso
							aErro   := oModel:GetErrorMessage()
							//Se a variável aErro não estiver vazia e o tipo da variável aErro for um Array.
							If !Empty(aErro) .And. ValType(aErro) == 'A'
								//FWAlertInfo( aErro[6] + CRLF + aErro[7], "Erro na Linha " + cValToChar(nLinhaAtu) )
								cMsgErro := "Linha " + cValToChar(nLinhaAtu) + ": " + cLinAtu + " | Motivo: " + aErro[6]
								// Verifica se existe uma mensagem de solução e a concatena
								If !Empty(aErro[7])
									cMsgErro += " | Solução: " + aErro[7]
								EndIf

								aAdd(aErrosGerais, {cArqSel, "", cMsgErro, "", 0,0})
							Endif
						Endif

						oModel:DeActivate() // Desativa o modelo após o uso

					Else
						//MsgAlert("O Código (" + aDados2[1][2] + ") não foi importado, pois já existe no banco de dados!", "Atenção")
						cMsgErro    := "Linha " + cValToChar(nLinhaAtu) + ": " + cLinAtu + " | Motivo: Registro já existe no banco de dados."
						aAdd(aErrosGerais, {cArqSel, "", cMsgErro, "", 0,0}) 
					EndIf
				EndIf
				
			EndIf

		EndDo

		oArquivo:Close()

		If Len(aErrosGerais) > 0

			// Este bloco será executado se houver erros gerais
			If MsgYesNo("Importação não efetuada ou com erros. Deseja ver os detalhes encontrados?", "Atenção")
				cArqErr := "ERROS_GERAIS_" + DTOS(Date()) + "_" + StrTran(Time(), ":", "") + ".txt"
				nHandle := FCREATE(cDir+cArqErr)
				If nHandle <> -1
					For nX := 1 to Len(aErrosGerais)
						// aErrosGerais[nX] é um array: {Número da linha, Houve erro, Mensagem de erro}
						If aErrosGerais[nX][3] <> "" 
							FWrite(nHandle, "- Erro: " + aErrosGerais[nX][3] + CRLF )
						EndIf
					Next nX
					FClose(nHandle)

					MsgInfo("Foi gerado o arquivo " + cDir + cArqErr + " com o log de erros.", "Atenção")
				Else
					MsgAlert("Não foi possível criar o arquivo com o log de erros gerais.", "Atenção")
				EndIf
			EndIf
		Else
			MsgInfo("Importação concluída!", "Atenção")
		EndIf
	Else
		FWAlertError('Arquivo não pode ser aberto! Verifique permissões ou se o arquivo existe.', 'Atenção')
	EndIf

Return
