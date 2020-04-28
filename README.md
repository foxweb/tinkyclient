# TinkyClient — tiny client for Tinkoff OpenAPI

Предлагаю вашему вниманию небольшой консольный Ruby-клиент для доступа к брокерскому аккаунту Тинькофф Инвестиции.
На данный момент это очень ранняя пре-альфа-версия, реализовано только отображение портфолио.
Цель проекта — сделать удобный консольный клиент для контроля своих активов, дополняющий официальное мобильное приложение [Инвестиции](https://www.tinkoff.ru/invest/).

# Быстрый старт

Требования:
- установленный Ruby 2.7.1
- наличие [токена Tinkoff OpenAPI](https://tinkoffcreditsystems.github.io/invest-openapi/auth/)

```sh
$ bundle
$ echo TINKOFF_OPENAPI_TOKEN=ваш_токен > .env.local
$ bin/portfolio
$ bin/currencies
```

# Уведомление о защите персональных данных

1. Используя этот проект, никакие персональные данные НЕ ПЕРЕДАЮТСЯ никаким третьим лицам скрыто или явно.
2. Использование этого проекта не требует от пользователя никаких логинов, паролей, номеров телефона и других персональных данных.
3. Для доступа к вашем брокерскому счёту вы используете только ваш персональный токен из личного кабинета Тинькофф Инвестиций.
4. Этот токен вы генерируете самостоятельно.
5. Для нормальной работы этой программы вы самостоятельно записываете токен в текстовый файл, который сохраняется только на вашем устройстве.
6. Вы можете в любой момент отозвать (деактивировать) свой токен, если у вас возникнут подозрения в компрометации.

# Ссылки

- https://www.tinkoff.ru/invest/
- https://www.tinkoff.ru/invest/web-terminal/
- https://github.com/TinkoffCreditSystems/invest-openapi/
- https://tinkoffcreditsystems.github.io/invest-openapi/
- https://t.me/tinkoffinvestopenapi

# Лицензия

MIT License. Используйте как хотите и где хотите на свой страх и риск.

# Отказ от ответственности

Автор ничего не гарантирует и не отвечает ни за какие финансовые потери и риски пользователя, связанные с использованием этой программы. Программа разработана в образовательных целях, для обучения программированию и изучения языка Ruby. Несмотря на это, используя эту программу вы можете как потерять, так приобрести реальные денежные средства.
