require "file_utils"
require "./rm_spider"

require "../utils/time_utils"
require "../utils/text_utils"
require "../utils/path_utils"

class CV::RmNvInfo
  def self.dir(sname : String)
    PathUtils.cache_dir(sname, "infos")
  end

  def self.mkdir!(sname : String)
    ::FileUtils.mkdir_p(dir(sname))
  end

  def self.init(sname : String, snvid : String, valid = 10.years, label = "1/1")
    file = RmSpider.nvinfo_file(sname, snvid)
    link = RmSpider.nvinfo_link(sname, snvid)
    html = RmSpider.fetch(file, link, sname: sname, valid: valid, label: label)
  end

  def initialize(@sname, html : String)
    @rdoc = Myhtml::Parser.new(html)
  end

  getter author : String do
    case @sname
    when "hetushu" then node_text(".book_info a:first-child")
    when "zhwenpg" then node_text(".fontwt")
    when "69shu"   then node_text(".mu_beizhu > a[target]")
    else                meta_data("og:novel:author")
    end
  end

  getter btitle : String do
    case @sname
    when "hetushu" then node_text("h2")
    when "zhwenpg" then node_text(".cbooksingle h2")
    when "69shu"   then node_text(".weizhi > a:last-child")
    else
      meta_data("og:novel:book_name").sub(/作\s+者[：:].+$/, "")
    end
  end

  getter genres : Array(String) do
    case @sname
    when "hetushu"
      genre = node_text(".title > a:last-child").not_nil!
      tags = @rdoc.css(".tag a").map(&.inner_text).to_a
      [genre].concat(tags).uniq
    when "zhwenpg" then [] of String
    when "69shu"   then [node_text(".weizhi > a:nth-child(2)")]
    else                [meta_data("og:novel:category")]
    end
  end

  getter bintro : Array(String) do
    case @sname
    when "69shu"   then [] of String
    when "hetushu" then @rdoc.css(".intro > p").map(&.inner_text).to_a
    when "zhwenpg" then TextUtils.split_html(node_text("tr:nth-of-type(3)"))
    when "bxwxorg" then TextUtils.split_html(node_text("#intro>p:first-child"))
    else                TextUtils.split_html(meta_data("og:description"))
    end
  end

  getter bcover : String do
    case @sname
    when "hetushu"
      image_url = node_attr(".book_info img", "src")
      "https://www.hetushu.com#{image_url}"
    when "69shu"
      image_url = "/#{@snvid.to_i // 1000}/#{@snvid}/#{@snvid}s.jpg"
      "https://www.69shu.com/files/article/image/#{image_url}"
    when "zhwenpg"
      node_attr(".cover_wrapper_m img", "data-src")
    when "jx_la"
      meta_data("og:image").sub("qu.la", "jx.la")
    else
      meta_data("og:image")
    end
  end

  getter status : String do
    case @sname
    when "69shu", "zhwenpg" then "0"
    when "hetushu"
      node_attr(".book_info", "class").includes?("finish") ? "1" : "0"
    else
      meta_data("og:novel:status")
    end
  end

  getter update_int : Int64 { RmSpider.fix_mftime(update_str, @sname) }

  getter update_str : String do
    case @sname
    when "69shu"
      node_text(".mu_beizhu").sub(/.+时间：/m, "")
    when "bqg_5200"
      node_text("#info > p:last-child").sub("最后更新：", "")
    else
      meta_data("og:novel:update_time")
    end
  end

  private def node_attr(sel : String, attr : String, df : String? = "")
    find_node(sel).try(&.attributes[attr]?) || df
  end

  private def meta_data(sel : String, df : String? = "")
    node_attr("meta[property=\"#{sel}\"]", "content") || df
  end

  private def node_text(sel : String, df : String? = "")
    find_node(sel).try(&.inner_text.strip) || df
  end

  private def find_node(sel : String)
    @rdoc.css(sel).first?
  end
end
