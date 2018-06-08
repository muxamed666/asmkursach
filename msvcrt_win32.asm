format PE CONSOLE

entry start

include "H:\DOWNLOADS\FASM\include\win32ax.inc"

section '.text' code executable

; Ввод stdin -> st0
macro input
{
        pusha                                   ; сохр. рег.
        push    floatbuffer                     ; указатель на буфер ввода
        push    floatformat                     ; указатель на формат "%f"
        call    [scanf]                         ; вызываем scanf
        pop     ecx                             ; очищаем стек
        pop     ecx                             ; очищаем стек
        fld     dword[floatbuffer]              ; загружаем значение в FPU
        xor     ecx,    ecx                     ; обнуляем ecx
        mov     dword[floatbuffer],     ecx     ; обнуляем буфер ввода
        popa                                    ; восст. рег
}

; Вывод st0 -> stdout
macro output
{
        pusha                                   ; сохр. рег.
        fst     qword[doublebuffer]             ; выталкиваем из st0 число
        push    dword[doublebuffer+4]           ; в 32-битном коде пушить 64-е
        push    dword[doublebuffer]             ;      число нужно в два этапа
        push    floatformat                     ; формат "%f"
        call    [printf]                        ; вызываем printf
        add     esp,    12                      ; сбрасываем стек
        popa                                    ; восст. регистры
}

; Вывод строки текста на экран
macro myPrintf str
{
        pusha
        push    str
        call    [printf]
        pop     ecx
        popa
}

; Функция f(x) = sqrt( (sin(x+3))^2 - 4 * ln(x))
macro func
{
        fild    dword[three]                    ; st0 = 3, st1 = x
        fxch    st1                             ; st0 = x, st1 = 3
        fld     st0                             ; st0 = x, st1 = x, st2 = 3
        fxch    st2                             ; st0 = 3, st1 = x, st2 = x
        faddp                                   ; st0 = x+3, st1 = x
        fsin                                    ; st0 = sin(x+3), st1 = x
        fmul    st0,    st0                     ; st0 = sin^2(x+3), st1 = x
        fxch    st1                             ; st0 = x, st1 = sin^2(x+3)
        fild    dword[four]                     ; st0 = 4, st1 = x, st2 = sin^2(x+3)
        fxch    st1                             ; st0 = x, st1 = 4, st2 = sin^2(x+3)
        fldln2                                  ; st0 = ln2, st1 = x, st2 = 4, st3 = sin^2(x+3)
        fxch    st1                             ; st0 = x, st1 = ln2, st2 = 4, st3 = sin^2(x+3)
        fyl2x                                   ; st0 = ln(x), st1 = 4, st2 = sin^2(x+3)
        fmulp                                   ; st0 = 4*ln(x), st1 = sin^2(x+3)
        fsubp                                   ; st0 = sin^2(x+3) - 4*ln(x)
        fsqrt                                   ; st0 = sqrt(sin^2(x+3) - 4*ln(x))
}

start:
finit

; вводим значения
myPrintf hello
myPrintf inpta
input
fstp    qword[aa]
myPrintf inptb
input
fstp    qword[bb]
myPrintf inptdx
input
fstp    qword[xx]

; выводим таблицу в цикле
line:
finit
myPrintf tab
fld     qword[aa]
output
myPrintf tab
func
output
myPrintf crlf
fld     qword[aa]
fld     qword[xx]
faddp
fst     qword[aa]
; сравниваем с b
fld     qword[bb]
fcom
fstsw   ax
sahf
ja      line


; ---- завершаемся
push 0
call [ExitProcess]


; ---- данные

section '.data' data readable writeable
hello db 'Vvedite chisla a, b, dx:', 10, 0
inpta db 'VVEDITE A = ', 0
inptb db 'VVEDITE B = ', 0
inptdx db 'VVEDITE DX = ', 0
floatformat db '%f', 0
floatbuffer dd 0
doublebuffer dq 0
three dd 3
four  dd 4
aa    dq 0
bb    dq 0
xx    dq 0
crlf  db 10,0
tab   db 09,0

; ---- библиотеки
section '.idata' data readable import
        library kernel32, 'kernel32.dll', msvcrt, 'msvcrt.dll'
        import kernel32, ExitProcess, 'ExitProcess'
        import msvcrt, printf, 'printf', scanf, 'scanf'
