require File.expand_path(File.dirname(__FILE__)) + '/helper'

class TestAdapter < Premailer::TestCase

  def test_default_to_best_available
    require 'nokogiri'
    assert_equal 'Premailer::Adapter::Nokogiri', Premailer::Adapter.use.name
  end

  def test_settable_via_symbol
    Premailer::Adapter.use = :nokogiri
    assert_equal 'Premailer::Adapter::Nokogiri', Premailer::Adapter.use.name
  end

  def test_adapters_are_findable_by_symbol
    assert_equal 'Premailer::Adapter::Nokogiri', Premailer::Adapter.find(:nokogiri).name
  end

  def test_adapters_are_findable_by_class
    assert_equal 'Premailer::Adapter::Nokogiri', Premailer::Adapter.find(Premailer::Adapter::Nokogiri).name
  end

  def test_raises_argument_error
    assert_raises(ArgumentError, "Invalid adapter: unknown") {
      Premailer::Adapter.find(:unknown)
    }
  end

end
