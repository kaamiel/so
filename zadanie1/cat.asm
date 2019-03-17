SYS_READ  equ 0
SYS_WRITE equ 1
SYS_OPEN  equ 2
SYS_CLOSE equ 3

O_RDONLY  equ 0

SYS_EXIT  equ 60
STDOUT    equ 1
BUFF_SIZE equ 4

; Wykonanie programu zaczyna się od etykiety _start.
global _start


section .rodata

error_msg db "Error!!!",10
new_line  db `\n`


section .bss

buffer    resb 4


section .text

_start:
    cmp     qword [rsp], 2  ; czy dokładnie jeden argument
    jnz     error           ; error jeśli nie

    lea     rbp, [rsp + 2 * 8]  ; adres args[1]
    mov     rsi, [rbp]

    mov     eax, SYS_OPEN   ; open file
    mov     rdi, rsi        ; open file
    mov     rsi, O_RDONLY   ; open file
    syscall                 ; open file
    mov     r12, rax        ; deskryptor w r12
    cmp     r12, 0
    js      error

loop:
    mov     eax, SYS_READ   ; read z pliku
    mov     rdi, r12        ; read z pliku
    mov     rsi, buffer     ; read z pliku
    mov     edx, BUFF_SIZE  ; read z pliku
    syscall                 ; read z pliku

    cmp     rax, 0
    js      error
    jz     end

    mov     eax, SYS_WRITE
    mov     edi, STDOUT
    mov     rsi, buffer
    mov     edx, BUFF_SIZE
    syscall

    ; mov     eax, SYS_WRITE
    ; mov     edi, STDOUT
    ; mov     rsi, new_line
    ; mov     edx, 1
    ; syscall

    jmp     loop

end:
    mov     eax, SYS_CLOSE  ; close file
    mov     rdi, r12        ; close file
    syscall                 ; close file

    jmp     noError

error:
    mov     eax, SYS_WRITE
    mov     edi, STDOUT
    mov     rsi, error_msg
    mov     edx, new_line - error_msg
    syscall

    mov     edi, 1
    jmp     exit

noError:
    xor     edi, edi        ; kod powrotu 0

exit:
    mov     eax, SYS_EXIT   ; exit syscall

    syscall