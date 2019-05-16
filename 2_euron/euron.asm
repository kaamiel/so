
global euron
extern get_value, put_value

; adresy funkcji
section .data
align 16
fun dq \
multiply,\
plus,\
0,\
minus,\
0, 0,\
else, else, else, else, else,\
else, else, else, else, else,\
0, 0, 0, 0, 0, 0, 0, 0,\
branch,\
clean,\
duplicate,\
exchange,\
0,\
get,\
0, 0, 0, 0, 0, 0, 0, 0,\
put,\
0, 0,\
synchronize,\
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,\
n

section .bss
align 16
top resq N * (N - 1) / 2    ; miejsce na wymianę wierzchołków stosów
sem resw N * (N - 1) / 2    ; miejsce na spinlocki

section .text
align 16
plus:       ; '+', 43 – zdejmij dwie wartości ze stosu, oblicz ich sumę i wstaw wynik na stos;
    pop     r8
    add     [rsp], r8
    jmp     increase

multiply:   ; '*', 42 – zdejmij dwie wartości ze stosu, oblicz ich iloczyn i wstaw wynik na stos;
    pop     r8
    pop     r9
    imul    r8, r9
    push    r8
    jmp     increase

minus:      ; '-', 45 – zaneguj arytmetycznie wartość na wierzchołku stosu;
    neg     qword [rsp]
    jmp     increase

n:          ; 'n', 110 – wstaw na stos numer euronu;
    push    r12
    jmp     increase

branch:     ; 'B', 66 – zdejmij wartość ze stosu, jeśli teraz na wierzchołku stosu jest wartość
            ; różna od zera, potraktuj zdjętą wartość jako liczbę w kodzie
            ; uzupełnieniowym do dwójki i przesuń się o tyle operacji;
    pop     r8
    cmp     qword [rsp], 0
    je      increase
    add     r13, r8
    jmp     increase

clean:      ; 'C', 67 – zdejmij wartość ze stosu;
    add     rsp, 8
    jmp     increase

duplicate:  ; 'D', 68 – wstaw na stos wartość z wierzchołka stosu, czyli zduplikuj wartość na
            ; wierzchu stosu;
    push    qword [rsp]
    jmp     increase

exchange:   ; 'E', 69 – zamień miejscami dwie wartości na wierzchu stosu;
    pop     r8
    pop     r9
    push    r8
    push    r9
    jmp     increase

get:        ; 'G', 71 – wstaw na stos wartość uzyskaną z wywołania (zaimplementowanej gdzieś
            ; indziej w języku C) funkcji
            ; uint64_t get_value(uint64_t n);
    mov     rdi, r12    ; argument n dla funkcji get_value

    push    rbp         ; zapamiętaj rbp na stosie
    mov     rbp, rsp    ; zapamiętaj rsp w rbp
    and     rsp, -16    ; wyrównaj wskaźnik stosu przed wywołaniem funkcji
    call    get_value   ; wywołaj get_value
    mov     rsp, rbp    ; przywróć rsp
    pop     rbp         ; przywróć rbp

    push    rax         ; wynik funkcji get_value
    jmp     increase

put:        ; 'P', 80 – zdejmij wartość ze stosu (oznaczmy ją przez w) i wywołaj (zaimplementowaną
            ; gdzieś indziej w języku C) funkcję
            ; void put_value(uint64_t n, uint64_t w);
    mov     rdi, r12    ; argument n dla funkcji put_value
    pop     rsi         ; argument w dla funkcji put_value

    push    rbp         ; zapamiętaj rbp na stosie
    mov     rbp, rsp    ; zapamiętaj rsp w rbp
    and     rsp, -16    ; wyrównaj wskaźnik stosu przed wywołaniem funkcji
    call    put_value   ; wywołaj put_value
    mov     rsp, rbp    ; przywróć rsp
    pop     rbp         ; przywróć rbp

    jmp     increase

synchronize:    ; 'S', 83 – zdejmij wartość ze stosu, potraktuj ją jako numer euronu m, czekaj na
                ; operację 'S' euronu m ze zdjętym ze stosu numerem euronu n i zamień
                ; wartości na wierzchołkach stosów euronów m i n.
    pop     r8          ; zdejmij wartość ze stosu -- m w r8
    mov     r9, r12     ; n w r9
    cmp     r8, r9      ; czy m == n ?
    je      increase    ; tak, increase
    jb      ok          ; nie, m < n -- ok
    xchg    r8, r9      ; n < m, zamień -- min(m, n) w r8, max(m, n) w r9
ok:
    mov     rcx, r8     ; m
    imul    rcx, N      ; m * N
    add     rcx, r9     ; m * N + n

    mov     rdx, r8     ; m
    add     rdx, 3      ; m + 3
    imul    rdx, r8     ; m * (m + 3)
    add     rdx, 2      ; m * (m + 3) + 2 = (m + 1) * (m + 2)
    shr     rdx, 1      ; (m + 1) * (m + 2) / 2

    sub     rcx, rdx    ; m * N + n - (m + 1) * (m + 2) / 2 w rcx

    lea     r10, [top + 8 * rcx]    ; miejsce na wymianę wierzchołków stosów pary (m, n) w [r10]
    lea     rax, [sem + 2 * rcx]    ; spinlock pary (m, n) w [rax]
                                    ; pierwszy bajt na wzajemne wykluczanie (bit 0.) i flagę
                                    ; kolejności (bit 1.), drugi bajt na czekanie dwóch wątków

busy_wait:                  ; P(mutex)
    lock bts word [rax], 0
    jc      busy_wait

    lock bts word [rax], 1  ; czy jestem pierwszy:
    jc      snd             ; snd jeśli nie
                            ;     tak:
    pop     qword [r10]     ;         zapisz swój (pierwszego) wierzchołek stosu
    lock btr word [rax], 0  ;         V(mutex)
wait0:                      ;         czekaj na drugiego
    lock btr word [rax + 1], 0
    jnc     wait0
    push    qword [r10]     ;         skopiuj wierzchołek drugiego
    lock bts word [rax + 1], 1 ;      obudź drugiego

    jmp     increase

snd:                        ;     nie, jestem drugi (pierwszy już czeka):
    pop     r9
    push    qword [r10]     ;         skopiuj wierzchołek stosu pierwszego
    mov     qword [r10], r9 ;         zapisz swój (drugiego) wierzchołek stosu
    lock btr word [rax], 1  ;         zaznacz, że już nikt nie czeka
    lock btr word [rax], 0  ;         V(mutex)
    lock bts word [rax + 1], 0 ;      obudź pierwszego
wait1:                      ;         czekaj na wstanie pierwszego
    lock btr word [rax + 1], 1
    jnc     wait1

    jmp     increase

else:           ; '0' do '9', 48 do 57 – wstaw na stos odpowiednio liczbę 0 do 9;
    mov     al, byte [r13]
    sub     al, 48
    push    rax

    jmp increase



; uint64_t euron(uint64_t n, char const *prog);
euron:
    ; n w rdi
    ; prog w rsi
    push    r12         ; zapamiętaj r12 na stosie
    push    r13         ; zapamiętaj r13 na stosie
    push    rbp         ; zapamiętaj rbp na stosie
    mov     rbp, rsp    ; zapamiętaj rsp w rbp
    mov     r12, rdi    ; n w r12
    mov     r13, rsi    ; prog w r13
loop1:
    xor     rax, rax

    mov     al, byte [r13]  ; kolejny znak napisu wskazywanego przez prog
    lea     rsi, [fun + (eax - 42) * 8] ; funkcja kolejnego znaku
    xor     rax, rax
    jmp     [rsi]       ; skok do funkcji kolejnego znaku

increase:
    inc     r13         ; zwiększ wskaźnik prog
    cmp     byte [r13], 0   ; czy koniec napisu?
    jne     loop1       ; skocz do pętli jeśli nie

end:
    mov     rax, qword [rsp]    ; wynik funkcji euron (wierzchołek stosu)

    mov     rsp, rbp    ; przywróć rsp
    pop     rbp         ; przywróć rbp
    pop     r13         ; przywróć r13
    pop     r12         ; przywróć r12
    
    ret                 ; powrót
