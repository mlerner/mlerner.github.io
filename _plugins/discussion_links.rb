module Jekyll
  class RenderDiscussionTag < Liquid::Tag
    require "shellwords"

    def initialize(tag_name, params, tokens)
      super
    end

    def lookup(context, name)
      lookup = context
      name.split(".").each { |value| lookup = lookup[value] }
      lookup
    end

    def render(context)
      hn_link = "#{lookup(context, 'page.hn')}"
      "<p class='discussion'>Discussion on <a href='#{hn_link}'> Hacker News</a></p>"
    end
  end
end

Liquid::Template.register_tag("discussion", Jekyll::RenderDiscussionTag)
