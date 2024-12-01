import "@stdlib/tvm-dicts"
import "@stdlib/lisp-lists"
import "../scripts/intToString.tolk"

const GET_BALANCE = "get_balance";
const WITHDRAW = "withdraw";
const DICT_KEY_LEN = 256;
const AMOUNT_LEN = 32;
const MIN_NIN_TON = 1000000000;

global transactions: cell;

fun loadData() {
    transactions = createEmptyDict();
    var ds: slice = getContractData().beginParse();
    if (!ds.isEndOfSlice()) {
        var dict: cell = ds.loadDict();
        if (!dict.dictIsEmpty()) {
            transactions = dict;
        }
    }
    ds.assertEndOfSlice();
}

fun saveData() {
    setContractData(
        beginCell()
        .storeDict(transactions)
        .endCell()
    );
}

fun saveTransaction(address: slice, amount: int): int {
    debugPrint(address);
    val timestamp = now();
    debugPrintString("getting last transaction");
    val (cs: cell, n: int) = transactions.sDictGetRef(DICT_KEY_LEN, address);
    debugPrintString("Got transaction");
    var oldAmount = 0;
    if (cs != null) {
        var cs2 = cs;
        oldAmount = cs2.beginParse().loadInt(32);
    }
    debugPrintString("Old amount");
    debugPrint(oldAmount);
    val newValue: int = amount + oldAmount;
    debugPrintString("Amount");
    debugPrint(newValue);
    try {
        transactions.sDictSetRef(DICT_KEY_LEN, address, beginCell().storeInt(newValue, 32).endCell());
    } catch (e) {
        debugPrint(e);
    }
    return timestamp;
}

fun getBalance(address: slice): int {
    debugPrintString("Getting balance");
    val (cs: cell, n: int) = transactions.sDictGetRef(DICT_KEY_LEN, address);
    var cs2 = cs;
    val balance = cs2.beginParse().loadInt(32);
    return balance;
}

fun sendMessageWithCoins(address: slice, amount: int, message: cell): int {
    val timestamp = now();
    sendRawMessage(
        beginCell()
        .storeUint(0x18, 6)
        .storeSlice(address)
        .storeCoins(amount)
        .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .storeUint(0, 32)
        .storeSlice(message.beginParse())
        .endCell(),
        SEND_MODE_PAY_FEES_SEPARATELY + SEND_MODE_IGNORE_ERRORS
    );
    if (amount > 0) {
        saveTransaction(address, -amount);
    }
    return timestamp;
}

fun onInternalMessageRouter(myBalance: int, msgValue: int, msgFull: cell, msgBody: slice) {

    debugPrintString("onInternalMessage");
    var cs: slice = msgFull.beginParse();
    val flags = cs.loadMessageFlags();
    val sender = cs.loadAddress();

    debugPrint(msgValue);

    saveTransaction(sender, msgValue);


    if (msgBody.isEndOfSlice()) { // ignore all empty messages
        debugPrintString("Exiting onInternalMessage");
        return;
    }

    val op = msgBody.loadMessageOp();

    debugPrintString("Preparing to save transaction");

    debugPrintString("Transaction saved");
    if (op == 0) {
        val commentHash = stringHash(msgBody);
        if (commentHash == stringHash(GET_BALANCE)) {
            debugPrintString("GET_BALANCE");
            val balance = getBalance(sender);
            debugPrint(balance);
            debugPrintString(intToStringSlice(balance));
            sendMessageWithCoins(sender, 0, beginCell().storeSlice(intToStringSlice(balance)).endCell());
        }
        if (commentHash == stringHash(WITHDRAW)) {
            debugPrintString("WITHDRAW");
            val balance: int = getBalance(sender);
            val amountToWithdraw: int = min(balance, myBalance) / 10 * 9;
            debugPrintString("Contract balance, amount to withdraw");
            debugPrint(myBalance);
            debugPrint(balance);
            debugPrint(amountToWithdraw);
            try {
                if (amountToWithdraw < 0) {
                    debugPrintString("Not enough balance");
                    sendMessageWithCoins(sender, 0, beginCell().storeSlice("Not enough balance").endCell());
                } else {
                    sendMessageWithCoins(sender, amountToWithdraw, beginCell().storeSlice("Withdrawal").endCell());
                }
            } catch (e) {
                debugPrint(e);
            }
        }
        debugPrintString("Message function finished");
        return;
    }
    throw 0xffff;
}

fun onInternalMessage(myBalance: int, msgValue: int, msgFull: cell, msgBody: slice) {
    loadData();
    onInternalMessageRouter(myBalance, msgValue, msgFull, msgBody);
    saveData();
}
