require 'spec_helper'

describe PgSearch do
  it "raises an error when included" do
    expect do
      Module.new { include PgSearch }
    end.to raise_error 'extend PgSearch instead of including it'
  end
end
