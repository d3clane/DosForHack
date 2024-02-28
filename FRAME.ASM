;------------------------------------------------
;Prints frame and string in it
;Entry: ds:si - memory with frame info begin
;       memory have to end with '$' symbol
;Exit : None
;Destr: ax, bx, cx, dx, si, di, es
;------------------------------------------------
PrintFrame proc
        cld

        call ReadFrameParams

        push cx
        call ReadFrameStyle
        xor al, al      ; read frame style changes al, there should lie 0 
                        ; (color in ah, 0 in al)
        pop cx

        push si         ; pointer to the cmd string
        mov si, dx

        push bx
        push cx
        call PrintFrameShell
        pop cx
        pop bx
        pop si

        call PrintString  

        ret
        endp    

        
;------------------------------------------------
;Prints one line of the frame
;Entry: ds:si - points to the beginning of the 3-chars array (left, middle, right)
;       es:di - points to the beginning of the video ram to print in
;       ah - color
;       bx - width
;       DF flag set. DF = 0 -> left to right. DF = 1 -> reversed.
;Exit : ds:si moves to the end of the array
;       es:di moves on (bx) bytes to the right
;Destr: cx, si, di
;------------------------------------------------   
PrintLine proc
        lodsb   ; loading to al
        stosw   ; pushing left char

        lodsb   ; loading mid char
        mov cx, bx
        sub cx, 2   ; calculate number of cycle iterations
        rep stosw 

        lodsb   
        stosw       ; pushing right char

        ret
        endp


;------------------------------------------------
;Prints full frame
;Entry: ds:si - points to the beginning of the 9-chars array 
;       ah - frame color
;       bx - frame width
;       cx - frame height
;Exit : ds:si moves to the end of the array
;Destr: cx, si, di, es, dx, bx
;------------------------------------------------   
PrintFrameShell proc
        mov di, 0B800h
        mov es, di

        SCREEN_WIDTH  				equ 80d
        NUMBER_OF_BYTES_PER_CHAR	        equ 2d
        
        call CenterFrame

        mov dx, cx
        call PrintLine      ; prints top line
        mov cx, dx
        
        sub di, bx  ; moving back to the beginning of the line
        sub di, bx  ; twice because of NUMBER_OF_BYTES_PER_CHAR = 2
        add di, SCREEN_WIDTH * NUMBER_OF_BYTES_PER_CHAR ; next line

        sub cx, 2 ; height
InLoop: mov dx, cx
        push si
        call PrintLine
        sub di, bx  ; moving back to the beginning of the line
        sub di, bx  ; twice because of NUMBER_OF_BYTES_PER_CHAR = 2
        add di, SCREEN_WIDTH * NUMBER_OF_BYTES_PER_CHAR ; next line
        pop si
        mov cx, dx
        loop InLoop

        add si, 3   ; moving ds:si to the next 3 chars (bottom line)
        call PrintLine

        ret
        endp


;------------------------------------------------
;Center frame and returns left top corner coord
;Entry: bx - frame width
;       cx - frame height
;Exit : di points to the left top corner of the frame
;Destr: di, dx
;------------------------------------------------   
CenterFrame proc
        SCREEN_WIDTH  				equ 80d
	SCREEN_MIDDLE_LINE		        equ 13d
        SCREEN_MIDDLE_COLUMN                    equ 40d
        
        ; Centring frame 

        mov di, SCREEN_WIDTH + 2 * SCREEN_WIDTH * SCREEN_MIDDLE_LINE
        sub di, bx
        and di, -2      ; it have to be even (like bx / 2 * 2)

        mov dx, cx
        and dx, -2      ;dx & 0b1111..10 equals dx >> 1; dx << 1
        shl dx, 2       ;dx * 4
        add dx, cx      ;4 * dx + cx 
        and dx, -2      ;getting rid of last bit that cx added (if it exists)
        shl dx, 4       ; 5 * dx * 16 = 80 * dx

        sub di, dx

        ret
        endp

;------------------------------------------------
;Reads value in decimal from memory ds:si and stores in ax
;Entry: ds:si - pointer to the string beginning
;       es = ds
;Exit : ax - readen value, 
;       ds:si - points to the char after the string
;Destr: ax, bx, cx, dx, di, si
;------------------------------------------------   
MoveDecimalToRegister proc
        mov di, si
        call SkipSpaces

        mov si, di      ; moving to si str ptr after skipping
        mov cx, 20h
        xor ax, ax ; setting al to zero
        mov bx, 10d
ConvertDecimalLoop:
        cmp ds:[si], cl
        je ConvertDecimalLoopEnd

        mul bx  ; ax *= 10d (actually dx:ax)

        xor dx, dx
        mov dl, byte ptr [si] ; moving number to register
        inc si
        sub dl, '0'
        add ax, dx
        jmp ConvertDecimalLoop

ConvertDecimalLoopEnd:
        ret
        endp


;------------------------------------------------
;Reads value in hex from memory ds:si and stores in ax
;Entry: ds:si - pointer to the string beginning
;       es = ds
;Exit : ax - readen value, 
;       si - points to the char after the string
;Destr: ax, cx, dx, di, si 
;------------------------------------------------   
MoveHexToRegister proc
        mov di, si
        call SkipSpaces

        mov si, di      ; moving to si str ptr after skipping

        mov cx, 20h        
        xor ax, ax ;setting al to zero
ConvertHexLoop:
        cmp ds:[si], cl
        je ConvertHexLoopEnd

        shl ax, 4       ; (*= 16)
        call MoveHexByteToRegister
        add ax, dx
        jmp ConvertHexLoop
        
ConvertHexLoopEnd:
        ret
        endp


;------------------------------------------------
;Reads one byte in hex from memory ds:si and stores in ax
;Entry: ds:si - pointer to the string beginning
;Exit : dx - readen byte, 
;       si - moves on one byte (si + 1)
;Destr: dx, si 
;------------------------------------------------   
MoveHexByteToRegister proc
        xor dx, dx
        mov dl, byte ptr [si]
        inc si

        sub dl, 'a'
        jge MoveHexByteToRegisterReturn
        add dl, 'a' - 'A'
        jge MoveHexByteToRegisterReturn
        add dl, 'A' - '0' - 10d
        ; -10d because of ('b' - 'a' = 1, so i add 10 before ret)
        ; however '2' - '0' = 2

        ; can handle some errors here (ex: byte not in range)

MoveHexByteToRegisterReturn:
        add dl, 10d
        ret
        endp


;------------------------------------------------
;Finds len of the string
;Entry: ES:DI - string begin pointer
;       AL    - string end char
;
;Exit: CX - length of the string
;Destr: DI, CX
;------------------------------------------------
StrLen proc
       xor cx, cx
       dec cx           ; setting cx = FFFF
       repne scasb
       not cx
       dec cx
       ret
       endp

;------------------------------------------------
;Skips chars while it's equal to al
;Entry: ES:DI - string begin pointer
;       AL    - char to skip
;
;Exit : DI - pointer after skipping
;Destr: DI, CX
;------------------------------------------------
SkipWhileChar proc
        xor cx, cx
        dec cx          ; setting cx = FFFF
        repe scasb
        dec di
        ret
        endp


;------------------------------------------------
;Skips spaces
;Entry: ES:DI - string begin pointer
;
;Exit : DI - pointer after skipping
;Destr: DI, AL, CX
;------------------------------------------------
SkipSpaces proc
        mov al, 20h
        call SkipWhileChar
        ret
        endp


;------------------------------------------------
;Reads frame params from command line
;Entry: ds:si - string begin ptr
;Exit : ah - frame color
;       bx - frame width
;       cx - frame height
;       ds:si - skips params
;Destr: ax, bx, cx, si
;------------------------------------------------
ReadFrameParams proc
        call MoveDecimalToRegister      ;reading width 
        push ax
        call MoveDecimalToRegister      ;reading height
        mov bx, ax
        call MoveHexToRegister          ;reading color
        shl ax, 8 ; putting from al to ah

        mov cx, bx
        pop bx

        ret
        endp



;------------------------------------------------
;
;Entry: ds:si - string begin ptr
;Exit : ds:dx - beginning of the 9-chars array with style
;       ds:si - ds:si + skips style chars
;Destr: dx, si, di, cx, al
;------------------------------------------------
ReadFrameStyle proc
        mov di, si
        call SkipSpaces
        mov si, di

        xor dx, dx
        mov dl, byte ptr [si]
        inc si
        cmp dl, '*'
        je CustomStyle

        ; not calling MoveDecimalToRegister because 
        ; this func destroys a lot of registers

        sub dx, '1'
        ;assuming that number is '1' <= dl <= '9'

        mov di, dx
        shl dx, 3
        add dx, di      ;dx * 8 + dx

        add dx, offset FrameChars
        ret

CustomStyle:
        mov dx, si
        add si, 9
        ret

        endp


;------------------------------------------------
;
;Entry: ds:si - string begin ptr,
;       bx    - frame width
;       cx    - frame height
;       es    - video mem
;
;Exit : ds:si - ptr to the end of the input string
;       es:di - ptr to the end of string output
;       cx    - frame height
;       bx    - frame width
;
;Destr: cx, ds:si, es:di, ax, dx, bx
;------------------------------------------------
PrintString proc
        call CenterFrame ; destroying dx
        shr cx, 1
        ;shr bx, 1 (useless right now)
        mov ax, cx
        mov cx, SCREEN_WIDTH * NUMBER_OF_BYTES_PER_CHAR 
        mul cx
        add di, ax

        push ax di es
        mov ax, ds
        mov es, ax
        mov di, si
        mov al, '$'
        call StrLen
        pop es di ax

        call CenterString

PrintStringLoop:
        cmp ds: byte ptr[si], '$'
        je PrintStringLoopEnd
        movsb
        inc di
        jmp PrintStringLoop

PrintStringLoopEnd:
        ret
        endp

;------------------------------------------------
;Calculating di to center string
;Entry: bx - frame width,
;       cx - string length
;       es:di - beginning of the screen line
;Exit : es:di - start-printing point
;Destr: di
;------------------------------------------------
CenterString proc
        push bx
        push cx

        and bx, -2    
        add di, bx      ; adding (bx / 2) * 2
        
        and cx, -2      
        sub di, cx      ; sub (cx / 2) * 2
        pop cx
        pop bx
        ret
        endp
        
FrameChars db 0c9h, 0cdh, 0bbh, 0bah, 20h, 0bah, 0c8h, 0cdh, 0bch,      \
                 3,    3,    3,    3, 20h,    3,    3,    3,    3      

