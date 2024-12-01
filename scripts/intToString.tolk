import "@stdlib/lisp-lists"

// func language = "fc";

fun intToString(n: int) {
    var string: builder = beginCell();
    var chars: tuple = null;
    do {
        var (b: int, r) = n.divMod(10);
        chars = listPrepend(r + 48, chars);
    } while (!(n == 0));
    do {
        var char: int = chars.listNext();
        string.storeUint(char, 8);
    } while (!(chars == null));
    return string.endCell().beginParse();
}

fun intToStringSlice(n: int): slice {
    var b = beginCell(); // Начинаем сборку строки
    var temp = beginCell();    // Временный Cell для переворота порядка цифр

    // Разбиваем число на цифры и записываем их в обратном порядке
    while (n > 0) {
        var digit = n % 10;            // Извлекаем последнюю цифру
        temp.storeUint(digit + 48, 8); // Преобразуем в ASCII-код и сохраняем
        n = n / 10;                    // Убираем обработанную цифру
    }

    // Переворачиваем порядок символов
    var s = temp.endCell().beginParse();
    while (!s.isEndOfSlice()) {
        var char = s.loadUint(8);
        b.storeUint(char, 8); // Записываем в итоговый Cell
    }

    val result = b.endCell().beginParse(); // Завершаем сборку строки\
    return result;
}
