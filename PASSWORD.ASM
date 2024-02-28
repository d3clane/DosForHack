.model tiny
.code
.286

org 100h

HASH_MULTIPLIER equ 43d

Start:
    call ReadPassword

    call CheckPassword

    mov ax, 4c00h
    int 21h         ; terminating program


;------------------------------------------------
;Checks password on correctness 
;Entry: ax - hash
;Destr: ax, bx, cx, dx, di, si, es
;------------------------------------------------
CheckPassword proc
    cmp ds: word ptr [82h], '87'    ; checking for admin rights
    jne PassCheck
    mov ax, word ptr CORRECT_PASS_HASH

PassCheck:
    cmp ax, word ptr CORRECT_PASS_HASH
    jne PassDeny

    mov si, offset SUCCESS_FRAME
    jmp PassCheckEnd

PassDeny:
    mov si, offset DENY_FRAME

PassCheckEnd:
    call PrintFrame
    ret
    endp

;------------------------------------------------
;Reads password, saves in PASS_BUF and calculates hash in ax
;Entry: None
;Exit : ax - hash, PASS_BUF - saved password
;Destr: ax, bx, cx, dx, di, si
;------------------------------------------------
ReadPassword proc
    cld 
    xor bx, bx
    xor cx, cx

    mov si, HASH_MULTIPLIER
    mov di, offset PASS_BUF
InputLoop:
    cmp word ptr LOOP_COUNTER, 0
    je EndInput

    mov ah, 06h
    mov dl, 0ffh
    int 21h         ; stdin input using 21h
    jz InputLoop    ; no input -> loop

    xor ah, ah

    cmp al, '$'    ; '$' symbol = end
    je EndInput

    stosb
    mov bx, ax  ; saving ax
    mov ax, cx  ; moving prev counted hash to ax
    mul si      ; *= 43
    add ax, bx  ; pref[i - 1] * 43 + a[i]
    mov cx, ax  ; saving ax in cx

    dec word ptr LOOP_COUNTER
    jmp InputLoop

EndInput:   
    mov ax, cx

    ret
    endp

include frame.asm

SUCCESS_FRAME db '40 15 7a 1 permission success$'
DENY_FRAME    db '40 15 40 1 permission denied$'

CORRECT_PASS_HASH dw 63231d
PASS_BUF          db '000000000000000$'
LOOP_COUNTER      dw 20d

end Start