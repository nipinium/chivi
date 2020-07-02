require "json"
require "myhtml"
require "colorize"

require "../utils/html_utils"
require "../utils/file_utils"
require "../utils/time_utils"
require "../utils/han_to_int"

# require "../kernel/book_info"
# require "../kernel/book_misc"

# require "../kernel/chap_list"

# class Volume
#   property label
#   property chaps : ChapList

#   def initialize(@label = "正文", @chaps = ChapList.new)
#   end

#   INDEX_RE = /([零〇一二两三四五六七八九十百千]+|\d+)[集卷]/

#   def index
#     if match = INDEX_RE.match(@label)
#       Utils.han_to_int(match[1])
#     else
#       0
#     end
#   end
# end

module RemoteInfo
  extend self
  DIR = File.join("var", ".cache", "books")
end

class InfoSpider
  def self.load!(seed : String, bsid : String, expiry = 6.hours, frozen = true)
    url = SpiderUtil.info_url(seed, bsid)
    file = SpiderUtil.info_path(seed, bsid)

    unless html = Utils.read_file(file, expiry)
      puts "- HIT: #{url.colorize(:blue)}"

      html = Utils.fetch_html(url)
      File.write(file, html) if frozen
    end

    new(html, seed, bsid)
  end

  def initialize(html : String, @seed : String, @bsid : String)
    @dom = Myhtml::Parser.new(html)
  end

  def get_infos!(info = VpInfo.new) : VpInfo
    if info.zh_title.empty?
      info.zh_title = get_title!
      info.zh_author = get_author!
      info.reset_uuid
    end

    unless info.cr_seedmap[@seed]?
      info.zh_intro = get_intro! if info.zh_intro.empty?
      info.add_cover(get_cover!)

      genre = get_genre!
      if info.zh_genre.empty?
        info.zh_genre = genre
      else
        info.add_tag(genre)
      end

      info.add_tags(get_tags!)
    end

    info.set_status(get_status!)

    mftime = get_mftime!
    info.set_mftime(mftime)

    if mftime > info.last_times.fetch(@seed, -1)
      info.cr_seedmap[@seed] = @bsid
      info.last_times[@seed] = mftime
    end

    info
  end

  def get_title! : String
    case @seed
    when "jx_la", "duokan8", "nofff", "rengshu", "xbiquge", "paoshu8"
      title = meta_content("og:novel:book_name")
    when "hetushu"
      title = inner_text("h2")
    when "69shu"
      title = inner_text(".weizhi > a:last-child")
    when "zhwenpg"
      title = inner_text(".cbooksingle h2")
    else
      raise "Site not supported!"
    end

    title.sub(/\(.+\)$/, "").strip
  end

  def get_author! : String
    case @seed
    when "jx_la", "duokan8", "nofff", "rengshu", "xbiquge", "paoshu8"
      author = meta_content("og:novel:author")
    when "hetushu"
      author = inner_text(".book_info a:first-child")
    when "69shu"
      author = inner_text(".mu_beizhu > a[target]")
    when "zhwenpg"
      author = inner_text(".fontwt")
    else
      raise "Site not supported!"
    end

    author.sub(/\(.+\)|.QD$/, "").strip
  end

  def get_intro! : String
    case @seed
    when "jx_la", "duokan8", "nofff", "rengshu", "xbiquge", "paoshu8"
      meta_content("og:description")
    when "hetushu"
      @dom.css(".intro > p").map(&.inner_text).join("\n")
    when "69shu"
      ""
      # TODO: extract 69shu book intro
    when "zhwenpg"
      inner_text("tr:nth-of-type(3)")
    else
      raise "Site not supported!"
    end
  end

  def get_cover! : String
    case @seed
    when "jx_la", "duokan8", "nofff", "rengshu", "xbiquge", "paoshu8"
      cover = meta_content("og:image")
      cover = cover.sub("qu.la", "jx.la") if @seed == "jx_la"
      cover
    when "hetushu"
      if img_node = @dom.css(".book_info img").first?
        url = img_node.attributes["src"]
        "https://www.hetushu.com#{url}"
      else
        ""
      end
    when "69shu"
      # TODO: extract 69shu book cover
      ""
    when "zhwenpg"
      img_node = @dom.css(".cover_wrapper_m img").first
      img_node.attributes["data-src"] || ""
    else
      raise "Site not supported!"
    end
  end

  def get_genre! : String
    case @seed
    when "jx_la", "duokan8", "nofff", "rengshu", "xbiquge", "paoshu8"
      meta_content("og:novel:category")
    when "hetushu"
      inner_text(".title > a:nth-child(2)").strip
    when "69shu"
      inner_text(".weizhi > a:nth-child(2)")
    when "zhwenpg"
      ""
    else
      raise "Site not supported!"
    end
  end

  def get_tags! : Array(String)
    if @seed == "hetushu"
      @dom.css(".tag a").map(&.inner_text).to_a
    else
      [] of String
    end
  end

  def get_status! : Int32
    case @seed
    when "jx_la", "duokan8", "nofff", "rengshu", "xbiquge", "paoshu8"
      case meta_content("og:novel:status")
      when "完成", "完本", "已经完结", "已经完本", "完结"
        1
      else
        0
      end
    when "hetushu"
      info_node = @dom.css(".book_info").first
      if info_node.attributes["class"].includes?("finish")
        1
      else
        0
      end
    when "zhwenpg", "69shu"
      0
    else
      raise "Site not supported!"
    end
  end

  EPOCH = Time.local(2010, 1, 1).to_unix_ms

  def get_mftime! : Int64
    case @seed
    when "jx_la", "duokan8", "nofff", "rengshu", "xbiquge", "paoshu8"
      text = meta_content("og:novel:update_time")
      Utils.parse_time(text).to_unix_ms
    when "hetushu"
      EPOCH
    when "69shu"
      text = inner_text(".mu_beizhu").sub(/.+时间：/m, "")
      Utils.parse_time(text).to_unix_ms
    when "zhwenpg"
      EPOCH
    else
      raise "Site not supported!"
    end
  end

  def get_chaps! : ChapList
    output = ChapList.new

    case @seed
    when "duokan8"
      @dom.css(".chapter-list a").each do |link|
        if href = link.attributes["href"]?
          csid = File.basename(href, ".html")
          title = link.inner_text
          output << ChapItem.new(csid, title)
        end
      end
    when "69shu"
      volumes = @dom.css(".mu_contain").to_a.map do |node|
        volume = Volume.new

        node.css("a").each do |link|
          if href = link.attributes["href"]?
            csid = File.basename(href)
            title = link.inner_text
            next if title.starts_with?("我要报错！")

            volume.chaps << ChapItem.new(csid, title)
          end
        end

        volume
      end

      volumes.shift if volumes.size > 1
      volumes.each { |volume| output.concat(volume.chaps) }
    when "zhwenpg"
      latest_chap = inner_text(".fontchap")
      latest_title, _ = Utils.split_title(latest_chap)

      @dom.css("#dulist a").each do |link|
        if href = link.attributes["href"]?
          csid = href.sub("r.php?id=", "")
          output << ChapItem.new(csid, link.inner_text)
        end
      end

      output.reverse! if latest_title == output.first.zh_title
    when "jx_la", "nofff", "rengshu", "xbiquge", "paoshu8"
      output = extract_volumes("#list dl")
    when "hetushu"
      output = extract_volumes("#dir")
    else
      raise "Site not supported!"
    end

    output
  end

  private def extract_volumes(selector)
    return ChapList.new unless parent = @dom.css(selector).first?

    nodes = parent.children
    volumes = [] of Volume

    nodes.each do |node|
      if node.tag_sym == :dt
        label = node.inner_text.gsub(/《.*》/, "").strip
        volumes << Volume.new(label)
      elsif node.tag_sym == :dd
        link = node.css("a").first?
        next unless link

        if href = link.attributes["href"]?
          csid = File.basename(href, ".html")
          title = link.inner_text

          volumes << Volume.new if volumes.empty?
          volumes.last.chaps << ChapItem.new(csid, title, volumes.last.label)
        end
      end
    end

    volumes.shift if volumes.first.label.includes?("最新章节")

    if @seed == "jx_la"
      order = 0

      volumes.sort_by! do |volume|
        if volume.label == "作品相关"
          {-1, 0}
        else
          index = volume.index
          order += 1 if index == 0
          {order, index}
        end
      end
    end

    output = ChapList.new
    volumes.each { |volume| output.concat(volume.chaps) }
    output
  end

  private def inner_text(css : String)
    @dom.css(css).first.inner_text.strip
  end

  private def meta_content(css : String)
    if node = @dom.css("meta[property=\"#{css}\"]").first?
      node.attributes["content"]
    else
      ""
    end
  end
end
