require "test_helper"

class AccountTest < ActiveSupport::TestCase
  include SyncableInterfaceTest

  setup do
    @account = @syncable = accounts(:depository)
    @family = families(:dylan_family)
  end

  test "can destroy" do
    assert_difference "Account.count", -1 do
      @account.destroy
    end
  end

  test "groups accounts by type" do
    result = @family.accounts.by_group(period: Period.all)
    assets = result[:assets]
    liabilities = result[:liabilities]

    assert_equal @family.assets, assets.sum
    assert_equal @family.liabilities, liabilities.sum

    depositories = assets.children.find { |group| group.name == "Depository" }
    properties = assets.children.find { |group| group.name == "Property" }
    vehicles = assets.children.find { |group| group.name == "Vehicle" }
    investments = assets.children.find { |group| group.name == "Investment" }
    other_assets = assets.children.find { |group| group.name == "OtherAsset" }

    credits = liabilities.children.find { |group| group.name == "CreditCard" }
    loans = liabilities.children.find { |group| group.name == "Loan" }
    other_liabilities = liabilities.children.find { |group| group.name == "OtherLiability" }

    assert_equal 2, depositories.children.count
    assert_equal 1, properties.children.count
    assert_equal 1, vehicles.children.count
    assert_equal 1, investments.children.count
    assert_equal 1, other_assets.children.count

    assert_equal 1, credits.children.count
    assert_equal 1, loans.children.count
    assert_equal 1, other_liabilities.children.count
  end

  test "generates balance series" do
    assert_equal 2, @account.series.values.count
  end

  test "generates balance series with single value if no balances" do
    @account.balances.delete_all
    assert_equal 1, @account.series.values.count
  end

  test "generates balance series in period" do
    @account.balances.delete_all
    @account.balances.create! date: 31.days.ago.to_date, balance: 5000, currency: "USD" # out of period range
    @account.balances.create! date: 30.days.ago.to_date, balance: 5000, currency: "USD" # in range

    assert_equal 1, @account.series(period: Period.last_30_days).values.count
  end

  test "generates empty series if no balances and no exchange rate" do
    with_env_overrides SYNTH_API_KEY: nil do
      assert_equal 0, @account.series(currency: "NZD").values.count
    end
  end
end
