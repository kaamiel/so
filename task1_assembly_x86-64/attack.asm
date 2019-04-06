SYS_READ  equ 0
SYS_OPEN  equ 2
SYS_CLOSE equ 3
SYS_EXIT  equ 60
O_RDONLY  equ 0
BUFF_SIZE equ 4096

; Wykonanie programu zaczyna się od etykiety _start.
global _start


section .rodata             ; zmienne globalne tylko do odczytu

array dd 6, 8, 0, 2, 0      ; sekwencja liczb, która ma być w pliku


section .bss                ; zmienne globalne inicjowane zerami

buffer    resb BUFF_SIZE    ; bufor o rozmiarze BUFF_SIZE bajtów
fd        resb 1            ; miejsce na deskryptor pliku


; makro do czytania z pliku, 0 parametrów
%macro read_macro 0
    xor     rax, rax        ; ile bajtów ostatnio przeczytano, na początku 0
    xor     r12, r12        ; ile w sumie przeczytano, na początku 0
%%begin:
    lea     rsi, [buffer + r12] ; bufor
    mov     rdx, BUFF_SIZE  ; ile bajtów przeczytać
    sub     rdx, r12        ; tyle już przeczytano
    mov     eax, SYS_READ   ; czytanie z pliku
    mov     edi, [fd]       ; deskryptor pliku
    syscall                 ; sys_read syscall

    add     r12, rax        ; aktualizacja sumy przeczytanych bajtów

    cmp     rax, 0          ; czy czytanie z pliku się powiodło
    jl      error           ; error jeśli nie -- sys_read zwrócił ujemną liczbę
    je      close           ; close jeśli przeczytano 0 bajtów

    cmp     r12, BUFF_SIZE  ; czy przeczytano BUFF_SIZE bajtów
    jl      %%begin         ; begin jeśli nie
%endmacro


section .text               ; kod wykonywalny

_start:
    cmp     qword [rsp], 2  ; czy dokładnie jeden argument
    jnz     error           ; error jeśli nie

    lea     rbp, [rsp + 16] ; adres argv[1], czyli nazwa pliku wejściowego

    mov     eax, SYS_OPEN   ; otwarcie pliku
    mov     rdi, [rbp]      ; nazwa pliku wejściowego
    mov     esi, O_RDONLY   ; flaga, tylko do odczytu
    syscall                 ; sys_open syscall

    cmp     rax, 0          ; czy otwarcie pliku się powiodło
    jl      error           ; error jeśli nie -- sys_open zwrócił ujemną liczbę

    mov     [fd], rax       ; deskryptor pliku wejściowego w [fd]
    xor     ebx, ebx        ; suma wczytanych liczb w ebx, na początku 0
    xor     r14d, r14d      ; flagi w r14d, na początku 0
    xor     r15d, r15d      ; aktualny indeks w tablicy array, na początku 0

read:
    read_macro
    jmp     calc            ; nie zamykamy pliku skoro nie skończyliśmy czytać

close:
    mov     eax, SYS_CLOSE  ; zamknięcie pliku
    mov     edi, [fd]       ; deskryptor
    syscall                 ; sys_close syscall

    cmp     rax, 0          ; czy zamknięcie pliku się powiodło
    jl      error           ; error jeśli nie -- sys_close zwrócił ujemną liczbę

    test    r12, 3          ; czy plik ma dobrą długość
    jnz     error           ; error jeśli nie

    bts     r14d, 2         ; ustaw we fladze bit nr 2 -- koniec pliku

calc:
    xor     rsi, rsi        ; numer liczby w buforze, na początku 0
loop:                       ; pętla po buforze
    mov     eax, [buffer + rsi] ; aktualna liczba
    bswap   eax             ; zamiana na cienkokońcówkowość
    add     ebx, eax        ; aktualizacja sumy wczytanych liczb

    cmp     eax, 68020      ; czy plik zawiera liczbę 68020
    je      error           ; error jeśli tak
    ja      else_noFlag
; noFlag:                   ; to nie jest liczba większa od 68020 i mniejsza od 2^31
    bt      r14d, 1         ; czy była już sekwencja 6, 8, 0, 2, 0
    jc      continue        ; tak, continue
    lea     rdx, [array + 4 * r15d]
    cmp     eax, [rdx]      ; czy kolejna z sekwencji 6, 8, 0, 2, 0
    jne     else_increase   ; nie, else
; increase:                 ; tak, kolejna z sekwencji 6, 8, 0, 2, 0
    inc     r15d            ; zwiększ aktualny indeks tablicy array
    cmp     r15d, 5         ; czy plik zawiera całą sekwencję 6, 8, 0, 2, 0
    jne     continue        ; nope, continue
; flag1:                    ; tak, plik zawiera całą sekwencję 6, 8, 0, 2, 0
    bts     r14d, 1         ; ustaw we fladze bit nr 1 -- plik zawiera sekwencję 6, 8, 0, 2, 0
; else_flag1:
    jmp     continue
else_increase:
    cmp     eax, 6          ; czy pierwszy element sekwencji 6, 8, 0, 2, 0
    jne     else_set1       ; nie, to nie jest 6
; set1:                     ; tak, pierwszy element sekwencji 6, 8, 0, 2, 0
    mov     r15d, 1         ; ustaw aktualny indeks tablicy array na 1
    jmp     continue
else_set1:                  ; nie, szukaj sekwencji od początku
    xor     r15d, r15d      ; ustaw aktualny indeks tablicy array na 0
    jmp     continue
else_noFlag:
    xor     r15d, r15d      ; szukaj sekwencji 6, 8, 0, 2, 0 od początku
    bt      r14d, 0         ; czy była już liczba większa od 68020 i mniejsza od 2^31
    jc      continue        ; tak, continue
    cmp     eax, 0x80000000 ; czy to jest liczba większa od 68020 i mniejsza od 2^31
    jae     continue        ; nie, continue
; flag0:                    ; tak, to jest liczba większa od 68020 i mniejsza od 2^31
    bts     r14d, 0         ; ustaw we fladze bit nr 0 -- plik zawiera liczbę większą od 68020 i mniejszą od 2^31
; else_flag0:
continue:
    add     rsi, 4          ; kolejna liczba z buforu
    cmp     rsi, r12        ; czy koniec buforu
    jl      loop            ; nie, jest kolejna
    bt      r14d, 2         ; czy jest co czytać
    jnc     read            ; jest, czytaj dalej

end:
    cmp     ebx, 68020      ; czy suma liczb w pliku modulo 2^32 jest równa 68020
    jne     error           ; error jeśli nie
    bt      r14d, 0         ; czy plik zawiera liczbę większą od 68020 i mniejszą od 2^31
    jnc     error           ; error jeśli nie
    bt      r14d, 1         ; czy plik zawiera sekwencję 6, 8, 0, 2, 0
    jnc     error           ; error jeśli nie
    xor     edi, edi        ; wszystko ok, kod powrotu 0
    jmp     exit

error:
    mov     edi, 1          ; kod powrotu 1

exit:
    mov     eax, SYS_EXIT   ; exit
    syscall                 ; sys_exit syscall
