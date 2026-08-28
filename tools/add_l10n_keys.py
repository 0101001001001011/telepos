#!/usr/bin/env python3
# Adds the new (session) UI keys to all intl_*.arb, preserving order/format.
import json, collections, io, os

ARB = "assets/i18n"
LANGS = ["ru", "en", "kk", "ky", "uz"]

# key -> {lang: value}; optional "_ph": [placeholders] for ICU @metadata (ru template).
KEYS = {
  "setPolicyEditProduct": {"ru":"Разрешить редактирование товаров","en":"Allow editing products","kk":"Тауарларды өңдеуге рұқсат","ky":"Товарларды түзөтүүгө уруксат","uz":"Mahsulotlarni tahrirlashga ruxsat"},
  "setPolicyEditProductDesc": {"ru":"Кассир может изменять карточки товаров в каталоге","en":"Cashier can edit product cards in the catalog","kk":"Кассир каталогтағы тауар карточкаларын өзгерте алады","ky":"Кассир каталогдогу товар карточкаларын өзгөртө алат","uz":"Kassir katalogdagi mahsulot kartalarini o'zgartira oladi"},
  "setPolicyEditPrice": {"ru":"Разрешить изменение цены в продаже","en":"Allow changing price during sale","kk":"Сатуда бағаны өзгертуге рұқсат","ky":"Сатууда бааны өзгөртүүгө уруксат","uz":"Sotuvda narxni o'zgartirishga ruxsat"},
  "setPolicyEditPriceDesc": {"ru":"Кассир может вручную менять цену позиции в чеке","en":"Cashier can manually change a line price on the receipt","kk":"Кассир чектегі позиция бағасын қолмен өзгерте алады","ky":"Кассир чектеги позициянын баасын кол менен өзгөртө алат","uz":"Kassir chekdagi pozitsiya narxini qo'lda o'zgartira oladi"},
  "setPolicyDiscounts": {"ru":"Разрешить скидки","en":"Allow discounts","kk":"Жеңілдіктерге рұқсат","ky":"Арзандатууларга уруксат","uz":"Chegirmalarga ruxsat"},
  "setPolicyDiscountsDesc": {"ru":"Кассир может применять скидки к позициям чека","en":"Cashier can apply discounts to receipt lines","kk":"Кассир чек позицияларына жеңілдік қолдана алады","ky":"Кассир чек позицияларына арзандатуу колдоно алат","uz":"Kassir chek pozitsiyalariga chegirma qo'llashi mumkin"},
  "setPolicyCashInOut": {"ru":"Разрешить внесение/изъятие наличных","en":"Allow cash in/out","kk":"Қолма-қол ақша салу/алуға рұқсат","ky":"Накталай киргизүү/чыгарууга уруксат","uz":"Naqd kirim/chiqimga ruxsat"},
  "setPolicyCashInOutDesc": {"ru":"Кассир может вносить и изымать наличные из кассы","en":"Cashier can deposit and withdraw cash from the till","kk":"Кассир кассадан ақша сала және ала алады","ky":"Кассир кассадан накталай сала жана ала алат","uz":"Kassir kassadan naqd pul kiritishi va olishi mumkin"},
  "setPolicyBigAmount": {"ru":"Разрешить крупные суммы (>1 млн)","en":"Allow large amounts (>1M)","kk":"Ірі сомаларға рұқсат (>1 млн)","ky":"Чоң суммаларга уруксат (>1 млн)","uz":"Katta summalarga ruxsat (>1 mln)"},
  "setPolicyBigAmountDesc": {"ru":"Снять ограничение в 1 000 000 на операции","en":"Lift the 1,000,000 cap on operations","kk":"Операциялардағы 1 000 000 шегін алып тастау","ky":"Операциялардагы 1 000 000 чегин алып салуу","uz":"Operatsiyalardagi 1 000 000 chegarasini olib tashlash"},
  "setPolicyBlockPriceDecrease": {"ru":"Запретить снижение цены ниже карточки","en":"Forbid lowering price below the card price","kk":"Бағаны карточкадан төмен түсіруге тыйым","ky":"Бааны карточкадан төмөн түшүрүүгө тыюу","uz":"Narxni karta narxidan past tushirishni taqiqlash"},
  "setPolicyBlockPriceDecreaseDesc": {"ru":"Цену в чеке нельзя установить ниже цены товара","en":"A receipt line price cannot be set below the product price","kk":"Чектегі бағаны тауар бағасынан төмен қоюға болмайды","ky":"Чектеги бааны товардын баасынан төмөн коюуга болбойт","uz":"Chekdagi narxni mahsulot narxidan past qo'yib bo'lmaydi"},
  "setPolicyRahmet": {"ru":"Разрешить оплату Rahmet QR","en":"Allow Rahmet QR payment","kk":"Rahmet QR төлеміне рұқсат","ky":"Rahmet QR төлөмүнө уруксат","uz":"Rahmet QR to'loviga ruxsat"},
  "setPolicyRahmetDesc": {"ru":"Показывать кнопку оплаты Rahmet QR на экране оплаты","en":"Show the Rahmet QR payment button on the payment screen","kk":"Төлем экранында Rahmet QR төлем түймесін көрсету","ky":"Төлөм экранында Rahmet QR төлөм баскычын көрсөтүү","uz":"To'lov ekranida Rahmet QR to'lov tugmasini ko'rsatish"},
  "printerAutoDetect": {"ru":"Найти принтер","en":"Find printer","kk":"Принтерді табу","ky":"Принтерди табуу","uz":"Printerni topish"},
  "printerAutoDetecting": {"ru":"Поиск принтера…","en":"Searching for printer…","kk":"Принтер ізделуде…","ky":"Принтер изделүүдө…","uz":"Printer qidirilmoqda…"},
  "printerFound": {"ru":"Найдено: {device}","en":"Found: {device}","kk":"Табылды: {device}","ky":"Табылды: {device}","uz":"Topildi: {device}","_ph":["device"]},
  "printerFoundWithNote": {"ru":"Найдено: {device} — {note}","en":"Found: {device} — {note}","kk":"Табылды: {device} — {note}","ky":"Табылды: {device} — {note}","uz":"Topildi: {device} — {note}","_ph":["device","note"]},
  "printerNotFoundAnyPort": {"ru":"Принтер не найден ни на одном порту (USB/serial). Проверьте кабель и питание.","en":"Printer not found on any port (USB/serial). Check the cable and power.","kk":"Принтер бірде-бір портта табылмады (USB/serial). Кабель мен қуатты тексеріңіз.","ky":"Принтер бир да портто табылган жок (USB/serial). Кабелди жана кубатты текшериңиз.","uz":"Printer hech bir portda topilmadi (USB/serial). Kabel va quvvatni tekshiring."},
  "printerUsbName": {"ru":"USB-принтер","en":"USB printer","kk":"USB-принтер","ky":"USB-принтер","uz":"USB printer"},
  "ownerOnlyTitle": {"ru":"Доступно только владельцу кассы","en":"Available to the till owner only","kk":"Тек касса иесіне қолжетімді","ky":"Бул касса ээсине гана жеткиликтүү","uz":"Faqat kassa egasiga ochiq"},
  "ownerOnlyDesc": {"ru":"Системные операции (перезагрузка, сброс, драйверы, терминал) доступны только под учётной записью владельца.","en":"System operations (reboot, reset, drivers, terminal) are available only under the owner account.","kk":"Жүйелік операциялар (қайта қосу, ысыру, драйверлер, терминал) тек иесінің тіркелгісінде қолжетімді.","ky":"Системалык операциялар (өчүрүп-күйгүзүү, баштапкы абалга келтирүү, драйверлер, терминал) ээсинин эсебинде гана жеткиликтүү.","uz":"Tizim operatsiyalari (qayta yuklash, qayta tiklash, drayverlar, terminal) faqat egasi hisobida ochiq."},
}

for lang in LANGS:
    path = os.path.join(ARB, f"intl_{lang}.arb")
    with io.open(path, encoding="utf-8") as f:
        data = json.load(f, object_pairs_hook=collections.OrderedDict)
    added = 0
    for key, vals in KEYS.items():
        if key in data:
            continue
        data[key] = vals[lang]
        added += 1
        # @metadata with placeholders only in the ru template.
        if lang == "ru" and "_ph" in vals:
            data["@" + key] = {"placeholders": {p: {"type": "String"} for p in vals["_ph"]}}
    with io.open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"{lang}: +{added}")
print("done")
