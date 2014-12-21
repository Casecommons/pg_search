if ENV["TRAVIS"]
  begin
    require 'coveralls'
    Coveralls.wear!
  rescue LoadError # rubocop:disable Lint/HandleExceptions
  end
end
