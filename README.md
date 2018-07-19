# Crypto CLI

Crypto CLI is a command-line interface for trading on cryptocurrency exchanges.

# Example

## Buy LEX tokens on LeverEX

First, get your API key & secret on credentials management page.

Second, execute the following commands:

```
cryptonaut add.account leverex [your_key] [your_secret]
cryptonaut activate leverex
(leverex) get.deposit.address BTC
BTC: [your_deposit_address]
# Send BTC to [your_deposit_address]
(leverex) get.deposits BTC
Amount  Timestamp               Confirmations   TXID
0.5     2018-07-17 16:16:00     0               4b1613ae67ee0ebcd6f84d50f6d0d2eb4579e9c7f31c57cf79c333ba9a145c15       
(leverex) await.deposit BTC
# Wait until dialog window appears per https://superuser.com/questions/31917/is-there-a-way-to-show-notification-from-bash-script-in-ubuntu
(leverex) show.spread LEX:BTC

```
