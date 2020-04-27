# TinkyClient — tiny client for Tinkoff OpenAPI

Предлагаю вашему внимаю небольшой консольный Ruby-клиент для доступа к брокерскому аккаунту Тинькофф Инвестиции.
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
```

# Ссылки

- https://www.tinkoff.ru/invest/
- https://www.tinkoff.ru/invest/web-terminal/
- https://github.com/TinkoffCreditSystems/invest-openapi/
- https://tinkoffcreditsystems.github.io/invest-openapi/
- https://t.me/tinkoffinvestopenapi

# Лицензия

MIT License. Используйте как хотите и где хотите на свой страх и риск.
