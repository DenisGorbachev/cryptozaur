defmodule Cryptozaur.Connectors.Huobi do
  import OK, only: [success: 1]

  import Cryptozaur.Utils

  alias Cryptozaur.Model.{Ticker, Trade, Order, Balance}
  alias Cryptozaur.Drivers.HuobiRest, as: Rest

  # http://api.huobi.pro/v1/common/symbols
  @info Map.get(Poison.decode!(~s({"status":"ok","data":[{"base-currency":"btc","quote-currency":"usdt","price-precision":2,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"bch","quote-currency":"usdt","price-precision":2,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"eth","quote-currency":"usdt","price-precision":2,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"etc","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"ltc","quote-currency":"usdt","price-precision":2,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"eos","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"xrp","quote-currency":"usdt","price-precision":4,"amount-precision":2,"symbol-partition":"main"},{"base-currency":"omg","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"dash","quote-currency":"usdt","price-precision":2,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"zec","quote-currency":"usdt","price-precision":2,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"ada","quote-currency":"usdt","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"steem","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"iota","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"ocn","quote-currency":"usdt","price-precision":8,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"soc","quote-currency":"usdt","price-precision":4,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"ctxc","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"act","quote-currency":"usdt","price-precision":4,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"btm","quote-currency":"usdt","price-precision":4,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"bts","quote-currency":"usdt","price-precision":4,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"ont","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"iost","quote-currency":"usdt","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"ht","quote-currency":"usdt","price-precision":4,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"trx","quote-currency":"usdt","price-precision":6,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"dta","quote-currency":"usdt","price-precision":8,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"neo","quote-currency":"usdt","price-precision":2,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"qtum","quote-currency":"usdt","price-precision":2,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"smt","quote-currency":"usdt","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"ela","quote-currency":"usdt","price-precision":4,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"ven","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"theta","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"snt","quote-currency":"usdt","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"zil","quote-currency":"usdt","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"xem","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"nas","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"ruff","quote-currency":"usdt","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"hsr","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"let","quote-currency":"usdt","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"mds","quote-currency":"usdt","price-precision":6,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"storj","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"elf","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"itc","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"cvc","quote-currency":"usdt","price-precision":4,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"gnt","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"xmr","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"bch","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"eth","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"ltc","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"etc","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"eos","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"main"},{"base-currency":"omg","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"xrp","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"main"},{"base-currency":"dash","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"zec","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"ada","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"main"},{"base-currency":"steem","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"main"},{"base-currency":"iota","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"main"},{"base-currency":"poly","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"kan","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"lba","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"wan","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"bft","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"btm","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"ont","quote-currency":"btc","price-precision":8,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"iost","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"ht","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"trx","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"smt","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"ela","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"wicc","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"ocn","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"zla","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"abt","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"mtx","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"nas","quote-currency":"btc","price-precision":8,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"ven","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"dta","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"neo","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"wax","quote-currency":"btc","price-precision":8,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"bts","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"zil","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"theta","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"ctxc","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"srn","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"xem","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"icx","quote-currency":"btc","price-precision":8,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"dgd","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"chat","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"wpr","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"lun","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"swftc","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"snt","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"meet","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"yee","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"elf","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"let","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"qtum","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"lsk","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"itc","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"soc","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"qash","quote-currency":"btc","price-precision":8,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"mds","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"eko","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"topc","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"mtn","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"act","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"hsr","quote-currency":"btc","price-precision":8,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"stk","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"storj","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"gnx","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"dbc","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"snc","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"cmt","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"tnb","quote-currency":"btc","price-precision":10,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"ruff","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"qun","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"zrx","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"knc","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"blz","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"propy","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"rpx","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"appc","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"aidoc","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"powr","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"cvc","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"pay","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"qsp","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"dat","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"rdn","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"mco","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"rcn","quote-currency":"btc","price-precision":10,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"mana","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"utk","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"tnt","quote-currency":"btc","price-precision":10,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"gas","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"bat","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"ost","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"link","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"gnt","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"mtl","quote-currency":"btc","price-precision":8,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"evx","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"req","quote-currency":"btc","price-precision":8,"amount-precision":1,"symbol-partition":"innovation"},{"base-currency":"adx","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"ast","quote-currency":"btc","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"eng","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"salt","quote-currency":"btc","price-precision":8,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"edu","quote-currency":"btc","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"bifi","quote-currency":"btc","price-precision":8,"amount-precision":4,"symbol-partition":"bifurcation"},{"base-currency":"bcx","quote-currency":"btc","price-precision":8,"amount-precision":4,"symbol-partition":"bifurcation"},{"base-currency":"bcd","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"bifurcation"},{"base-currency":"sbtc","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"bifurcation"},{"base-currency":"btg","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"bifurcation"},{"base-currency":"xmr","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"eos","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"main"},{"base-currency":"omg","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"iota","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"ada","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"steem","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"poly","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"kan","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"lba","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"wan","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"bft","quote-currency":"eth","price-precision":8,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"zrx","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"ast","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"knc","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"ont","quote-currency":"eth","price-precision":8,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"ht","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"btm","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"iost","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"smt","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"ela","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"trx","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"abt","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"nas","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"ocn","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"wicc","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"zil","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"ctxc","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"zla","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"wpr","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"dta","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"mtx","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"theta","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"srn","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"ven","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"bts","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"wax","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"hsr","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"icx","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"mtn","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"act","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"blz","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"qash","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"ruff","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"cmt","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"elf","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"meet","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"soc","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"qtum","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"itc","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"swftc","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"yee","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"lsk","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"lun","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"let","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"gnx","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"chat","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"eko","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"topc","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"dgd","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"stk","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"mds","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"dbc","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"snc","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"pay","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"qun","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"aidoc","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"tnb","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"appc","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"rdn","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"utk","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"powr","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"bat","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"propy","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"mana","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"req","quote-currency":"eth","price-precision":8,"amount-precision":1,"symbol-partition":"innovation"},{"base-currency":"cvc","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"qsp","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"evx","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"dat","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"mco","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"gnt","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"gas","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"ost","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"link","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"rcn","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"tnt","quote-currency":"eth","price-precision":8,"amount-precision":0,"symbol-partition":"innovation"},{"base-currency":"eng","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"salt","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"adx","quote-currency":"eth","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"edu","quote-currency":"eth","price-precision":10,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"xrp","quote-currency":"ht","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"iost","quote-currency":"ht","price-precision":8,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"dash","quote-currency":"ht","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"wicc","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"eos","quote-currency":"ht","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"bch","quote-currency":"ht","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"ltc","quote-currency":"ht","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"etc","quote-currency":"ht","price-precision":6,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"waves","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"waves","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"hb10","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"main"},{"base-currency":"cmt","quote-currency":"usdt","price-precision":4,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"dcr","quote-currency":"btc","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"dcr","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"},{"base-currency":"pai","quote-currency":"btc","price-precision":8,"amount-precision":2,"symbol-partition":"innovation"},{"base-currency":"pai","quote-currency":"eth","price-precision":6,"amount-precision":4,"symbol-partition":"innovation"}]})), "data")

  def get_symbols do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      symbols <- Rest.get_symbols(rest)
    after
      Enum.map(symbols, &to_symbol(&1["base-currency"], &1["quote-currency"]))
    end
  end

  # Huobi returns an error for these currencies
  def get_ticker(base, quote) when base in ["BT1", "BT2"] do
    success(%Ticker{
      symbol: to_symbol(base, quote),
      bid: 0.0,
      ask: 0.0,
      volume_24h_base: 0.0,
      volume_24h_quote: 0.0
    })
  end

  def get_ticker(base, quote) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      ticker <- Rest.get_ticker(rest, base, quote)
    after
      to_ticker(ticker, base, quote)
    end
  end

  def get_tickers() do
    with success(symbols) <- get_symbols() do
      ticker_tuples = symbols |> Enum.map(&get_ticker_by_symbol(&1))
      # check that each ticker_tuple is a success, or return the first failure
      with success(ticker_tuples) <- all_ok(ticker_tuples, ticker_tuples) do
        ticker_tuples |> Enum.map(&unwrap(&1)) |> success()
      end
    end
  end

  def get_ticker_by_symbol(symbol) do
    [_exchange, base, quote] = to_list(symbol)
    get_ticker(base, quote)
  end

  def get_latest_trades(base, quote) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_public_driver(Rest)
      result <- Rest.get_latest_trades(rest, base, quote)
    after
      trades = Enum.map(result, &List.first(&1["data"]))
      symbol = to_symbol(base, quote)
      Enum.map(trades, &to_trade(symbol, &1))
    end
  end

  def get_orders(key, secret, base, quote) do
    OK.for do
      pair = "#{base}:#{quote}"
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      orders <- Rest.get_orders(rest)

      orders =
        orders
        |> Enum.map(&to_order/1)
        |> Enum.filter(&(&1.pair == pair))
    after
      orders
    end
  end

  def get_balances(key, secret) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
      %{"list" => balances} <- Rest.get_balances(rest)
      balances = balances |> Enum.group_by(& &1["currency"])
    after
      # TODO: subtract type = frozen from type = trade
      balances |> Enum.map(&to_balance/1)
    end
  end

  def place_order(key, secret, base, quote, amount, price, _extra \\ %{}) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
    after
      type = if amount > 0, do: "buy-limit", else: "sell-limit"
      Rest.place_order(rest, base, quote, type, abs(amount), %{price: price})
    end
  end

  def cancel_order(key, secret, _base, _quote, uid) do
    OK.for do
      rest <- Cryptozaur.DriverSupervisor.get_driver(key, secret, Rest)
    after
      Rest.cancel_order(rest, uid)
    end
  end

  defp to_balance({currency, balances}) do
    [
      %{"type" => "trade", "balance" => available_balance_string},
      %{"type" => "frozen", "balance" => frozen_balance_string}
    ] = balances

    available_balance = available_balance_string |> to_float()
    frozen_balance = frozen_balance_string |> to_float()
    %Balance{currency: String.upcase(currency), total_amount: available_balance + frozen_balance, available_amount: available_balance}
  end

  defp to_ticker(%{"bid" => [bid, _bid_amount], "ask" => [ask, _ask_amount], "amount" => volume_24h_base, "vol" => volume_24h_quote}, base, quote) do
    %Ticker{
      symbol: to_symbol(base, quote),
      bid: to_float(bid),
      ask: to_float(ask),
      volume_24h_base: to_float(volume_24h_base),
      volume_24h_quote: to_float(volume_24h_quote)
    }
  end

  defp to_order(%{
         "amount" => amount_requested_string,
         "created-at" => created_at,
         "field-amount" => amount_filled_string,
         "field-cash-amount" => quote_filled_string,
         # in base currency for "buy" orders and in quote for "sell" ones
         "field-fees" => fee_string,
         "id" => uid_int,
         "price" => price_string,
         "state" => state,
         # "eoseth"
         "symbol" => symbol,
         # "sell-limit", "sell-market", "buy-limit", "buy-market"
         "type" => type
       }) do
    sign = if String.starts_with?(type, "buy-"), do: 1, else: -1
    pair = parse_pair(symbol)
    timestamp = parse_timestamp(created_at)
    amount_requested = Float.parse(amount_requested_string) |> elem(0)
    amount_filled = Float.parse(amount_filled_string) |> elem(0)
    uid = Integer.to_string(uid_int)
    price = Float.parse(price_string) |> elem(0)

    quote_filled = Float.parse(quote_filled_string) |> elem(0)
    fee = Float.parse(fee_string) |> elem(0)

    # exchange takes fee from what you've got after the order is executed
    base_diff = sign * amount_filled - if sign == 1, do: fee, else: 0
    quote_diff = -1 * sign * (quote_filled - if sign == 1, do: 0, else: fee)

    status =
      cond do
        state in ["canceled", "filled", "partial-canceled"] -> "closed"
        true -> "opened"
      end

    %Order{
      uid: uid,
      pair: pair,
      price: price,
      base_diff: base_diff,
      quote_diff: quote_diff,
      amount_requested: amount_requested * sign,
      amount_filled: amount_filled * sign,
      status: status,
      timestamp: timestamp
    }
  end

  defp parse_pair(string) do
    quote =
      cond do
        String.ends_with?(string, "btc") -> "BTC"
        String.ends_with?(string, "eth") -> "ETH"
        String.ends_with?(string, "usdt") -> "USDT"
        true -> raise "Unknown quote currency in #{string}"
      end

    base = string |> String.upcase() |> String.replace_suffix(quote, "")
    "#{base}:#{quote}"
  end

  defp to_symbol(base, quote) do
    "HUOBI:#{to_pair(base, quote)}"
  end

  defp to_pair(base, quote) do
    "#{String.upcase(base)}:#{String.upcase(quote)}"
  end

  defp to_trade(symbol, data) do
    %{
      "amount" => amount,
      # "sell", "buy"
      "direction" => type,
      "id" => uid,
      "price" => price,
      "ts" => timestamp
    } = data

    sign =
      case type do
        "buy" -> 1
        "sell" -> -1
      end

    uid_string = Integer.to_string(uid)
    timestamp = parse_timestamp(timestamp)

    %Trade{
      uid: uid_string,
      symbol: symbol,
      price: price,
      amount: amount * sign,
      timestamp: timestamp
    }
  end

  defp parse_timestamp(timestamp) do
    DateTime.from_unix!(timestamp, :millisecond) |> DateTime.to_naive()
  end

  def get_amount_precision(base, quote) do
    base = String.downcase(base)
    quote = String.downcase(quote)
    @info |> Enum.find(&(&1["base-currency"] == base and &1["quote-currency"] == quote)) |> Map.get("amount-precision")
  end

  def get_price_precision(base, quote) do
    base = String.downcase(base)
    quote = String.downcase(quote)
    @info |> Enum.find(&(&1["base-currency"] == base and &1["quote-currency"] == quote)) |> Map.get("price-precision")
  end

  def get_tick(_base, quote) do
    case quote do
      _ -> 0.00000001
    end
  end

  # TODO copy-pasted
  def get_min_amount(base, price) do
    case base do
      _ -> 0.00001000 / price
    end
  end

  def get_link(base, quote) do
    "https://www.huobi.pro/#{String.downcase(base)}_#{String.downcase(quote)}/exchange/"
  end
end
