module Jekyll
  class RenderDiscussionTag < Liquid::Tag
    require "shellwords"

    def initialize(tag_name, text, tokens)
      super
      @text = text.shellsplit
    end

    def render(context)
      "<p class='discussion'>Discussion on <a href='#{@text[0]}'> Hacker News</a></p>"
    end
  end
end

Liquid::Template.register_tag("discussion", Jekyll::RenderDiscussionTag)
