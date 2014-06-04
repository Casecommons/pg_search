if ENV["TRAVIS"]
  begin
    require 'coveralls'
    Coveralls.wear!
  rescue LoadError
  end
end
