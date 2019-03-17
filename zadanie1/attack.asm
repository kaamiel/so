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

    mov     rax, SYS_OPEN   ; open file
    mov     rdi, [rbp]      ; open file
    mov     rsi, O_RDONLY   ; open file
    syscall                 ; open file

    cmp rax, 0              ; check for errors on opening file
    jl error
    mov     rbx, rax        ; deskryptor w rbx
    xor     r12, r12

read:
    mov     rax, SYS_READ   ; read z pliku
    mov     rdi, rbx        ; read z pliku
    mov     rsi, buffer     ; read z pliku
    mov     rdx, BUFF_SIZE  ; read z pliku
    syscall                 ; read z pliku

    cmp     rax, 0
    jl      error
    jne     print

    mov     rax, SYS_CLOSE  ; close file
    mov     rdi, rbx        ; close file
    syscall                 ; close file

    cmp     rax, 0          ; check for errors
    jl      error           ; if less than zero, error
    jmp     noError

print:
    ; mov     rdx, rax
    ; mov     rax, SYS_WRITE
    ; mov     rdi, STDOUT
    ; mov     rsi, buffer
    ; syscall

    mov     eax, buffer
    bswap   eax
    add     r12, rax

    ; mov     rax, SYS_WRITE
    ; mov     rdi, STDOUT
    ; mov     rsi, new_line
    ; mov     rdx, 1
    ; syscall

    ; cmp     rax, 0          ; check for errors
    ; jl      error           ; if less than zero, error
    jmp     read

error:
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    mov     rsi, error_msg
    mov     rdx, new_line - error_msg
    syscall

    mov     rdi, 1
    jmp     exit

noError:
    xor     rdi, rdi        ; kod powrotu 0

exit:

    ; mov     rax, SYS_WRITE
    ; mov     rdi, STDOUT
    ; mov     rsi, new_line
    ; mov     rdx, 1
    ; syscall    

    mov     rax, SYS_EXIT   ; exit syscall
    syscall
