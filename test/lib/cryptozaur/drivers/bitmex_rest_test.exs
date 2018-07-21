defmodule Cryptozaur.Drivers.BitmexRestTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  import OK, only: [success: 1]

  alias Cryptozaur.Drivers.BitmexRest, as: Rest

  setup_all do
    HTTPoison.start()

    credentials = Application.get_env(:cryptozaur, :bitmex, key: "", secret: "")

    success(driver) = Rest.start_link(Enum.into(credentials, %{}))

    %{driver: driver}
  end

  test "get_trades should return a bucket of trades", %{driver: driver} do
    use_cassette "bitmex/get_trades" do
      {:ok, trades} = Cryptozaur.Drivers.BitmexRest.get_trades(driver, "XBT", "USD")

      [
        %{
          "trdMatchID" => "313c6f3b-d054-683f-8871-2fa3cbc10b82",
          "size" => 22563,
          "price" => 6804,
          "side" => "Buy",
          "foreignNotional" => 22563,
          "grossValue" => 331_608_411,
          "homeNotional" => 3.31608411,
          "symbol" => "XBTUSD",
          "tickDirection" => "PlusTick",
          "timestamp" => "2017-11-10T15:29:12.522Z"
        }
        | _
      ] = trades
    end
  end

  test "get_order_book should return order book for specified currency", %{driver: driver} do
    use_cassette "bitmex/order_book" do
      assert success([
               %{
                 "id" => 8_799_408_540,
                 "price" => 5914.6,
                 "side" => "Sell",
                 "size" => 80195,
                 "symbol" => "XBTUSD"
               },
               %{
                 "id" => 8_799_408_550,
                 "price" => 5914.5,
                 "side" => "Buy",
                 "size" => 2906,
                 "symbol" => "XBTUSD"
               }
             ]) == Rest.get_order_book(driver, "XBT", %{depth: 1})
    end
  end

  test "get_balance should return information about balance of the specified currency", %{driver: driver} do
    use_cassette "bitmex/get_balance" do
      assert success(%{
               "account" => 90042,
               "addr" => "3BMEX54NrJr5RDShprSLdfJ9a5Bx5RZHMX",
               "amount" => 450_000,
               "confirmedDebit" => 0,
               "currency" => "XBt",
               "deltaAmount" => 450_000,
               "deltaDeposited" => 450_000,
               "deltaTransferIn" => 0,
               "deltaTransferOut" => 0,
               "deltaWithdrawn" => 0,
               "deposited" => 450_000,
               "pendingCredit" => 0,
               "pendingDebit" => 0,
               "prevAmount" => 0,
               "prevDeposited" => 0,
               "prevTimestamp" => "2017-10-26T12:00:00.000Z",
               "prevTransferIn" => 0,
               "prevTransferOut" => 0,
               "prevWithdrawn" => 0,
               "script" => "534104220936c3245597b1513a9a7fe96d96facf1a840ee21432a1b73c2cf42c1810284dd730f21ded9d818b84402863a2b5cd1afe3a3d13719d524482592fb23c88a341042bda0510af4b27ebfc3f88c90d45b2f7514bb510ba9ecb4945076e2a49f7a4f02b4358832f0cf4ea3a6ad890899a108289d609070d21e2d7ef6cc25b2918fed0410472225d3abc8665cf01f703a270ee65be5421c6a495ce34830061eb0690ec27dfd1194e27b6b0b659418d9f91baec18923078aac18dc19699aae82583561fefe54104a24db5c0e8ed34da1fd3b6f9f797244981b928a8750c8f11f9252041daad7b2d95309074fed791af77dc85abdd8bb2774ed8d53379d28cd49f251b9c08cab7fc54ae",
               "timestamp" => "2017-10-27T08:38:46.421Z",
               "transferIn" => 0,
               "transferOut" => 0,
               "withdrawalLock" => [],
               "withdrawn" => 0
             }) == Rest.get_balance(driver, "XBt")
    end
  end

  test "place_order should successfully place an order", %{driver: driver} do
    use_cassette "bitmex/place_order" do
      assert success(%{
               "side" => "Buy",
               "transactTime" => "2017-11-04T10:39:17.918Z",
               "ordType" => "Limit",
               "displayQty" => nil,
               "stopPx" => nil,
               "settlCurrency" => "XBt",
               "triggered" => "",
               "orderID" => "0e5ccba9-00bc-7e4a-48d9-76cd22ca6bcf",
               "currency" => "USD",
               "pegOffsetValue" => nil,
               "price" => 5000,
               "pegPriceType" => "",
               "text" => "Submitted via API.",
               "workingIndicator" => true,
               "multiLegReportingType" => "SingleSecurity",
               "timestamp" => "2017-11-04T10:39:17.918Z",
               "cumQty" => 0,
               "ordRejReason" => "",
               "avgPx" => nil,
               "orderQty" => 1,
               "simpleOrderQty" => nil,
               "ordStatus" => "New",
               "timeInForce" => "GoodTillCancel",
               "clOrdLinkID" => "",
               "simpleLeavesQty" => 0.0002,
               "leavesQty" => 1,
               "exDestination" => "XBME",
               "symbol" => "XBTUSD",
               "account" => 90042,
               "clOrdID" => "",
               "simpleCumQty" => 0,
               "execInst" => "",
               "contingencyType" => ""
             }) == Rest.place_order(driver, "XBT", "USD", 1, 5000)
    end
  end

  test "delete_order should successfully remove the order", %{driver: driver} do
    use_cassette "bitmex/delete_order" do
      assert success([%{"side" => "Buy", "transactTime" => "2017-11-04T10:39:17.918Z", "ordType" => "Limit", "displayQty" => nil, "stopPx" => nil, "settlCurrency" => "XBt", "triggered" => "", "orderID" => "0e5ccba9-00bc-7e4a-48d9-76cd22ca6bcf", "currency" => "USD", "pegOffsetValue" => nil, "price" => 5000, "pegPriceType" => "", "text" => "Canceled: Canceled via API.\nSubmitted via API.", "workingIndicator" => false, "multiLegReportingType" => "SingleSecurity", "timestamp" => "2017-11-04T10:44:18.553Z", "cumQty" => 0, "ordRejReason" => "", "avgPx" => nil, "orderQty" => 1, "simpleOrderQty" => nil, "ordStatus" => "Canceled", "timeInForce" => "GoodTillCancel", "clOrdLinkID" => "", "simpleLeavesQty" => 0, "leavesQty" => 0, "exDestination" => "XBME", "symbol" => "XBTUSD", "account" => 90042, "clOrdID" => "", "simpleCumQty" => 0, "execInst" => "", "contingencyType" => ""}]) == Rest.delete_order(driver, "0e5ccba9-00bc-7e4a-48d9-76cd22ca6bcf")
    end
  end

  test "change_order should successfully change the order", %{driver: driver} do
    use_cassette "bitmex/change_order" do
      assert success(%{
               "side" => "Buy",
               "transactTime" => "2017-11-04T11:04:18.004Z",
               "ordType" => "Limit",
               "displayQty" => nil,
               "stopPx" => nil,
               "settlCurrency" => "XBt",
               "triggered" => "",
               "orderID" => "680dcacb-02ae-3c3e-4ef0-91b92a9c94cf",
               "currency" => "USD",
               "pegOffsetValue" => nil,
               "price" => 5500,
               "pegPriceType" => "",
               "text" => "Amended orderQty price: Amended via API.\nSubmitted via API.",
               "workingIndicator" => true,
               "multiLegReportingType" => "SingleSecurity",
               "timestamp" => "2017-11-04T11:04:18.004Z",
               "cumQty" => 0,
               "ordRejReason" => "",
               "avgPx" => nil,
               "orderQty" => 2,
               "simpleOrderQty" => nil,
               "ordStatus" => "New",
               "timeInForce" => "GoodTillCancel",
               "clOrdLinkID" => "",
               "simpleLeavesQty" => 0.0004,
               "leavesQty" => 2,
               "exDestination" => "XBME",
               "symbol" => "XBTUSD",
               "account" => 90042,
               "clOrdID" => "",
               "simpleCumQty" => 0,
               "execInst" => "",
               "contingencyType" => ""
             }) == Rest.change_order(driver, "680dcacb-02ae-3c3e-4ef0-91b92a9c94cf", %{price: 5500, amount: 2})
    end
  end

  test "get_orders should return information all orders", %{driver: driver} do
    use_cassette "bitmex/get_orders" do
      assert success([%{"side" => "Buy", "transactTime" => "2017-10-27T13:16:55.418Z", "ordType" => "Limit", "displayQty" => nil, "stopPx" => nil, "settlCurrency" => "XBt", "triggered" => "", "orderID" => "76a8cc9e-140d-4946-85bc-853d274b3333", "currency" => "USD", "pegOffsetValue" => nil, "price" => 5600, "pegPriceType" => "", "text" => "Submission from www.bitmex.com", "workingIndicator" => true, "multiLegReportingType" => "SingleSecurity", "timestamp" => "2017-10-27T13:16:55.418Z", "cumQty" => 0, "ordRejReason" => "", "avgPx" => nil, "orderQty" => 1, "simpleOrderQty" => nil, "ordStatus" => "New", "timeInForce" => "GoodTillCancel", "clOrdLinkID" => "", "simpleLeavesQty" => 0.0002, "leavesQty" => 1, "exDestination" => "XBME", "symbol" => "XBTUSD", "account" => 90042, "clOrdID" => "", "simpleCumQty" => 0, "execInst" => "ParticipateDoNotInitiate", "contingencyType" => ""}]) == Rest.get_orders(driver, %{})
    end
  end
end
