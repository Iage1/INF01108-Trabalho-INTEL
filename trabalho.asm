;TRABALHO DE PROGRAMAÇÃO INTEL
.model small
.stack 100h 

.data ; Variáveis e constantes do programa 

    CR equ 13   ; \r
    LF equ 10   ; \n

    quebraLinha db CR, LF   ; Pra uso na escrita de arquivos
    const_dois dw 2 ; Constante dois pra uso em mul

    msgErroAbrir db "Erro ao abrir arquivo",'$'  ; Mensagens (usando a int21/AH=09h)
    msgErroLer db "Erro ao ler arquivo",'$'
    msgErroCol db "Erro nas colunas do arquivo",'$'
    msgErroEscrita db "Erro na escrita do arquivo",'$'
    msgErroOperacao db "Operacao invalida em EXP.TXT",'$'

    arqDados db "DADOS.TXT",0   ; Variáveis para os arquivos
    arqExp db "EXP.TXT",0
    arqResult db "RESULT.TXT",0
    
    handleArq dw ?
    bufferArq db 4000 dup(?) ; Buffer para armazenar todo o arquivo  
    bufferWrite db 4000 dup(?) ; Buffer para armazenar a matriz de dados convertida e escrever no arquivo
    bufferLinha db 100 dup (?) ; Buffer para armazenar um linha do arquivo de expressões e escrever no arquivo resultado
    bufferMenor db 30 dup(?)   ; Buffer menor para armazenar e converter cada numero de DADOS.TXT
    bytesLidos dw ?            ; Variável para armazenar numero de bytes lidos após int de leitura do arquivo


    sw_n dw 0   ; Variáveis da função sprintf_w
    sw_f db 0
    sw_m dw 0

    flagNeg db 0    ; Flag para a função atoi
    cont dw 0       ; Contador genérico

    numLinLew dw 1  ; Variável parâmetro para linha_exp_write
    dLinDest dw ?    ; Variável pra deslocamento até linha de destino na função calculo
    const dw ?      ; Variável pra número constante na função calculo

    stringTeste db  30 dup(?)    ; Variável usada em funções de teste

    numCol dw ? ; Número total de linhas e colunas da matriz 
    numLin dw ?
    linIndex dw ?   ; Índices de linhas e colunas para uso em funções
    colIndex dw ?

    matriz dw 2000 dup(?)   ; Reserva 2000 espaços pra matriz que contem os dados
    matrizExp dw 2000 dup(?)      ; Reserva 2000 espaços pra matriz das expressões

.code 
    .startup ; main
    
    call cmatrix
    call cmatrix_exp   


    call calculo
    
    ;mov si, 10
    ;mov ax, matriz[si]  
    ;call printf_numTeste

    
    

    .exit  

; SUBROTINAS DO PROGRAMA

cmatrix proc near
    ; Cria uma matriz no programa com base no arquivo de dados
    
    lea dx, arqDados    ; Abre o arquivo
    mov al, 0
    mov ah, 3dh
    int 21h             ; cf == 0 se ok
    jc erro_abrir
    mov handleArq, ax

    mov bx, handleArq   ; Lê o arquivo
    lea dx, bufferArq
    mov ah, 3fh
    mov cx, 4000
    int 21h             ; cf == 0 se ok, ax tem bytes lidos
    jc erro_ler
    mov bytesLidos, ax

    mov ah, 3eh         ; Fecha o arquivo
    mov bx, handleArq
    int 21h

	lea bx, bufferArq  ; adiciona o $ no final do buffer de arquivo para encontrar o fim
	mov si, bytesLidos
	mov byte ptr [bx+si], '$'

    lea si, bufferArq   ; Faz si percorrer o buffer até achar o CR (fim da linha)
    loop_numCol:
        cmp byte ptr [si], CR   ; Compara o byte apontado por si com o CR
        je fim_loop_numCol      ; Se for igual, achou o fim da linha (sai do loop)
        cmp byte ptr [si], LF   
        je fim_loop_numCol
        inc si
        jmp loop_numCol
    
    fim_loop_numCol:
        mov byte ptr [si], 0    ; Move o terminador de string (0) pro fim da linha: Buffer agora tem uma string terminada em 0
                                
    ;lea bx, bufferArq          Para verificar o valor do buffer depois de ter pego numCol
    ;call printf_s
    lea bx, bufferArq
    call atoi                   ; ax sai com o número convertido

    cmp ax, 1               ; Se estiver fora do intervalo, dá erro
    jl erro_numCol
    cmp ax, 20
    jg erro_numCol

    mov numCol, ax      ; Se não deu erro, atribui atribui o número a variável
    
    arruma_si:
        inc si                  ; Arruma o si para passar apontar pro primeiro byte da segunda linha
        cmp byte ptr [si], CR   ; Enquanto apontar para um cr ou lf (que sobrou da linha anterior) incrementa
        je arruma_si
        cmp byte ptr [si], LF
        je arruma_si

    ; A partir daqui, a função passa a coletar os dados do arquivo e armazena na matriz do programa
    mov numLin, 0  
    mov linIndex, 0         

    loop_lin:               ; Esse loop executa a cada linha da matriz
        cmp byte ptr [si], '$'  ; Se o byte apontado por si é '$', acabou a matriz
        je fim_cmatrix

        mov colIndex, 0     ; Resseta colIndex para a leitura de uma nova linha

        loop_col:  ; Loop executado para cada elemento (coluna) da matriz        
            lea di, bufferMenor     ; di para percorrer o buffer usado para os numeros
           
           escreve_buffer:              ; Loop pra escrita do numero no buffer
                mov al, byte ptr [si]   ; Necessário usar registradores (não tem transferência de memória para memória)

                cmp byte ptr [si], ';'  ; Vê se chegou no fim do número ou da linha. Do contrário, adiciona o byte pro buffer
                je fim_escreve_buffer
                cmp byte ptr [si], CR
                je fim_escreve_buffer
                cmp byte ptr [si], LF
                je fim_escreve_buffer

                mov [di], al            ; Conteudo do apontado por si pro endereço apontado por di (bufferMenor)
                inc si                  ; si vai pro próximo byte do arquivo
                inc di                  ; di pro proximo byte do buffer
                jmp escreve_buffer
            
            fim_escreve_buffer:         ; Move o terminador de string pro endereço apontado por di (que vai ser um cr ou lf) 
                mov byte ptr [di], 0    ; pra poder usar atoi no numero que o buffer pegou

            lea bx, bufferMenor
            call atoi                   ; Aqui ax sai com o numero convertido

            ; Com o número em ax, essa parte do código calcula o endereço e guarda na matriz
            mov cx, ax                  ; Passa o número para cx, pra poder usar mul

            ;Calculo do endereço é: endereço_base_matrix + (linIndex * numCol + colIndex) * 2
            mov ax, linIndex      
            mul numCol
            add ax, colIndex
            mul const_dois
            lea di, matriz      ; di armazena o endereço base da matriz
            add di, ax          ; di agora contém o endereço do elemento

            mov [di], cx        ; Armazena o numero no endereco correspondente na matriz

            ; Vai pra proxima coluna, ou pra proxima linha se tiver achado o cr ou lf
            inc colIndex 

            cmp byte ptr [si], CR  ; Se o byte apontado por si no buffer do arquivo for não ';', vai pra proxima linha
            je prox_lin            ; Do contrário, vai pra proxima coluna
            cmp byte ptr [si], LF
            je prox_lin
            cmp byte ptr [si], '$'

            inc si      
            jmp loop_col

            prox_lin:
                mov cx, colIndex    ; Primeiro checa se o número de colunas da linha bateu com o numCol fornecido, pra apontar possivel erro
                cmp cx, numCol
                jne erro_numCol

                loop_prox_lin:              ; Enquanto o conteúdo de si não for o primeiro digito da prox linha, inc si
                    cmp byte ptr [si], CR
                    je loop_prox_lin_inc
                    cmp byte ptr [si], LF
                    je loop_prox_lin_inc
                    jmp fim_prox_lin

                    loop_prox_lin_inc:
                        inc si
                        jmp loop_prox_lin
                
                fim_prox_lin:
                    inc linIndex
                    jmp loop_lin

    erro_abrir:
        lea dx, msgErroAbrir    ; Int 21/AH=09h para mostrar a mensagem
        mov ah, 09h
        int 21h

        mov al, 0       ; Int 21/AH=4Ch para encerrar o programa
        mov ah, 4ch   
        int 21h


    erro_ler:
        lea dx, msgErroLer
        mov ah, 09h
        int 21h

        mov al, 0      
        mov ah, 4ch   
        int 21h

    erro_numCol:
        lea dx, msgErroCol
        mov ah, 09h
        int 21h

        mov al, 0      
        mov ah, 4ch   
        int 21h

    fim_cmatrix:
        mov ax, linIndex
        mov numLin, ax
        ret
cmatrix endp

cmatrix_exp proc near
    ; Cria uma matriz no programa com base no arquivo de expressões
    ; [0 - flag de escrita no arquivo sim/nao (0/1) |2 - valor da linha da matriz que será alterada |4 - flag pra ver se valor 1 é ref/const (0/1) |6 - valor 1
    ; |8 - operação |10 - flag pra ver se valor 2 é ref/const (0/1) |12 - valor 2]
    ; NUMCOL DE EXP É 7 PARA CÁLCULOS FUTURAMENTE
    lea dx, arqExp    ; Abre o arquivo
    mov al, 0
    mov ah, 3dh
    int 21h             ; cf == 0 se ok
    jc erro_abrir
    mov handleArq, ax

    mov bx, handleArq   ; Lê o arquivo
    lea dx, bufferArq
    mov ah, 3fh
    mov cx, 4000
    int 21h             ; cf == 0 se ok, ax tem bytes lidos
    jc erro_ler
    mov bytesLidos, ax

    mov ah, 3eh         ; Fecha o arquivo
    mov bx, handleArq
    int 21h

    lea bx, bufferArq           ; Move caractere terminador para o final do buffer
    mov si, bytesLidos
    mov byte ptr [bx+si], 0

    lea si, bufferArq   ; si vai percorrer o buffer
    mov bx, 0           ; bx vai atuar no modo indexado na matriz

    loop_lin_cme:   ; Pra cada linha do arquivo, repete o processo
    
        cmp byte ptr [si], 0    ; Compara com o terminador colocado após o fechamento do arquivo
        je fim_cmatrix_exp

        word0_exp:
            mov matrizExp[bx], 0
            cmp byte ptr [si], '*'  ; Primeiro vê a flag que indica se o arquivo será escrito ou não
            jne word1_exp

            mov matrizExp[bx], 1       ; Acende flag de escrita
            inc si                  ; Vai pro primeiro caractere de fato
            jmp word1_exp

        word1_exp:
            inc si  ; si vai pro numero e bx vai pra proxima palavra da matriz (começo do número)
            inc bx
            inc bx
            
            lea di, bufferMenor ; bufferMenor pra receber e converter o numero em int

            loop_word1_exp:             ; Armazena os algarismos do numero um a um, até encontrar o final (']')
                cmp byte ptr [si], ']'  
                je fim_loop_word1_exp
                
                mov al, byte ptr [si]   
                mov [di], al
                inc di
                inc si
                jmp loop_word1_exp

            fim_loop_word1_exp:
                mov byte ptr [di], 0    ; Caractere terminador no final da string
                
            push bx                     ; Guarda o bx na pilha pra não perder o valor, já que atoi precisa que a string a ser convertida seja passada por bx
            lea bx, bufferMenor
            call atoi          
            pop bx
            
            mov matrizExp[bx], ax   ; ax sai da função atoi com o número convertido
        
        word2_exp:
            inc si      ; si passa por '=' e agora aponta pra um possivel '[' / numero
            inc si
            inc bx      ; bx pro byte 4 da linha
            inc bx
            
            mov matrizExp[bx], 0    ; Começa assumindo que é referencia

            cmp byte ptr [si], '['  ; Se realmente for, vai pra prox word. Do contrário, acende a flag de que é uma const
            je word3_exp

            mov matrizExp[bx], 1
            dec si                  ; Ajusta o ponteiro, pra estar no mesmo lugar pra word3_exp, mesmo se tivesse o colchete

        word3_exp:
            inc si                  ; Deve estar apontando pro primeiro digito do numero
            inc bx                  ; bx pro byte 6 
            inc bx
            lea di, bufferMenor     ; Resseta a posição de di pra percorrer bufferMenor do início novamente

            cmp byte ptr [si], '-'  ; Tratamento para numeros negativos necessário pra verificação seguinte não falhar
            jne loop_word3_exp

            mov byte ptr [di], '-'
            inc di
            inc si                  ; Agora sim, se era neg, vai estar apontando pro primeiro digito

            loop_word3_exp:             ; Armazena os algarismos do numero um a um, até não encontrar um numero (pode ser uma expressao ou o colchete)
                cmp byte ptr [si], '0'  
                jl fim_loop_word3_exp
                cmp byte ptr [si], '9'
                jg fim_loop_word3_exp
                
                mov al, byte ptr [si]   
                mov [di], al
                inc di
                inc si
                jmp loop_word3_exp

            fim_loop_word3_exp:
                mov byte ptr [di], 0    ; Caractere terminador no final da string
                
            push bx                     ; Guarda o bx na pilha pra não perder o valor, já que atoi precisa que a string a ser convertida seja passada por bx
            lea bx, bufferMenor
            call atoi            
            pop bx

            mov matrizExp[bx], ax   ; ax sai da função atoi com o número convertido


            cmp matrizExp[bx-2], 0  ; Tratamento pra si apontar pro mesmo lugar em word4_exp, mesmo que não haja colchete. Se tiver colchete, da certo sem alteracao
            je word4_exp            ; Se há colchete, pode continuar. Do contrário, decrementa 1 (já que em word4_exp vai ser incrementado 1, considerando o colchete]
            dec si

        word4_exp:
            inc si  ; Aqui deve estar apontando pra operação
            inc bx  ; bx pro byte 8
            inc bx
            
            mov al, byte ptr [si]        ; Simplesmente guarda a operação
            mov ah, 0                    ; Como a matriz é de words tem que zerar a parte alta ao atribuir só o byte de baixo
            mov matrizExp[bx], ax

        word5_exp:
            inc si  ; Deve estar apontando ou pra '[' ou pra um numero
            inc bx  ; bx pro byte 10
            inc bx
            
            mov matrizExp[bx], 0    ; Começa assumindo que é referencia

            cmp byte ptr [si], '['  ; Se realmente for, vai pra prox word. Do contrário, acende a flag de que é uma const
            je word6_exp

            mov matrizExp[bx], 1
            dec si                  ; Ajusta o ponteiro, pra estar no mesmo lugar pra word6_exp, mesmo se tivesse o colchete

        word6_exp:
            inc si  ; si deve estar apontando pro inicio do numero
            inc bx  ; bx pro byte 12
            inc bx
            lea di, bufferMenor

            cmp byte ptr [si], '-'  ; Tratamento para numeros negativos necessário pra verificação seguinte não falhar
            jne loop_word6_exp

            mov byte ptr [di], '-'
            inc di
            inc si                  ; Agora sim, se era neg, vai estar apontando pro primeiro digito

            loop_word6_exp:
                cmp byte ptr [si], '0'  
                jl fim_loop_word6_exp
                cmp byte ptr [si], '9'
                jg fim_loop_word6_exp
                
                mov al, byte ptr [si]   
                mov [di], al
                inc di
                inc si
                jmp loop_word6_exp

            fim_loop_word6_exp:
                mov byte ptr [di], 0    ; Caractere terminador no final da string
            
            push bx                     ; Guarda o bx na pilha pra não perder o valor, já que atoi precisa que a string a ser convertida seja passada por bx
            lea bx, bufferMenor
            call atoi       
            pop bx

            mov matrizExp[bx], ax   ; ax sai da função atoi com o número convertido

            cmp matrizExp[bx-2], 0  ; Tratamento pra si apontar pro mesmo lugar, mesmo que não haja colchete. Se tiver colchete, da certo sem alteracao
            je prox_lin_cme            ; Se há colchete, pode continuar. Do contrário, decrementa 1 
            dec si

        prox_lin_cme:
            inc bx  ; Ja incrementa o bx pra word 0 da segunda linha
            inc bx
            inc si  ; cr
            inc si  ; lf
            inc si  ; primeiro digito da linha de baixo
            jmp loop_lin_cme

    fim_cmatrix_exp:
        mov matrizExp[bx], '$'  ; Coloca um terminador no fim da matriz de expressões
        ret

cmatrix_exp endp

matrix_write proc near
    ; Escreve a matriz de dados atual no arquivo de resultado:
    ; Transforma a matriz em string e passa para um buffer, abre result.txt, acha o terminador no arquivo e escreve a matriz em baixo

    mov colIndex, 0
    mov linIndex, 0
    lea si, bufferWrite     ; si vai percorrer o buffer grande

    loop_lin_mw:
        mov cx, linIndex    ; Se o indice atual da linha for (igual / maior, tem que ver) que o total de linhas, vai pro final
        cmp cx, numLin
        je escrita_result_mw

        mov colIndex, 0     ; Zera o indice das colunas ao entrar na nova linha
        
        loop_col_mw:     ; Vai pegar o número da matriz, converter em string, escrever no buffer, colocar ';' ou cr lf
            mov cx, colIndex    ; Se o indice atual da coluna for o maximo, vai pra proxima linha
            cmp cx, numCol
            je prox_lin_mw

            ;Calculo do endereço é: matriz[(linIndex * numCol + colIndex) * 2]
            mov ax, linIndex
            mul numCol
            add ax, colIndex
            mul const_dois
            mov di, ax

            mov ax, matriz[di]  ; Converte o elemento em string e escreve em bufferMenor
            lea bx, bufferMenor
            call sprintf_w
            
            lea di, bufferMenor

            loop_escreve_mw:    ; Escreve a string de bufferMenor em bufferWrite
                mov al, byte ptr [di]

                cmp al, 0               ; Enquanto não chega no fim da string, escreve o byte do buffer menor no buffer grande
                je fim_loop_escreve_mw

                mov [si], al 
                inc si
                inc di
                jmp loop_escreve_mw
            
            fim_loop_escreve_mw:
                mov [si], ';'
                inc si
                inc colIndex
                jmp loop_col_mw
        
        prox_lin_mw:   ; Escreve um cr lf no buffer, e inc pra proxima linha
            dec si
            mov [si], CR
            inc si
            mov [si], LF
            inc si

            inc linIndex
            jmp loop_lin_mw


    ; A partir daqui a função deve localizar de onde a escrita no arquivo parou, escrever o buffer (matriz) logo após, e colocar o terminador (para futuras escritas)
    ; Enquanto o arquivo não for fechado, a posição do cabeçote é salva  
    escrita_result_mw:
        mov [si], 0   ; Adiciona o caractere terminador ao fim do buffer
    
        lea dx, arqResult    ; Abre o arquivo
        mov al, 2            ; al = 2 para leitura e escrita
        mov ah, 3dh
        int 21h             ; cf == 0 se ok
        jc erro_abrir_mw
         mov handleArq, ax

        mov ah, 42h         ; int parecida com um "fseek"
        mov al, 2           ; Aqui posiciona o cabeçote pro final do arquivo
        mov bx, handleArq
        mov cx, 0
        mov dx, 0
        int 21h
    
        ; Quebra a linha pra escrever na parte de baixo
        ;mov ah, 40h         ; int de escrita
        ;mov bx, handleArq   
        ;mov cx, 2          ; Número de bytes a serem escritos
        ;lea dx, quebraLinha
        ;int 21h
        ;jc erro_escrita_mw
    
        lea di, bufferWrite
        mov cont, 0
        loop_tam_buffer_mw:     ; Calcula o tamanho do buffer pra passar por parâmetro em cx na proxima escrita
        
            cmp byte ptr [di], 0
            je fim_loop_tam_buffer_mw

            inc cont
            inc di
            jmp loop_tam_buffer_mw
    
        fim_loop_tam_buffer_mw:

            mov ah, 40h         ; Escreve o buffer no arquivo de resultados
            mov bx, handleArq
            mov cx, cont
            lea dx, bufferWrite
            int 21h
            jc erro_escrita_mw

            mov ah, 3eh         ; Fecha o arquivo
            mov bx, handleArq
            int 21h
    
            jmp fim_mw
    
    
    erro_abrir_mw:
        lea dx, msgErroAbrir    ; Int 21/AH=09h para mostrar a mensagem
        mov ah, 09h
        int 21h

        mov al, 0       ; Int 21/AH=4Ch para encerrar o programa
        mov ah, 4ch   
        int 21h

    erro_escrita_mw:
        lea dx, msgErroEscrita
        mov ah, 09h
        int 21h

        mov al, 0
        mov ah, 4ch
        int 21h
    
    fim_mw:
        ret

matrix_write endp

linha_exp_write proc near
    ; Escreve uma linha do arquivo de expressões no arquivo de resultados
    ; Passar a linha como parametro na funcao de calculo numLinLew

    lea dx, arqExp    ; Abre o arquivo
    mov al, 0
    mov ah, 3dh
    int 21h             ; cf == 0 se ok
    jc erro_abrir
    mov handleArq, ax

    mov bx, handleArq   ; Lê o arquivo
    lea dx, bufferArq
    mov ah, 3fh
    mov cx, 4000
    int 21h             ; cf == 0 se ok, ax tem bytes lidos
    jc erro_ler
    mov bytesLidos, ax

    mov ah, 3eh         ; Fecha o arquivo
    mov bx, handleArq
    int 21h

	lea bx, bufferArq  ; adiciona o $ no final do buffer de arquivo para encontrar o fim
	mov si, bytesLidos
	mov byte ptr [bx+si], '$'

    mov cont, 0
    lea si, bufferArq

    loop_lew:
        mov ax, cont
        cmp ax, numLinLew
        je fim_loop_lew

        lea di, bufferLinha

        loop_escreve_lew:
            cmp byte ptr [si], CR       ; Enquanto não achar o fim da linha, continua escrevendo no bufferLinha
            je fim_loop_escreve_lew

            mov al, byte ptr [si]
            mov [di], al
            inc si
            inc di
            jmp loop_escreve_lew

        fim_loop_escreve_lew:
            inc cont
            mov byte ptr [di], CR  ; CRLF, Caracter terminador e incremento de si pra pra passar do cr lf
            inc di
            mov byte ptr [di], LF
            inc di
            mov byte ptr [di], '$'

            inc si
            inc si
            jmp loop_lew

    fim_loop_lew:       ; Escreve o último buffer linha na matriz result
        
        lea dx, arqResult    ; Abre o arquivo
        mov al, 2            ; al = 2 para leitura e escrita
        mov ah, 3dh
        int 21h             ; cf == 0 se ok
        jc erro_abrir_lew
        mov handleArq, ax

        mov ah, 42h         ; int parecida com um "fseek"
        mov al, 2           ; Aqui posiciona o cabeçote pro final do arquivo
        mov bx, handleArq
        mov cx, 0
        mov dx, 0
        int 21h

    lea di, bufferLinha
    mov cont, 0
    
    loop_tam_buffer_lew:     ; Calcula o tamanho do buffer pra passar por parâmetro em cx na proxima escrita
        
        cmp byte ptr [di], '$'
        je fim_loop_tam_buffer_lew

        inc cont
        inc di
        jmp loop_tam_buffer_lew
    
    fim_loop_tam_buffer_lew:

    mov ah, 40h         ; Escreve o buffer no arquivo de resultados
    mov bx, handleArq
    mov cx, cont
    lea dx, bufferLinha
    int 21h
    jc erro_escrita_lew

    mov ah, 3eh         ; Fecha o arquivo
    mov bx, handleArq
    int 21h
    
    jmp fim_linha_exp_write

    erro_abrir_lew:
        lea dx, msgErroAbrir    ; Int 21/AH=09h para mostrar a mensagem
        mov ah, 09h
        int 21h

        mov al, 0       ; Int 21/AH=4Ch para encerrar o programa
        mov ah, 4ch   
        int 21h

    erro_escrita_lew:
        lea dx, msgErroEscrita
        mov ah, 09h
        int 21h

        mov al, 0
        mov ah, 4ch
        int 21h

    fim_linha_exp_write:
        ret
linha_exp_write endp

calculo proc near

    mov bx, 0   ; bx vai percorrer a matriz de expressões word a word
    mov numLinLew, 1    ; Número da linha dentro do arquivo de exp. Parâmentro para linha_exp_write. Começa em 1 

    loop_calc:                  ; Execução pra cada linha de matrizExp
        mov cont, 0 ; cont vai ser usado adiante
        
        cmp matrizExp[bx], '$' ; Procura o caractere termiandor, colocado na matriz em cmatrix_exp
        je fim_calculo

        ; Pra cada linha, 3 situações: [v1] ? [v2] / [v1] ? v2 / v1 ? [v2]
        cmp matrizExp[bx+4], 1          ; Verifica se v1 é constante
        je const_linha_calc             ; Se for, vai pra calculo considerando v1 ? [v2]. Do contrário, segue a verificação

        cmp matrizExp[bx+10], 1         ; verifica se v2 é constante
        je linha_const_calc             ; Se for, vai pra calculo considerando [v1] ? v2. Do contrario, só pode ser [v1] ? [v2]
        
        linha_linha_calc:   ; [v1] ? [v2]
            ; si no modo indexado pra pegar o endereço do primeiro elemento da linha v1
            ; di no modo indexado pra pegar o endereço do primeiro elemento da linha v2

            mov ax, matrizExp[bx+6]     ; Calcula si de modo que matriz[si] -> matriz[(linIndex * numCol + colIndex) * 2 ] (v1)
            mul numCol                  ; Tem o deslocamento do endereço original pro endereço com o elemento
            mul const_dois
            mov si, ax  

            mov ax, matrizExp[bx+12]    ; O mesmo pra di (v2)
            mul numCol
            mul const_dois
            mov di, ax

            mov ax, matrizExp[bx+2]     ; Guarda o deslocamento para linha de destino em uma variável
            mul numCol
            mul const_dois
            mov dLinDest, ax


            ; Calculo da operação
            loop_LL:
                mov ax, numCol      ; Repete pra cada coluna, cont é incrementado no final
                cmp ax, cont
                je fim_loop_LL

                mov ax, matriz[si]  ; Passa o elemento da vez da linha 1 pra ax
                mov cx, matriz[di]  ; Passa o elemento da vez da linha 2 pra cx

                call calc_op ; ax deve retornar com o resultado do elemento da vez

                push bx         ; Armazena o elemento na posição apropriada na linha de destino. Guarda o bx pra não perder a word atual de matrizExp
                mov bx, dLinDest
                mov matriz[bx], ax
                pop bx

                inc si  ; Proximo elemento da matriz, tanto para quem acompanha v1(si), v2(di) e o destino (dLinDest)
                inc si
                inc di
                inc di
                inc dLinDest
                inc dLinDest

                inc cont
                jmp loop_LL
            
            fim_loop_LL:
                cmp matrizExp[bx], 1    ; Verifica flag de escrita para escrever no arquivo resultado
                jne prox_lin_calc

                push bx
                call linha_exp_write
                call matrix_write
                pop bx

                jmp prox_lin_calc

        const_linha_calc:   ; v1 ? [v2]
            
            mov ax, matrizExp[bx+6]      ; Passa o valor direto da matriz de expressões para cx, já que é constante
            mov const, ax               

            mov ax, matrizExp[bx+12]   ; Deslocamento da matriz de dados até a linha v2 
            mul numCol
            mul const_dois
            mov di, ax

            mov ax, matrizExp[bx+2]     ; Guarda o deslocamento para linha de destino em dLinDest
            mul numCol
            mul const_dois
            mov dLinDest, ax

            loop_CL:
                mov ax, numCol          ; Processo análogo ao em loop_LL
                cmp ax, cont
                je fim_loop_CL

                mov ax, const
                mov cx, matriz[di]

                call calc_op

                push bx
                mov bx, dLinDest
                mov matriz[bx], ax
                pop bx

                inc di  ; prox word da matriz
                inc di
                inc dLinDest    ; Prox elemento da linha de destino
                inc dLinDest

                inc cont
                jmp loop_CL

            fim_loop_CL:
                cmp matrizExp[bx], 1    ; Verifica flag de escrita para escrever no arquivo resultado
                jne prox_lin_calc

                push bx
                call linha_exp_write
                call matrix_write
                pop bx

                jmp prox_lin_calc
        
        linha_const_calc:   ; [v1] ? v2

            mov ax, matrizExp[bx+6]      
            mul numCol
            mul const_dois
            mov si, ax

            mov ax, matrizExp[bx+12]
            mov const, ax

            mov ax, matrizExp[bx+2]
            mul numCol
            mul const_dois
            mov dLinDest, ax

            loop_LC:
                mov ax, numCol
                cmp ax, cont
                je fim_loop_LC

                mov ax, matriz[si]
                mov cx, const

                call calc_op

                push bx
                mov bx, dLinDest
                mov matriz[bx], ax
                pop bx

                inc si
                inc si
                inc dLinDest
                inc dLinDest

                inc cont
                jmp loop_LC
            
            fim_loop_LC:
                cmp matrizExp[bx], 1
                jne prox_lin_calc

                push bx
                call linha_exp_write
                call matrix_write
                pop bx

                jmp prox_lin_calc

    prox_lin_calc:
        add bx, 14 ; Prox linha da matriz de expressões
        inc numLinLew
        jmp loop_calc
        
    fim_calculo:
        ret

calculo endp

calc_op proc near
    ; Função pra ser chamada exclusivamente na função calculo
    ; Faz a operação com base no que está armazenado na linha word4 da matrizExp
    ; ax carrega o primeiro valor e cx o segundo. bx tem o deslocamento pro primeiro elemento da linha da matrizExp
    
    
    cmp matrizExp[bx+8], '+'    ; Vê qual a operação deve ser feita
    je soma_calc
    cmp matrizExp[bx+8], '-'
    je sub_calc
    cmp matrizExp[bx+8], '*'
    je mult_calc
    cmp matrizExp[bx+8], '/'
    je div_calc
    cmp matrizExp[bx+8], '%'
    je resto_calc
    cmp matrizExp[bx+8], '&'
    je and_calc
    cmp matrizExp[bx+8], '|'
    je or_calc
    cmp matrizExp[bx+8], '^'
    je xor_calc
    
    jmp fim_calc_op

    soma_calc:
        add ax, cx
        jmp fim_calc_op
    
    sub_calc:
        sub ax, cx
        jmp fim_calc_op
    
    mult_calc:                  ; imul e idiv para operações com sinal
        imul cx
        jmp fim_calc_op

    div_calc:
        cwd
        idiv cx
        jmp fim_calc_op
    
    resto_calc:
        cwd                     ; cwd (convert word to doubleword) necessário uma vez que o dividendo em em idiv é dx:ax. Ele converte ax em um numero de 32 bits pra dx:ax
        idiv cx             
        mov ax, dx              ; O resto é armazenado em dx na operação de divisão
        jmp fim_calc_op
    
    and_calc:
        and ax, cx
        jmp fim_calc_op

    or_calc:
        or ax, cx
        jmp fim_calc_op
    
    xor_calc:
        xor ax, cx
        jmp fim_calc_op

    fim_calc_op:
        ret

calc_op endp

atoi proc near
    ; Converte string em número 
    ; Passar o endereço da string em bx "lea bx, string"
    ; ax sai com o número convertido
    ; Modifica ax e bx
	mov		ax,0 	;AX = 0		
		
    cmp     byte ptr[bx], '-'   ; Verifica se o numero é negativo
    jne     atoi_2
    mov     flagNeg, 1
    inc     bx

atoi_2:

    cmp		byte ptr[bx], 0	;[bx] corresponde ao acesso ao endereço apontado por bx, já a diretiva byte ptr indica que devemos acessar um byte do endereço apontado por bx
	jz		atoi_1			;se achou o terminador nulo, sai da função

	mov		cx,10			;CX = 10
	mul		cx				;A * CX(10); mul sempre age sobre o que está no registrador A

	mov		ch,0			;CH = 0, corresponde a zerar a parte baixa de CX
	mov		cl,[bx]			;Colocamos o caractere apontado pelo registrador BX em CL
	add		ax,cx			;Adiciona esse valor ao AX, que é onde está sendo construído o número

	sub		ax,'0'			;Subtrai o 0 em ascii para converter de fato o número

	inc		bx				;Passa para o próximo byte da string
		
	jmp		atoi_2

atoi_1:
	cmp flagNeg, 0
    je return_atoi

    neg ax

return_atoi:
    mov flagNeg, 0
    ret

atoi	endp

sprintf_w proc near		
    ; Converte número em string
    ; Passar o número em ax, e o endereço aonde a string vai ser escrita (buffer) em bx 
    ; Modifica do ax ao dx e bp
	mov		sw_n,ax				;Coloca o número a ser convertido na variável sw_n
	cmp 	sw_n, 0
	jge		ehPosSprintf
	neg		sw_n
	mov		[bx],'-'
	inc 	bx

ehPosSprintf:	
	mov		cx,5				;Inicializa o CX com 5 para servir como contador da repetição
	mov		sw_m,10000			;Inicializa com 10000 a variável sw_m para que ela vá divindo o número e convertendo para string
	mov		sw_f,0				;Flag que indica se já começamos a armazenar dígitos, serve para garantir que não iremos guardar zeros à esquerda
	
sw_do:

	mov		dx,0				;DX = 0, pois a divisão se dá por DX:AX/ sw_m			DX = Resto(para ser usado depois)		Al = Dígito atual
	mov		ax,sw_n				;Inicializa o AX, que servirá como divisor na operação "DIV", com o valor de sw_n, que contém o número a ser convertido
	div		sw_m				
	
	cmp		al,0				;Compara o digito atual com 0
	jne		sw_store			;Se não for zero, guarda o número
	cmp		sw_f,0				;Se for zero, checa se já estamos escrevendo o número, se ainda não estamos, pula a parte de guardar, pois não queremos guardar zeros à esquerda
	je		sw_continue			

sw_store:
	add		al,'0'				;Adiciona '0' para converter o dígito para ascii
	mov		[bx],al				;Colocamos o dígito convertido no endereço apontado por bx
	inc		bx					;Incrementamos o ponteiro onde está segundo guardada a string
	
	mov		sw_f,1				;Seta como ativa a flag que indica que já começamos a escrever o número
sw_continue:
	
	mov		sw_n,dx				;Coloca na variável responsável por guardar o número durante a conversão o resto da divisão feita anteriormente
	
	mov		dx,0				;Zera o resto atual
	mov		ax,sw_m				;Divide o sw_m (que começa em 10000) por 10
	mov		bp,10				
	div		bp
	mov		sw_m,ax				;Guarda no sw_m seu novo valor
	
	dec		cx					;Diminui a variável que controla o tamanho do número que estamos convertendo
	
	cmp		cx,0				;Verifica se terminamos de converter o número
	jnz		sw_do

	cmp		sw_f,0				;Verifica se terminamos a conversão sem ter começado alguma escrita e escreve forçadamente um '0' no endereço da string
	jnz		sw_continua2
	mov		[bx],'0'
	inc		bx
sw_continua2:

	mov		byte ptr[bx],0		;Garante o terminador nulo ao final da string
		
	ret
		
sprintf_w	endp

printf_s proc near		
    ; Escreve uma string na tela
    ; Passar o endereço da string a ser escrita em bx
    ; Modifica ax, bx e dx
	mov		dl,[bx]				;Move para o registrador DL (que opera como uma extensão do AX), o endereço apontado por BX
	cmp		dl,0				;Compara para ver se chegou ao \0
	je		ps_1				;Jump se igual

	push	bx					;Coloca bx na pilha
	mov		ah,2				;Chama o serviço '2' da int 21H, que funciona espeficiamente para exibir um caracte na tela, sendo que este caractere deve estar no DL
	int		21H					;O serviço de interrupção para a execução normal do programa e passa o o controle para o sistema operacional
	pop		bx					;Retorna o último valor colocado na pilha para o bx (isso é feito pois durante a interrupção pode acontecer do registrador BX ser alterado durante a interrupção)

	inc		bx					;Incrementa o ponteiro para a posição da string
		
	jmp		printf_s			;Volta para o começo da função
		
ps_1:
	
    ret
	
printf_s	endp

; SUBROTINAS DE TESTE
printf_numTeste proc near
    ; Função printa um numero 
    ; Passar o numero a ser printado em ax antes de chamar
    ; Modifica ax e bx
       
    lea bx, stringTeste
    call  sprintf_w

    lea bx, stringTeste
    call printf_s

    ret
printf_numTeste endp


end 