# Cryptozaur CLI

![Intro image](https://github.com/DenisGorbachev/cryptozaur/blob/master/images/intro.jpg)

## Developer's best friend

Cryptozaur **saves your time** by providing a unified command-line interface for cryptocurrency exchanges:

* Place orders without opening UI.
* Use simple automated trading strategies:
  * Accumulate a lowcap altcoin by maintaining small buy orders within price range.
  * Optimize your stop-loss by selling off your position in small chunks instead of dumping it immediately.
* List aggregated balances from all exchanges.
* Export trade history to CSV from all exchanges.

## Contents

* [Installation](#installation)
* [Examples](#examples)
* [Automated trading](#automated-trading)
* [Architecture](#architecture)

## Installation

1. [Install Elixir](https://elixir-lang.org/install.html)
1. `git clone https://github.com/DenisGorbachev/cryptozaur.git`
1. `cd cryptozaur`
1. `mix deps.get`
1. `mix reset`
1. `./cryptozaur add.account [EXCHANGE] [KEY] [SECRET]`

**Optional**: add `cryptozaur` directory to `PATH` for easy invocation.
 
**Recommended**: encrypt `~/.cryptozaur` directory ([guide](#encrypt-cryptozaur-directory)).

## Examples

### Buy LEX tokens on LeverEX

First, get your API key & secret on credentials management page.

Second, execute the following commands:

```
cryptozaur add.account leverex [your_key] [your_secret]

cryptozaur get.deposit.address leverex BTC
BTC: [your_deposit_address]
### Send BTC to [your_deposit_address]

cryptozaur get.deposits leverex BTC
Amount  Timestamp               Confirmations   TXID
0.5     2018-07-17 16:16:00     0               4b1613ae67ee0ebcd6f84d50f6d0d2eb4579e9c7f31c57cf79c333ba9a145c15       

cryptozaur await.deposit leverex BTC
### Wait until dialog window appears per https://superuser.com/questions/31917/is-there-a-way-to-show-notification-from-bash-script-in-ubuntu

cryptozaur show.spread leverex LEX:BTC
Ask: 0.00006530 150.0
Bid: 0.00006510 35.5

cryptozaur buy leverex LEX:BTC 0.00006530 20
[UID: 43213253] Buy 20.0 LEX at 0.00006530 BTC = 0.00130600 BTC (Filled 20.0 LEX)

cryptozaur withdraw leverex LEX 20.0 0x4fdd5eb2fb260149a3903859043e962ab89d8ed4
[UID: 138483] Withdraw 20.0 LEX to 0x4fdd5eb2fb260149a3903859043e962ab89d8ed4 (Confirmations: 0)
### Wait until withdrawal is processed

cryptozaur show.withdrawal leverex 138483
[UID: 138483] Withdraw 20.0 LEX to 0x4fdd5eb2fb260149a3903859043e962ab89d8ed4 (Confirmations: 4)
```

### Place a stop-loss order

With Cryptozaur, you can **save money** by offloading your position in small chunks instead of market-selling through the orderbook. 

```
cryptozaur stop.sell coinex ETH:BTC 0.068 350 10 600

### This command will start selling ETH if price goes below 0.068 from full position of 350 ETH in chunks of 10 ETH until the full position is sold (waiting for 600 seconds = 10 minutes between each sell)
### This command will also maintain 10 ETH sell order trailing at ask, to ensure that any buying by other traders will hit your order.
```

### Run trans-fee mining

Some exchanges have recently implemented "[trans-fee mining](https://www.binaryoptions.net/what-is-trans-fee-mining-and-why-you-should-care/)". It's a profitable (although questionable) way of acquiring native exchange tokens via self-trade.

```
cryptozaur add.account coinex [your_key] [your_secret]

cryptozaur mine coinex ETH:BTC --single-order-amount 0.1 --budget 0.5
### This command will self-trade on ETH:BTC market by concurrently placing buy & sell orders for 0.1 ETH at the same price until the budget of 0.5 BTC is exhausted
```

## Automated trading

You can automate your trading by running certain commands periodically via task scheduler:

* MacOS and Linux: [Cron](https://www.howtoforge.com/a-short-introduction-to-cron-jobs)
* Windows 7 and below: [Task Scheduler](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/cc748993(v=ws.11))
* Windows 8 and above: [Schtasks](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/cc725744(v=ws.11))

For example, if you want to accumulate a lowcap altcoin, you can add the following line to crontab:

```
15 * * * * /usr/bin/cryptozaur accumulate --account tradeogre --market MSR:BTC --from-price 0.00005200 --to-price 0.00005800 --full-amount 190000.0 --visible-amount 10000.0 --order-count 10 >> /var/log/MSR.accumulate.log 2>&1
```

This command will run every 15 minutes, maintaining 10 buy orders summing up to 10000.0 MSR, spreading them evenly between 5200-5800 sats, until it accumulates 190000.0 MSR.

## Architecture

* Cryptozaur stores keys & secrets in `~/.cryptozaur/accounts.json`. We strongly recommend to encrypt `~/.cryptozaur` directory! ([guide](#encrypt-cryptozaur-directory))

### Terminology

* `account` - API key & secret pair (e.g. "leverex")
* `market` - exchange partition that allows trading `base` asset against `quote` asset (e.g. "ETH:BTC" spot market or "ETHM18" futures market).
* `symbol` - unique identifier of the trading pair (e.g. "BINANCE:BNB:BTC") (format: `"#{exchange}:#{base}:#{quote}"`)
* `base` - asset being bought / sold (e.g. 1ST, AMP, PTOY)
* `quote` - asset used for buying / selling (e.g. BTC, ETH)
* `amount` - quantity of base asset (e.g. AMP)
* `base_diff` - quantity of base asset affected by the order (to handle fees)
* `quote_diff` - quantity of quote asset affected by the order (to handle fees)
* `capital` - quantity of quote asset (e.g. BTC) managed by strategy
* `range` - prices from `bottom` to `top`
* `frame` - timestamps from `from` to `to`
* `tick` - minimum price increment / decrement
* `precision` - minimum price / amount precision (e.g. "8" for *most, but not all* ALTBTC pairs, since BTC is divisible by 8 digits) (different from `tick`: e.g. `tick = 0.5`, `precision = 1`)

## Guides

### Encrypt Cryptozaur directory

MacOS / Linux:

```
### Setup (run once)
mkdir -p ~/.cryptozaur.encfs ~/.cryptozaur

### Mount (run every time you want to use cryptozaur)
encfs ~/.cryptozaur.encfs ~/.cryptozaur

### Unmount (run after you finished using cryptozaur)
fusermount -u ~/.cryptozaur
```

Windows:

```
### Want to contribute? Click "edit" on top of this file.
```
