require "myhtml"
require "../../cutil/text_utils"

class CV::HtmlParser
  def initialize(html : String)
    @doc = Myhtml::Parser.new(html)
  end

  forward_missing_to @doc

  # find the first node matching the query, return nil otherwise
  def find(query : String)
    @doc.css(query).first?
  end

  def find_list(query : String)
    @doc.css(query).to_a
  end

  # reading attribute data of a node
  def attr(query : String, name : String, fallback : String? = "")
    find(query).try(&.attributes[name]?) || fallback
  end

  # return inner text
  def text(query : String, fallback : String? = "")
    return fallback unless node = find(query)
    text = node.inner_text
    TextUtils.fix_spaces(text).strip
  end

  # return multi text entries for each nodes
  def text_list(query : String) : Array(String)
    @doc.css(query).map(&.inner_text).to_a
  end

  # split text string to multi lines
  def text_para(query : String) : Array(String)
    TextUtils.split_html(text(query))
  end

  # extract open graph metadata
  def meta(query : String, fallback : String? = "")
    attr("meta[property=\"#{query}\"]", "content", fallback)
  end

  # split meta content to multi lines
  def meta_para(query : String) : Array(String)
    TextUtils.split_html(meta(query))
  end
end
