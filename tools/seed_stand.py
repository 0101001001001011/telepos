#!/usr/bin/env python3
"""Засев стенда провода (`test/manual/wt_stand.dart`) для живой приёмки продажи.

Касса, товары, кассиры, смена, покупатели с авансом и бонусами, сертификаты
(с ПИНом и без), фискальный оператор-эмулятор, провайдер QR-эмулятор.
Перенесён из разового скрипта второго стенда (2026-09-13), чтобы каждый стенд
не засевался заново руками.

Почему Python, а не curl: mingw-curl в Git Bash портит кириллицу доводов —
имя кассы и товаров доезжало до стенда мусором.

Запуск (стенд уже поднят, порт управления — его `TELEPOS_STAND_CONTROL`):

    TELEPOS_STAND_QR_KEY=... python tools/seed_stand.py --control 18401 \
        --fiscal-url http://127.0.0.1:18402 --qr-url http://127.0.0.1:18403

Ключ провайдера QR берётся **только из переменной окружения**
`TELEPOS_STAND_QR_KEY` — в файле и в командной строке его нет (командная
строка видна в списке процессов). Без переменной провайдер заводится без
ключа. Без `--qr-url` провайдер не заводится вовсе, без `--fiscal-url` —
фискальный оператор.

Скрипт останавливается на первом отказе двери и проверяет, что ключ
провайдера не вернулся ни в одном ответе.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

QR_KEY_ENV = "TELEPOS_STAND_QR_KEY"

PRODUCTS = [
    (101, 4870000000101, "Молоко 3.2%", "450"),
    (102, 4870000000102, "Хлеб белый", "250"),
    (103, 4870000000103, "Кофе молотый", "3200"),
    (104, 4870000000104, "Наушники", "7900"),
    (105, 4870000000105, "Сыр твёрдый", "1850"),
]

CUSTOMERS = [
    ("77011234567", "Покупатель С Авансом", "700", "0"),
    ("77017654321", "Покупатель С Бонусами", "0", "1500"),
]

# (номер, номинал, ПИН или None). С ПИНом — для проверки замка перебора и
# фразы «нужен ПИН».
CERTIFICATES = [
    ("PS-0001", "5000", None),
    ("PS-0002", "1500", "9999"),
    ("PS-0004", "3000", None),
]


class Stand:
    def __init__(self, control_port: int, secret: str | None):
        self.base = f"http://127.0.0.1:{control_port}/stand"
        self.secret = secret

    def door(self, path: str, /, **params):
        url = f"{self.base}/{path}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        try:
            with urllib.request.urlopen(url, timeout=30) as reply:
                body = reply.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            sys.exit(f">>> {path}: отказ {e.code}: {e.read().decode('utf-8')}")
        except urllib.error.URLError as e:
            sys.exit(f">>> {path}: стенд не отвечает на {self.base} ({e.reason})")
        if self.secret and self.secret in body:
            sys.exit(f">>> {path}: УТЕЧКА — ключ провайдера в ответе двери")
        print(f">>> {path}\n{body}")
        return json.loads(body) if body.startswith(("{", "[")) else body


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--control",
        type=int,
        default=int(os.environ.get("TELEPOS_STAND_CONTROL", "8799")),
        help="порт двери управления стенда (TELEPOS_STAND_CONTROL)",
    )
    parser.add_argument("--fiscal-url", help="адрес эмулятора WebKassa")
    parser.add_argument("--qr-url", help="адрес эмулятора провайдера QR")
    parser.add_argument("--qr-code", default="sbp_stand")
    parser.add_argument("--qr-patience", default="180", help="секунды")
    parser.add_argument(
        "--skip-cash",
        action="store_true",
        help="не заводить кассовый счёт (стенд, где он уже есть)",
    )
    args = parser.parse_args()

    sys.stdout.reconfigure(encoding="utf-8")
    secret = os.environ.get(QR_KEY_ENV) or None
    stand = Stand(args.control, secret)

    stand.door("configure", company="Магазин Приёмка QR", cashbox="POS", pos="1")
    if not args.skip_cash:
        stand.door("seed-cash-account")
    stand.door("seed-bank-account", id="2", name="Эквайринг (банк)")
    stand.door("sell-settings", debt="1", discount="1")
    stand.door("payment-kinds", on="certificate,prepayment,installment,qr")

    for ucode, barcode, name, price in PRODUCTS:
        stand.door(
            "seed-product", ucode=ucode, barcode=barcode, name=name, price=price
        )

    cashiers = stand.door("seed-cashiers")
    admin = stand.door("seed-cashier", name="Администратор Смены", pin="5678")
    stand.door("set-user-role", id=admin["id"], role="administrator")
    stand.door("open-shift", user=cashiers["withPin"]["id"])

    for phone, name, prepay, bonus in CUSTOMERS:
        stand.door(
            "seed-customer", phone=phone, name=name, prepay=prepay, bonus=bonus
        )

    for number, nominal, pin in CERTIFICATES:
        extra = {"pin": pin} if pin else {}
        stand.door("seed-certificate", number=number, nominal=nominal, **extra)

    if args.fiscal_url:
        stand.door("fiscal", operator="webkassa", url=args.fiscal_url)
    if args.qr_url:
        stand.door(
            "qr-provider",
            url=args.qr_url,
            code=args.qr_code,
            key=secret or "",
            patience=args.qr_patience,
        )
        stand.door("qr-provider")
    stand.door("hardware", clear="1")
    stand.door("invite")
    stand.door("state")


if __name__ == "__main__":
    main()
