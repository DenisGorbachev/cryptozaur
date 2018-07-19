defmodule Cryptozaur.Drivers.HuobiRestTest do
  use ExUnit.Case
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney, options: [clear_mock: true]
  import OK, only: [success: 1]
  alias Cryptozaur.Drivers.HuobiRest

  setup_all do
    HTTPoison.start()

    credentials = Application.get_env(:cryptozaur, :huobi, %{key: "", secret: ""})

    %{credentials: credentials}
  end

  test "init/1 should fetch trading account id", %{credentials: credentials} do
    # yes, use the same cassette as `get_accounts` test
    use_cassette "huobi/get_accounts" do
      no_account_id_credentials = Map.delete(credentials, :trading_account_id)
      success(_) = HuobiRest.start_link(no_account_id_credentials)
    end
  end

  test "init/1 shouldn't fetch trading account id for public driver" do
    # yes, use the same cassette as `get_accounts` test
    use_cassette "huobi/nothing" do
      success(_) = HuobiRest.start_link(%{key: :public})
    end
  end

  test "init/1 should return error when no trading account found", %{credentials: credentials} do
    use_cassette "huobi/get_accounts_bad" do
      no_account_id_credentials = Map.delete(credentials, :trading_account_id)
      Process.flag(:trap_exit, true)
      HuobiRest.start_link(no_account_id_credentials)
      assert_receive {:EXIT, _, "No active trading account"}
    end
  end

  describe "with trading_account_id" do
    setup context do
      # set trading account explicitly to prevent extra call in init/1
      credentials = Map.put(context.credentials, :trading_account_id, "2019764")
      success(driver) = HuobiRest.start_link(credentials)

      %{driver: driver, credentials: credentials}
    end

    test "get_symbols", %{driver: driver} do
      use_cassette "huobi/get_symbols" do
        success(result) = HuobiRest.get_symbols(driver)

        assert %{
                 "base-currency" => "omg",
                 "quote-currency" => "usdt",
                 "amount-precision" => 4,
                 "price-precision" => 2,
                 "symbol-partition" => "main"
               } == List.first(result)
      end
    end

    test "get_latest_trades", %{driver: driver} do
      use_cassette "huobi/get_latest_trades" do
        success(result) = HuobiRest.get_latest_trades(driver, "LTC", "BTC", 1)

        assert [
                 %{
                   "data" => [
                     %{
                       "amount" => 2.00000000,
                       "direction" => "sell",
                       "id" => 17_084_821_401_006_066_030,
                       "price" => 0.01608900,
                       "ts" => 1_517_300_010_434
                     }
                   ],
                   "id" => 1_708_482_140,
                   "ts" => 1_517_300_010_434
                 }
               ] == result
      end
    end

    test "get_ticker", %{driver: driver} do
      use_cassette "huobi/get_ticker" do
        success(result) = HuobiRest.get_ticker(driver, "BTC", "USDT")

        assert %{
                 "id" => 1_459_292_454,
                 "bid" => [11370.1, 0.0088],
                 "ask" => [11380.59, 0.017],
                 "open" => 12333.0,
                 "high" => 12588.87,
                 "low" => 11018.0,
                 "close" => 11370.1,
                 "count" => 150_803,
                 "amount" => 8960.53341581391,
                 "vol" => 105_207_278.39132378,
                 "version" => 1_459_292_454
               } == result
      end
    end

    test "get_accounts", %{driver: driver} do
      use_cassette "huobi/get_accounts" do
        success(result) = HuobiRest.get_accounts(driver)

        assert [
                 %{
                   "id" => 2_019_764,
                   "state" => "working",
                   "subtype" => "",
                   "type" => "spot"
                 }
               ] == result
      end
    end

    test "get_balance", %{driver: driver} do
      use_cassette "huobi/get_balances" do
        success(result) = HuobiRest.get_balances(driver)

        # truncate data to assert
        truncated = Map.put(result, "list", Enum.take(result["list"], 1))

        assert %{
                 "id" => 2_019_764,
                 "list" => [
                   %{
                     "balance" => "0.000000000000000000",
                     "currency" => "act",
                     "type" => "trade"
                   }
                 ],
                 "state" => "working",
                 "type" => "spot"
               } == truncated
      end
    end

    test "get_orders (submitted order)", %{driver: driver} do
      use_cassette "huobi/get_orders_submitted" do
        success(result) = HuobiRest.get_orders(driver)

        assert [
                 %{
                   "account-id" => 2_019_764,
                   "amount" => "1.000000000000000000",
                   "canceled-at" => 0,
                   "created-at" => 1_517_314_091_356,
                   "field-amount" => "0.0",
                   "field-cash-amount" => "0.0",
                   "field-fees" => "0.0",
                   "finished-at" => 0,
                   "id" => 1_009_318_443,
                   "price" => "0.010000000000000000",
                   "source" => "api",
                   "state" => "submitted",
                   "symbol" => "eoseth",
                   "type" => "buy-limit"
                 }
               ] == result
      end
    end

    test "get_orders (cancelled order)", %{driver: driver} do
      use_cassette "huobi/get_orders_cancelled" do
        success(result) = HuobiRest.get_orders(driver)

        assert [
                 %{
                   "account-id" => 2_019_764,
                   "amount" => "1.000000000000000000",
                   "canceled-at" => 1_517_322_129_912,
                   "created-at" => 1_517_314_091_356,
                   "field-amount" => "0.0",
                   "field-cash-amount" => "0.0",
                   "field-fees" => "0.0",
                   "finished-at" => 1_517_322_129_959,
                   "id" => 1_009_318_443,
                   "price" => "0.010000000000000000",
                   "source" => "api",
                   "state" => "canceled",
                   "symbol" => "eoseth",
                   "type" => "buy-limit"
                 }
               ] == result
      end
    end

    test "get_orders (filled order)", %{driver: driver} do
      use_cassette "huobi/get_orders_filled" do
        success(result) = HuobiRest.get_orders(driver, %{"states" => "filled"})

        assert [
                 %{
                   "account-id" => 2_019_764,
                   "amount" => "0.100000000000000000",
                   "canceled-at" => 0,
                   "created-at" => 1_517_323_628_646,
                   "field-amount" => "0.100000000000000000",
                   "field-cash-amount" => "0.001106000000000000",
                   "field-fees" => "0.000002212000000000",
                   "finished-at" => 1_517_323_668_177,
                   "id" => 1_011_768_083,
                   "price" => "0.011060000000000000",
                   "source" => "api",
                   "state" => "filled",
                   "symbol" => "eoseth",
                   "type" => "sell-limit"
                 },
                 %{
                   "account-id" => 2_019_764,
                   "amount" => "0.100000000000000000",
                   "canceled-at" => 0,
                   "created-at" => 1_517_322_935_819,
                   "field-amount" => "0.100000000000000000",
                   "field-cash-amount" => "0.001100516000000000",
                   "field-fees" => "0.000200000000000000",
                   "finished-at" => 1_517_323_051_582,
                   "id" => 1_011_596_711,
                   "price" => "0.011005160000000000",
                   "source" => "api",
                   "state" => "filled",
                   "symbol" => "eoseth",
                   "type" => "buy-limit"
                 },
                 %{
                   "account-id" => 2_019_764,
                   "amount" => "0.100000000000000000",
                   "canceled-at" => 0,
                   "created-at" => 1_517_322_845_288,
                   "field-amount" => "0.100000000000000000",
                   "field-cash-amount" => "0.001100034000000000",
                   "field-fees" => "0.000200000000000000",
                   "finished-at" => 1_517_323_116_597,
                   "id" => 1_011_575_146,
                   "price" => "0.011000340000000000",
                   "source" => "api",
                   "state" => "filled",
                   "symbol" => "eoseth",
                   "type" => "buy-limit"
                 }
               ] == result
      end
    end

    test "place_order", %{driver: driver} do
      use_cassette "huobi/place_order_buy_limit" do
        success(result) =
          HuobiRest.place_order(driver, "EOS", "ETH", "buy-limit", 1.0, %{
            price: 0.01
          })

        assert "1009318443" == result
      end
    end

    test "cancel_order", %{driver: driver} do
      use_cassette "huobi/cancel_order" do
        success(result) = HuobiRest.cancel_order(driver, 1_009_318_443)

        assert "1009318443" == result
      end
    end
  end
end
