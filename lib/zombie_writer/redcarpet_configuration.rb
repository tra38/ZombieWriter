require 'redcarpet'
require 'redcarpet/render_strip'

class CustomStripDownRender < Redcarpet::Render::StripDown
  def link(link, title, content)
    "#{content}"
  end
end