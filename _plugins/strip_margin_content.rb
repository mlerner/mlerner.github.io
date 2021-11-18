# Jekyll filter plugin to remove margin content
# Used to cleanup post content in feed.xml
# Derived from: https://gist.github.com/sumdog/99bf642024cc30f281bc

require 'nokogiri'

module Jekyll
  module StripMarginContentFilter

    def strip_margin_content(raw)
      doc = Nokogiri::HTML.fragment(raw.encode('UTF-8', :invalid => :replace, :undef => :replace, :replace => ''))

      for block in ['label', 'input', 'span'] do
        doc.css(block).each do |ele|
          ele.remove if (ele['class'] == 'marginnote' or ele['class'] == 'margin-toggle' or ele['class'] == 'sidenote' or ele['class'] == 'sidenote-number' or ele['class'] == 'margin-toggle sidenote-number')
        end
      end

      doc.inner_html

    end
  end
end

Liquid::Template.register_filter(Jekyll::StripMarginContentFilter)