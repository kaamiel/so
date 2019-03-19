SYS_READ  equ 0
SYS_WRITE equ 1
SYS_OPEN  equ 2
SYS_CLOSE equ 3
SYS_EXIT  equ 60
STDOUT    equ 1
O_RDONLY  equ 0
BUFF_SIZE equ 4

; Wykonanie programu zaczyna się od etykiety _start.
global _start


section .rodata             ; zmienne globalne tylko do odczytu

array dd 6, 8, 0, 2, 0
error_msg db "Error!!!", 10
new_line  db `\n`


section .bss                ; zmienne globalne inicjowane zerami

buffer    resb 4            ; 4-bajtowy bufor

section .text               ; kod wykonywalny

_start:
    cmp     qword [rsp], 2  ; czy dokładnie jeden argument
    jnz     error           ; error jeśli nie

    lea     rbp, [rsp + 16] ; adres argv[1], czyli nazwa pliku wejściowego

    mov     rax, SYS_OPEN   ; otwarcie pliku
    mov     rdi, [rbp]      ; nazwa pliku wejściowego
    mov     rsi, O_RDONLY   ; flaga, tylko do odczytu
    syscall                 ; open syscall

    cmp     rax, 0          ; czy otwarcie pliku się powiodło
    jl      error           ; error jeśli nie

    mov     r12, rax        ; deskryptor pliku wejściowego w r12
    xor     ebx, ebx        ; suma wczytanych liczb w ebx
    xor     r14d, r14d      ; flagi w r14d
    xor     r15d, r15d      ; aktualny indeks tablicy array

    xor     rax, rax
read:
    lea     rsi, [buffer + rax] ; bufor
    mov     r13, rax        ; ile bajtów już przeczytano
    mov     rdx, BUFF_SIZE  ; ile bajtów przeczytać
    sub     rdx, r13        ; tyle już przeczytano
    mov     rax, SYS_READ   ; czytanie z pliku
    mov     rdi, r12        ; deskryptor
    syscall                 ; read syscall

    cmp     rax, 0          ; czy czytanie z pliku się powiodło
    jl      error           ; error jeśli nie
    je      close           ; zamknięcie pliku, jeśli przeczytano 0 bajtów

    cmp     rax, BUFF_SIZE  ; czy przeczytano BUFF_SIZE bajtów
    je      calc            ; calc jeśli tak
    jmp     read            ; read jeśli nie

close:
    mov     rax, SYS_CLOSE  ; zamknięcie pliku
    mov     rdi, r12        ; deskryptor
    syscall                 ; close syscall

    cmp     r13, 0          ; czy plik ma dobrą długość
    jne     error           ; error jeśli nie

    cmp     ebx, 68020      ; czy suma liczb w pliku modulo 2^32 jest równa 68020
    jne     error           ; error jeśli nie

    cmp     rax, 0          ; czy zamknięcie pliku się powiodło
    jl      error           ; error jeśli nie
    jmp     noError         ; noError jeśli tak

calc:
    ;mov rbp, rsp; for correct debugging
    ; mov     rax, SYS_WRITE
    ; mov     rdi, STDOUT
    ; mov     rsi, buffer
    ; mov     rdx, BUFF_SIZE
    ; syscall

    mov     eax, [buffer]
    bswap   eax             ; zamiana na cienkokońcówkowość
    add     ebx, eax        ; aktualizacja sumy

    cmp     eax, 68020
    je      error           ; plik zawiera liczbę 68020
    jb      continue

    cmp     eax, 0x80000000
    jbe     number
    ; mov     rax, SYS_WRITE
    ; mov     rdi, STDOUT
    ; mov     rsi, new_line
    ; mov     rdx, 1
    ; syscall

    ; cmp     rax, 0          ; check for errors
    ; jl      error           ; if less than zero, error

continue:
    lea     rsi, [array + 4 * r15d]
    cmp     eax, [rsi]
    je      next
    cmp     eax, 6
    je      next2
    jne     next3
cont2:
    xor     rax, rax
    jmp     read
next:
    inc     r15d
    cmp     r15d, 5
    je      number2
    jmp     cont2
next2:
    mov     r15d, 1
    jmp     cont2
next3: 
    xor     r15d, r15d
    jmp     cont2
number2:
    bts     r14d, 1
    xor     rax, rax
    jmp     read
number:
    bts     r14d, 0
    xor     rax, rax
    jmp     read

error:
    ; mov     rax, SYS_WRITE
    ; mov     rdi, STDOUT
    ; mov     rsi, error_msg
    ; mov     rdx, new_line - error_msg
    ; syscall

    mov     rdi, 1          ; kod powrotu 1
    jmp     exit            ; exit

noError:
    mov     rdi, 1
    bts     r14d, 0
    jnc     exit
    bts     r14d, 1
    jnc     exit
    xor     rdi, rdi        ; kod powrotu 0

exit:
    mov     rax, SYS_EXIT   ; exit
    syscall                 ; exit syscall
