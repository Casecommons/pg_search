# frozen_string_literal: true

require "spec_helper"
require "active_support/core_ext/kernel/reporting"

describe "Including the deprecated PgSearch module" do
  with_model :SomeModel do
    model do
      silence_warnings do
        include PgSearch
      end
    end
  end

  with_model :AnotherModel

  it "includes PgSearch::Model" do
    expect(SomeModel.ancestors).to include PgSearch::Model
  end

  it "prints a deprecation message" do
    allow(PgSearch).to receive(:warn)

    AnotherModel.include(PgSearch)

    expect(PgSearch).to have_received(:warn).with(<<~MESSAGE, category: :deprecated, uplevel: 1)
      Directly including `PgSearch` into an Active Record model is deprecated and will be removed in pg_search 3.0.

      Please replace `include PgSearch` with `include PgSearch::Model`.
    MESSAGE
  end
end
