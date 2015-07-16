# -*- encoding: UTF-8 -*-

require File.expand_path(File.dirname(__FILE__)) + '/helper'

class TestPremailer < Premailer::TestCase
  def test_special_characters_nokogiri
    html = 	'<p>cédille c&eacute; & garçon gar&#231;on à &agrave; &nbsp; &amp; &copy;</p>'
    premailer = Premailer.new(html, :with_html_string => true, :adapter => :nokogiri)
  	premailer.to_inline_css
    assert_equal special_chars_nokogiri, premailer.processed_doc.at('p').inner_html
  end

  def test_special_characters_nokogiri_remote
    remote_setup('chars.html', :adapter => :nokogiri)
  	@premailer.to_inline_css
    assert_equal special_chars_nokogiri, @premailer.processed_doc.at('p').inner_html
  end

  #def test_cyrillic_nokogiri_remote
  #  if RUBY_VERSION =~ /1.9/
  #    remote_setup('iso-8859-5.html', :adapter => :nokogiri) #, :encoding => 'iso-8859-5')
  #  	@premailer.to_inline_css
  #    assert_equal Encoding.find('ISO-8859-5'), @premailer.processed_doc.at('p').inner_html.encoding
  #  end
  #end

  # TODO: this passes when run from rake but not when run from:
  #  ruby -Itest test/test_premailer.rb -n test_special_characters_hpricot
  if RUBY_PLATFORM != 'java'
    def test_special_characters_hpricot
      html = 	'<p>cédille c&eacute; & garçon gar&#231;on à &agrave; &nbsp; &amp;</p>'
      premailer = Premailer.new(html, :with_html_string => true, :adapter => :hpricot)
      premailer.to_inline_css
      assert_equal 'cédille c&eacute; & garçon gar&#231;on à &agrave; &nbsp; &amp;', premailer.processed_doc.at('p').inner_html
    end
  end

  def test_detecting_html
    adapters.each do |adapter|
      remote_setup('base.html', :adapter => adapter)
      assert !@premailer.is_xhtml?
    end
  end

  def test_detecting_xhtml
    adapters.each do |adapter|
      remote_setup('xhtml.html', :adapter => adapter)
      assert @premailer.is_xhtml?
    end
  end

  def test_self_closing_xhtml_tags
    adapters.each do |adapter|
      remote_setup('xhtml.html', :adapter => adapter)
      assert_match /<br[\s]*\/>/, @premailer.to_s
      assert_match /<br[\s]*\/>/, @premailer.to_inline_css
    end
  end

  def test_non_self_closing_html_tags
    adapters.each do |adapter|
      remote_setup('html4.html', :adapter => adapter)
      assert_match /<br>/, @premailer.to_s
      assert_match /<br>/, @premailer.to_inline_css
    end
  end

  def test_mailtos_with_query_strings
    html = <<END_HTML
    <html>
		<a href="mailto:info@example.com?subject=Programmübersicht&amp;body=Lorem ipsum dolor sit amet.">Test</a>
		</html>
END_HTML

    qs = 'testing=123'

    adapters.each do |adapter|
		  premailer = Premailer.new(html, :with_html_string => true, :link_query_string => qs, :adapter => adapter)
		  premailer.to_inline_css
	    assert_no_match /testing=123/, premailer.processed_doc.search('a').first.attributes['href'].to_s
	  end
  end

  def test_escaping_strings
    local_setup

    str = %q{url("/images/test.png");}
    assert_equal("url(\'/images/test.png\');", Premailer.escape_string(str))
  end

  def test_preserving_ignored_style_elements
    adapters.each do |adapter|
      local_setup('ignore.html', :adapter => adapter)

      assert_nil @doc.at('h1')['style']
    end
  end

  def test_preserving_ignored_link_elements
    adapters.each do |adapter|
      local_setup('ignore.html', :adapter => adapter)

      assert_nil @doc.at('body')['style']
    end
  end

  def test_importing_local_css
    # , :hpricot
    [:nokogiri].each do |adapter|
      local_setup('base.html', :adapter => adapter)

      # noimport.css (print stylesheet) sets body { background } to red
      assert_no_match /red/, @doc.at('body').attributes['style'].to_s

      # import.css sets .hide to { display: none }
      assert_match /display: none/, @doc.at('#hide01').attributes['style'].to_s
    end
  end

  def test_importing_remote_css
    adapters.each do |adapter|
      remote_setup('base.html', :adapter => adapter)

      # noimport.css (print stylesheet) sets body { background } to red
      assert_no_match /red/, @doc.at('body')['style']

      # import.css sets .hide to { display: none }
      assert_match /display: none/, @doc.at('#hide01')['style']
    end
  end

  def test_importing_css_as_string
    files_base = File.expand_path(File.dirname(__FILE__)) + '/files/'

    css_string = IO.read(File.join(files_base, 'import.css'))

    adapters.each do |adapter|
      premailer = Premailer.new(File.join(files_base, 'no_css.html'), {:css_string => css_string, :adapter => adapter})
      premailer.to_inline_css
      @doc = premailer.processed_doc

      # import.css sets .hide to { display: none }
      assert_match /display: none/, @doc.at('#hide01')['style']
    end
  end

  def test_local_remote_check
    assert Premailer.local_data?( StringIO.new('a') )
    assert Premailer.local_data?( '/path/' )
    assert !Premailer.local_data?( 'http://example.com/path/' )

    # the old way is deprecated but should still work
    premailer = Premailer.new( StringIO.new('a') )
    assert premailer.local_uri?( '/path/' )
  end

  def test_initialize_can_accept_io_object
    adapters.each do |adapter|
      io = StringIO.new('hi mom')
      premailer = Premailer.new(io, :adapter => adapter)
      assert_match /hi mom/, premailer.to_inline_css
    end
  end

  def test_initialize_can_accept_html_string
    adapters.each do |adapter|
      premailer = Premailer.new('<p>test</p>', :with_html_string => true, :adapter => adapter)
      assert_match /test/, premailer.to_inline_css
    end
  end

  def test_initialize_no_escape_attributes_option
    html = <<END_HTML
    <html> <body>
    <a id="google" href="http://google.com">Google</a>
    <a id="noescape" href="{{link_url}}">Link</a>
		</body> </html>
END_HTML

    adapters.each do |adapter|
    	pm = Premailer.new(html, :with_html_string => true, :adapter => adapter, :escape_url_attributes => false)
      pm.to_inline_css
      doc = pm.processed_doc
      assert_equal doc.at('#google')['href'], 'http://google.com'
      assert_equal doc.at('#noescape')['href'], '{{link_url}}'
    end
  end

  def test_remove_ids
    html = <<END_HTML
    <html> <head> <style type="text/css"> #remove { color:blue; } </style> </head>
    <body>
		<p id="remove"><a href="#keep">Test</a></p>
		<p id="keep">Test</p>
		</body> </html>
END_HTML

    adapters.each do |adapter|
  		pm = Premailer.new(html, :with_html_string => true, :remove_ids => true, :adapter => adapter)
      pm.to_inline_css
      doc = pm.processed_doc
  	  assert_nil doc.at('#remove')
  	  assert_nil doc.at('#keep')
  	  hashed_id = doc.at('a')['href'][1..-1]
  	  assert_not_nil doc.at("\##{hashed_id}")
  	end
  end

  def test_reset_contenteditable
    html = <<-___
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    <html> <head> <style type="text/css"> #remove { color:blue; } </style> </head>
    <body>
    <div contenteditable="true" id="editable"> Test </div>
    </body> </html>
    ___
    adapters.each do |adapter|
  		pm = Premailer.new(html, :with_html_string => true, :reset_contenteditable => true, :adapter => adapter)
      pm.to_inline_css
      doc = pm.processed_doc
  	  assert_nil doc.at('#editable')['contenteditable'],
        "#{adapter}: contenteditable attribute not removed"
  	end
  end

  def test_carriage_returns_as_entities
    html = <<-html
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    <html>
    <body>\n\r<p>test</p>\n\r<p>test</p>
    </body></html>
    html

    regex = jruby? ? /\n\n/ : /\n\r/

    adapters.each do |adapter|
      pm = Premailer.new(html, :with_html_string => true, :adapter => adapter)
      assert_match regex, pm.to_inline_css
    end
  end


  def test_advanced_selectors
    remote_setup('base.html', :adapter => :nokogiri)
    assert_match /italic/, @doc.at('h2 + h3')['style']
    assert_match /italic/, @doc.at('p[attr~=quote]')['style']
    assert_match /italic/, @doc.at('ul li:first-of-type')['style']

    if !jruby?
      remote_setup('base.html', :adapter => :hpricot)
      assert_match /italic/, @doc.at('p[@attr~="quote"]')['style']
      assert_match /italic/, @doc.at('ul li:first-of-type')['style']
    end
  end

  def test_premailer_related_attributes
    html = <<END_HTML
    <html> <head> <style>table { -premailer-width: 500; } td { -premailer-height: 20}; </style>
    <body>
		<table> <tr> <td> Test </td> </tr> </table>
		</body> </html>
END_HTML

    adapters.each do |adapter|
  		pm = Premailer.new(html, :with_html_string => true, :adapter => adapter)
      pm.to_inline_css
      doc = pm.processed_doc
  	  assert_equal '500', doc.at('table')['width']
  	  assert_equal '20', doc.at('td')['height']
  	end
  end

  def test_include_link_tags_option
    local_setup('base.html', :adapter => :nokogiri, :include_link_tags => true)
    assert_match /1\.231/, @doc.at('body').attributes['style'].to_s
    assert_match /display: none/, @doc.at('.hide').attributes['style'].to_s

    local_setup('base.html', :adapter => :nokogiri, :include_link_tags => false)
    assert_no_match /1\.231/, @doc.at('body').attributes['style'].to_s
    assert_match /display: none/, @doc.at('.hide').attributes['style'].to_s
  end

  def test_include_style_tags_option
    local_setup('base.html', :adapter => :nokogiri, :include_style_tags => true)
    assert_match /1\.231/, @doc.at('body').attributes['style'].to_s
    assert_match /display: block/, @doc.at('#iphone').attributes['style'].to_s

    local_setup('base.html', :adapter => :nokogiri, :include_style_tags => false)
    assert_match /1\.231/, @doc.at('body').attributes['style'].to_s
    assert_no_match /display: block/, @doc.at('#iphone').attributes['style'].to_s
  end

  def test_input_encoding
    html_special_characters = "Ää, Öö, Üü"
    html = "<p>#{html_special_characters}</p>"
    pm = Premailer.new(html, :with_html_string => true, :adapter => :nokogiri, :input_encoding => "UTF-8")
    assert_equal html_special_characters, pm.processed_doc.at('p').text
  end

  # output_encoding option should return HTML Entities when set to US-ASCII
  def test_output_encoding
    html_special_characters = "©"
    html_entities_characters = "&#169;"
    pm = Premailer.new(html_special_characters, :output_encoding => "US-ASCII", :with_html_string => true, :adapter => :nokogiri, :input_encoding => "UTF-8");
    assert_equal html_special_characters, pm.processed_doc.at('body').text
  end

  def test_meta_encoding_downcase
    meta_encoding = '<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">'
    http_equiv = Regexp.new(Regexp.escape('http-equiv="Content-Type"'), Regexp::IGNORECASE)
    content = Regexp.new(Regexp.escape('content="text/html; charset=utf-8"'), Regexp::IGNORECASE)
    pm = Premailer.new(meta_encoding, :with_html_string => true, :adapter => :nokogiri, :input_encoding => "utf-8")
    doc = pm.to_inline_css
    assert_match http_equiv, doc
    assert_match content, doc
  end

  def test_meta_encoding_upcase
    meta_encoding = '<meta http-equiv="Content-Type" content="text/html; charset=utf-8">'
    http_equiv = Regexp.new(Regexp.escape('http-equiv="Content-Type"'), Regexp::IGNORECASE)
    content = Regexp.new(Regexp.escape('content="text/html; charset=UTF-8"'), Regexp::IGNORECASE)
    pm = Premailer.new(meta_encoding, :with_html_string => true, :adapter => :nokogiri, :input_encoding => "UTF-8")
    doc = pm.to_inline_css
    assert_match http_equiv, doc
    assert_match content, doc
  end

  def test_htmlentities
    html_entities = "&#8217;"
    pm = Premailer.new(html_entities, :with_html_string => true, :adapter => :nokogiri, :replace_html_entities => true)
    assert_equal html_entities, pm.processed_doc.css('body').text
  end

  # If a line other than the first line in the html string begins with a URI
  # Premailer should not identify the html string as a URI. Otherwise the following
  # exception would be raised: ActionView::Template::Error: bad URI(is not URI?)
  def test_line_starting_with_uri_in_html_with_linked_css
    files_base = File.expand_path(File.dirname(__FILE__)) + '/files/'
    html_string = IO.read(File.join(files_base, 'html_with_uri.html'))

    assert_nothing_raised do
      premailer = Premailer.new(html_string, :with_html_string => true)
      premailer.to_inline_css
    end
  end

  def test_empty_html_nokogiri
    html = ""
    css = "a:hover {color:red;}"

    assert_nothing_raised do
      pm = Premailer.new(html, :with_html_string => true, :css_string => css, :adapter => :nokogiri)
      pm.to_inline_css
    end
  end

  def test_media_queries_when_keep_unmergable_in_head_flag_is_true
    html = <<-___
    <!DOCTYPE html>
    <html><head>
      <style type="text/css">
        #remove { color:blue; }
        @media only screen and (max-width:480px) { table { color:red; } }
      </style>
    </head>
    <body>
    <div id="editable"> Test </div>
    </body> </html>
    ___
    adapters.each do |adapter|
      pm = Premailer.new(html, :with_html_string => true, :adapter => adapter, keep_unmergable_in_head: true)
      pm.to_inline_css
      doc = pm.processed_doc
      refute_nil doc.at('head > style')
      asserted =
        if adapter == :hpricot
          doc.at('head > style').html
        elsif adapter == :nokogiri
          doc.at('head > style').text
        end
      assert_equal(asserted, "\n@media only screen and (max-width:480px) {\n  table {\n    color: red;\n  }\n}\n")
    end
  end

end
