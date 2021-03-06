format ELF executable 3         ; Используется формат ELF 3  

jmp main                        ; Переходим сразу к началу

; -----------------------------------------------------------------------------
; Макрос для вывода строки на экран
; -----------------------------------------------------------------------------
macro printString strptr, size
{
    pusha                       ; Сохраняем все общие регистры в стек

    mov     eax,    4           ; eax номер системного вызова sys_write в Linux
    mov     ebx,    1           ; В ebx помещается адрес stdout = 1
    mov     ecx,    strptr      ; В регистр ecx помещается адрес строки
    mov     edx,    size        ; В edx помещается количество записываемых байт
    int     80h                 ; прерывание 0x80, системный вызов к ядру Linux

    popa                        ; Достаем регистры обратно
}


; -----------------------------------------------------------------------------
; Макрос для чтения в буффер ввода size символов
; -----------------------------------------------------------------------------
macro readStdinToBuffer
{
    pusha                       ; Сохраняем регистры в стек

    mov     eax,    3           ; eax номер системного вызова sys_read в Linux
    mov     ebx,    0           ; В ebx помещается адрес stdin = 0
    mov     ecx,    inputbuffer ; В регистр ecx помещается адрес буффера ввода
    mov     edx,    10          ; В edx помещается количество записываемых байт
    int     80h                 ; прерывание 0x80, системный вызов к ядру Linux

    popa                        ; возвращаем регистры из стека
}


; -----------------------------------------------------------------------------
; Процедура для ввода дробного числа с stdin-а
; Читает строку байтов с входного потока, преобразовывает ее в знаковое число с
; плавающей точкой. После выполнения число остается в регистре st0 блока FPU
; -----------------------------------------------------------------------------
readStdinToFPU:
    pusha                               ; Сохраняем регистры
    readStdinToBuffer                   ; Чтение в буффер inputbuffer

    ; знак числа, проверяем в начале есть ли знак "-"
    mov     ecx,        inputbuffer     ; Адрес буффера помещаем в ecx
    mov     edx,        1               ; Предполагаем что число положительное
    push    edx                         ; Заталкиваем знак в стек
    cmp     byte[ecx],  '-'             ; Сравниваем первый символ с '-'
    jne     positive                    ; Если это не '-' -> положительное
    pop     edx                         ; Если отрицательное то заменим 1 на -1
    mov     edx,        -1              ; число отрицательное
    push    edx                         ; Заталкиваем знак в стек
    add     ecx,        1               ; Смещаем адрес, чтобы '-' не мешал
    positive:                           ; Метка для положительного числа
    ; Теперь в стеке лежит знак числа, он пригодится позже

    ; Цикл по введеной строке
    xor     edx,        edx             ; Очищаем edx
    mov     edx,        0               ; Самодельный счетчик будет в edx

    iter1:                              ; Метка цикла
    cmp     edx,        10              ; Проверяем не было ли уже 10 байта
    je      continue                    ; Если было, то выходим из цикла

    add     ecx,        1               ; Добавляем к адресу в ecx единицу
    add     edx,        1               ; Добавляем к счетчику единицу

    cmp     byte[ecx],  0Ah             ; Ищем конец в строке ввода с консоли
    jne     iter1                       ; Если не конец то на новый шаг цикла
    continue:                           ; Метка для выхода с этого цикла
    ; Конец первого цикла


    sub     edx,        1
    ; Теперь edx содержит реальное количество байт в строке


    ; Обратный цикл по введеной строке
    mov     eax,        0               ; Мантисса
    mov     ebx,        1               ; Множитель разряда
    sub     ecx,        1               ; Адрес конца строки
    push    ebx                         ; 1 на случай если точка не найдена

    iter:                               ; Метка цикла
;   printString ecx,    1               ; Вывод 1 символа на экран

    cmp     byte[ecx],  '.'             ; Сравниваем с точкой
    jne     digit                       ; Если это не точка, значит это цифра
    add     esp,        4               ; Выкидываем из стека предыдущее знач.
    push    ebx                         ; Сохраняем в стеке теущий множитель 
    sub     ecx,        1               ; Вычитаем от адреса в ecx единицу
    sub     edx,        1               ; Вычитаем от счетчика единицу
    jmp     lastcheck                   ; И уходим сразу в конец цикла

    digit:                              ; Обрабатываем цифры
    cmp     byte[ecx],  '0'             ; Сравниваем с символом нуля
    jl      error                       ; Ошибка если меньше
    cmp     byte[ecx],  '9'             ; Ошибка если больше чем 9
    jg      error                       ; Теперь в ecx точно цифра в коде ascii

    push    edx                         ; Заталкиваем edx в стек на время
    mov     dl,         byte[ecx]       ; помещаем в edx байт из строки
    sub     edx,        '0'             ; в edx теперь текущая цифра
    push    eax                         ; Заталкиваем eax
    mov     eax,        ebx             ; Сбрасываем ebx в eax
    mul     edx                         ; в edx:eax разряд числа в 10-й СС
    mov     edx,        eax             ; eax -> edx
    pop     eax                         ; Возвращаем eax обратно
    add     eax,        edx             ; Добавляем в eax еще один разряд
    pop     edx                         ; Возвращаем edx обратно

    sub     ecx,        1               ; Вычитаем от адреса в ecx единицу
    sub     edx,        1               ; Вычитаем от счетчика единицу
    push    eax                         ; Сохраняем eax
    push    edx                         ; Сохраняем edx
    mov     eax,        10              ; Записываем 10 в eax
    mul     ebx                         ; Умножаем на 10, результат в edx:eax
    mov     ebx,        eax             ; eax -> ebx
    pop     edx                         ; Выталкиваем edx 
    pop     eax                         ; Выталкиваем eax 

    lastcheck:
    cmp     edx,        -1              ; Ищем конец в строке ввода с консоли
    jne     iter                        ; Если не конец то на новый шаг цикла
    ; Конец цикла

    ; Достаем сохраненные числа из стека
    pop     ebx                         ; делитель из стека в ebx
    pop     ecx                         ; знак из стека в ecx

    ; На данный момент в eax лежит мантисса а в ebx делитель, в ecx знак 
    ; Записываем число в формат чисел с плавающей точкой
    xor     edx,        edx             ; Очищаем edx
    mov     dword[mant],eax             ; fild не читает из регистров, поэтому
    mov     dword[decm],ebx             ; скидываем eax, ebx и ecx в память
    mov     dword[sign],ecx             ; ecx -> sign
    fild    dword[sign]                 ; знак в st2
    fild    dword[decm]                 ; делитель в st1
    fild    dword[mant]                 ; мантисса в st0 выталкивая остальное 
    fdiv    st0,        st1             ; Делим: st0 = st0 / st1
    fmul    st0,        st2             ; Умножаем: st0 = st0 * st2
    
    ; В результате на вершине стека, в st0 остается введеное в stdin число
    popa
    ret                                 ; Выходим из процедуры


; -----------------------------------------------------------------------------
; Процедура, вычисляет значение функции. Аругмент ожидается в регистре st0
; После выполнения ответ остается в регистре st0 блока FPU;
; -----------------------------------------------------------------------------
func:   
    fild    dword[three]                ; st0 = 3, st1 = x
    fxch    st1                         ; st0 = x, st1 = 3
    fmul    st0,        st0             ; st0 = x^2, st1 = 3 
    fld     st0                         ; st0 = x^2, st1 = x^2, st2 = 3
    fxch    st2                         ; st0 = 3, st1 = x^2, st2 = x^2
    fxch    st1                         ; st0 = x^2, st1 = 3, st2 = x^2     
    faddp   st1,        st0             ; st0 = x^2 + 3, st1 = x^2
    fldln2                              ; st0 = ln2, st1 = x^2+3, st2=x^2
    fxch    st1                         ; st0 = x^2 + 3, st1 = ln(2), st2 = x^2
    fyl2x                               ; st0 = ln(x^2+3), st1 = x^2
    fsubp                               ; st0 = x^2 - ln(x^2+3)
    fsqrt                               ; st0 = sqrt(x^2 - ln(x^2+3))
     
    ret


; -----------------------------------------------------------------------------
; Процедура для вывода дробного числа из st0 в stdout 
; После выполнения число остается в регистре st0 блока FPU
; -----------------------------------------------------------------------------
writeFPUst0ToStdout:
    ; Заталкиваем регистры в стек и сохраняем исходное число 
    pusha                               ; сохраняем стек 
    fst     qword[backup]               ; делаем бэкап

    ; Для начала проверим, нет ли в st0 значения NaN и -INF 
    fxam                                ; При NaN уст. CF и не уст. PF, ZF
    fstsw   ax                          ; Копируем флаги FPU в регистр eax
    sahf                                ; загружаем флаги из eax (для джампа)
    jnc     normalFloat                 ; Если там не NAN и не INF 
    printString nanorinf, 10            ; Выводим строку "NaN or INF"           
    jmp procEnd                         ; И прекращаем

    normalFloat:
    ; Вывод из FPU в stdout 
    ; Выводим в stdout знак '-' если число отрицательное
    ftst                                ; Сравниваем st0 с нулем 
    fstsw   ax                          ; Копируем флаги FPU в регистр eax
    sahf                                ; загружаем флаги из eax (для джампа)
    jnc     fpositive                   ; Переход
    mov     dword[dig], '-'             ; '-' -> dig
    printString dig,    1               ; выводим символ в stdout
    fchs                                ; Меняем знак числа в st0

    fpositive:
    ; Пытаемся вывести число из st0 в stdout
    fld1                                ; Добавляем в стек 1
    fld     st1                         ; Снова на вершину стека дробное число
    fprem                               ; Остаток от деления на 1, дробная часть
    fsub    st2,        st0             ; Вычитанием получаем целую часть
    fxch    st2                         ; Переставляем st2 и st0 местами

    ; Теперь в st0 лежит целая часть числа. Следующий цикл пушит ее в стек
    ; В ten заранее записано 10 чтобы удобно делить и умножать
    xor     ecx,        ecx             ; обнуляем счетчик цифр
    xor     eax,        eax             ; тут будут храниться флаги FPU 
    integr:
    fidiv   dword[ten]                  ; Делим st0 на 10
    fxch    st1                         ; Меняем местами st0 и st1
    fld     st1                         ; Еще раз добавляем целую часть 
    fprem                               ; Отделяем дробную часть от нее 
    fsub    st2,        st0             ; Вычитанием получаем целую часть
    fimul   dword[ten]                  ; Умножаем на 10 чтобы получить цифру
    fistp   dword[dig]                  ; В dig последняя цифра (из st0) 
    add     ecx,        1               ; Увеличиваем счетчик цифр 
    push    dword[dig]                  ; Пушим в стек цифру 
    fxch    st1                         ; Следующий разряд на вершину
    ; Это нужно повторять пока от целой части не останется 0
    ftst                                ; Сравниваем st0 с нулем 
    fstsw   ax                          ; Копируем флаги FPU в регистр eax
    sahf                                ; загружаем флаги из eax (для джампа)
    jnz     integr                      ; Если st0 еще не 0 то опять цикл 

    ; теперь в стеке по цифрам лежит целая часть числа, а в ecx количество цифр
    ; выводим это на консоль 

    integrOut:
    xor     edx,        edx             ; Обнуляем edx для текущего символа
    pop     edx                         ; Вытаскиваем цифру из стека
    add     edx,        '0'             ; цифра -> ascii символ
    mov     dword[dig], edx             ; edx -> dig
    printString dig,    1               ; выводим символ в stdout
    loop    integrOut                   ; цикл, в ecx счетчик

    ; Теперь нужно вывести дробную часть если она имеется
    ; Проверяем существует ли дробная часть числа 
    fstp    st0                         ; Выталкиваем st0 из стека 
    fxch    st1                         ; Ставим на вершину дробную часть
    ftst                                ; Сравниваем ее с нулем 
    fstsw   ax                          ; Копируем флаги FPU в eax 
    sahf                                ; Загружаем флаги из eax 
    jz      floatEnd                    ; Заканчиваем если st0 = 0

    ; Тут известно что дробная часть существует. Нужно вывести точку
    mov     dword[dig], '.'             ; '.' -> dig
    printString dig,    1               ; выводим символ в stdout

    ; Теперь нужно вывести саму дробную часть через умножение на 10
    ; Не более 5 символов после точки 

    mov     ecx,        4               ; Ограничение для цикла
    floatOut:
    fimul   dword[ten]                  ; Умножаем st0 на 10
    fxch    st1                         ; st0 <-> st1
    fld     st1                         ; Скопируем дробную часть на вершину 
    fprem                               ; Отделяем дробную часть
    fsub    st2,        st0             ; Вычитаем, получаем цифру целой
    fxch    st2                         ; Ставим цифру на вершину st0
    fistp   dword[dig]                  ; Выталкиваем ее в dig
    add     dword[dig], '0'             ; цифра -> ascii символ
    printString dig,    1               ; Выводим в stdout 
    ; Это нужно повторять пока от дробной части числа не останется 0
    fxch    st1                         ; дробная часть -> st0
    ftst                                ; Сравниваем с нулем 
    fstsw   ax                          ; Копируем флаги FPU в регистр eax
    sahf                                ; загружаем флаги из eax (для джампа)
    loopnz  floatOut                    ; ecx=0 или st0=0

    floatEnd:

    fstp    st0                         ; Очистить st0
    fstp    st0                         ; Очистить st0 

    procEnd:

    ; Теперь в stdout вывелось число из st0
    ; Восстанавливаем стек и st0
    fld     qword[backup]               ; Загружаем бэкап
    popa

    ret                                 ; Выход из процедуры


; -----------------------------------------------------------------------------
; Начало
; -----------------------------------------------------------------------------
main:

finit                               ; Инициализируем математический сопроцессор 
fclex                               ; Обнуляем флаги исключений сопроцессора

printString well1, 24               ; Вывод приглашения ко вводу на экран
printString wella, 4                ; Вывод приглашения ко вводу на экран
call    readStdinToFPU              ; Считываем число
fstp    qword[storage_a]            ; Выталкиваем его в память
printString wellb, 4                ; Вывод приглашения ко вводу на экран
call    readStdinToFPU              ; Считываем число
fstp    qword[storage_b]            ; Выталкиваем его в память
printString welldx, 5               ; Вывод приглашения ко вводу на экран
call    readStdinToFPU              ; Считываем число
fstp    qword[storage_dx]           ; Выталкиваем его в память


printString tableheader, 15         ; Выводим заголовок тблицы 

; Правильно ли задали промежуток
finit
fld     qword[storage_b]            ; пушим b
fld     qword[storage_a]            ; пушим a
fcom                                ; сравниваем st0 и st1
fstsw   ax                          ; Копируем флаги FPU в регистр eax
sahf                                ; загружаем флаги из eax (для джампа)
ja      finally                     ; выходим из цикла


tabline:
printString tab, 1                  ; Выводим acsii код табуляции на экран
finit                               ; Переинициализируем FPU
; Это нужно чтобы дропнуть сразу весь его стек, иначе дальше будет overflow 
fld     qword[storage_a]            ; Кладем x = a в st0
call    writeFPUst0ToStdout         ; Выводим st0 на экран 
printString tab, 1                  ; Выводим acsii код табуляции на экран
call    func                        ; Рассчитываем значение y(x) и кладем в st0 
call    writeFPUst0ToStdout         ; Выводим st0 на экран 
printString linefeed, 1             ; Переводим курсор на новую строку  

fld     qword[storage_a]            ; A из памяти в st0
fld     qword[storage_dx]           ; st0 = dx, st1 = a
faddp   st1,        st0             ; st0 = a + dx
fst     qword[storage_a]            ; Копируем его также в память 
;сравниваем с b
fld     qword[storage_b]            ; st0 = b, st1 = a + dx
fsubp   st1,        st0             ; st0 = ((a + dx)-b) 
fld1                                ; st0 = 1.0, st1 = ((a + dx)-b)
fild    dword[precision]            ; st0 = 10000000, st1 = 1, st2 =((a+dx)-b)
fdivp   st1,        st0             ; st0 = 0.0000001, st1 = ((a + dx)-b) 
fxch    st1                         ; st0 = ((a + dx)-b), st1 = 0.0000001
fcom                                ; сравниваем st0 и st1
fstsw   ax                          ; Копируем флаги FPU в регистр eax
sahf                                ; загружаем флаги из eax (для джампа)
ja      finally                     ; выходим из цикла если st0 больше
jmp     tabline                     ; снова выводим строку таблицы

;writeFPUst0ToStdout                ; Выводим число

finally:


; -----------------------------------------------------------------------------
; Завершение работы программы
; -----------------------------------------------------------------------------
printString byebye, 7       ; Сюда удобно breakpoint ставить 
mov     eax,        1       ; В eax номер системного вызова sys_exit в Linux
mov     ebx,        0       ; В ebx возвращаемое программой значение при выходе
int     80h                 ; прерывание 0x80, системный вызов к ядру Linux
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; Завершение работы c сообщением об ошибке
; -----------------------------------------------------------------------------
error:
printString errorstring, 47 ; Выводим сообщение об ошибке
mov     eax,        1       ; В eax номер системного вызова sys_exit в Linux
mov     ebx,        3       ; Возвращаем ненулевое значение так как ошибка
int     80h                 ; прерывание 0x80, системный вызов к ядру Linux

; -----------------------------------------------------------------------------
; Задаем переменные, строки и другие данные.
; -----------------------------------------------------------------------------
inputbuffer db 10 dup(?)
well1 db "Enter a, b, dx values: ", 0ah
wella db "a = ", 0ah
wellb db "b = ", 0ah
welldx db "dx = ", 0ah
tableheader db 0ah, 09h, "x = ", 09h, "y(x) = ", 0ah
byebye db 0Ah,"Done.", 0ah
errorstring db "Error occured, check input data, then restart.", 0ah
tab db 09h
linefeed db 0ah
nanorinf db "NaN or INF"
mant dd ?
decm dd ?
sign dd ?
ten dd 10
three dd 3
precision dd 10000000
dig dd ?
backup dq ?
storage_a dq ?
storage_b dq ?
storage_dx dq ?
