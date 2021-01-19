require "myhtml"
require "colorize"
require "file_utils"

require "../_utils/time_utils"
require "../_utils/text_utils"
require "../_utils/http_utils"

class CV::RmInfo
  def self.init(s_name : String, s_nvid : String,
                expiry : Time = Time.utc - 1.hour, freeze : Bool = true)
    file = path_for(s_name, s_nvid)
    expiry = TimeUtils::DEF_TIME if s_name == "jx_la"

    unless html = FileUtils.read(file, expiry)
      url = url_for(s_name, s_nvid)
      html = HttpUtils.get_html(url, encoding: HttpUtils.encoding_for(s_name))
      File.write(file, html) if freeze
    end

    new(s_name, s_nvid, file, html: html)
  end

  def self.path_for(s_name : String, s_nvid : String)
    "_db/.cache/#{s_name}/infos/#{s_nvid}.html"
  end

  def self.url_for(s_name : String, s_nvid : String) : String
    case s_name
    when "nofff"    then "https://www.nofff.com/#{s_nvid}/"
    when "69shu"    then "https://www.69shu.com/#{s_nvid}/"
    when "jx_la"    then "https://www.jx.la/book/#{s_nvid}/"
    when "qu_la"    then "https://www.qu.la/book/#{s_nvid}/"
    when "rengshu"  then "http://www.rengshu.com/book/#{s_nvid}"
    when "xbiquge"  then "https://www.xbiquge.cc/book/#{s_nvid}/"
    when "zhwenpg"  then "https://novel.zhwenpg.com/b.php?id=#{s_nvid}"
    when "hetushu"  then "https://www.hetushu.com/book/#{s_nvid}/index.html"
    when "duokan8"  then "http://www.duokan8.com/#{prefixed(s_nvid)}/"
    when "paoshu8"  then "http://www.paoshu8.com/#{prefixed(s_nvid)}/"
    when "5200"     then "https://www.5200.tv/#{prefixed(s_nvid)}/"
    when "shubaow"  then "https://www.shubaow.net/#{prefixed(s_nvid)}/"
    when "bqg_5200" then "https://www.biquge5200.com/#{prefixed(s_nvid)}/"
    else                 raise "Unsupported remote source <#{s_name}>!"
    end
  end

  private def self.prefixed(s_nvid : String)
    "#{s_nvid.to_i // 1000}_#{s_nvid}"
  end

  getter s_name : String
  getter s_nvid : String
  getter c_file : String

  def initialize(@s_name, @s_nvid, @c_file, html = File.read(@c_file))
    @rdoc = Myhtml::Parser.new(html)
  end

  def cached?(expiry = Time.utc - 6.months)
    FileUtils.recent?(@c_file, expiry)
  end

  def uncache!
    File.delete(@c_file) if File.exists?(@c_file)
  end

  getter author : String do
    case @s_name
    when "hetushu" then node_text(".book_info a:first-child")
    when "zhwenpg" then node_text(".fontwt")
    when "69shu"   then node_text(".mu_beizhu > a[target]")
    else                meta_data("og:novel:author")
    end
  end

  getter btitle : String do
    case @s_name
    when "hetushu" then node_text("h2")
    when "zhwenpg" then node_text(".cbooksingle h2")
    when "69shu"   then node_text(".weizhi > a:last-child")
    else                meta_data("og:novel:book_name")
    end
  end

  getter genres : Array(String) do
    case @s_name
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
    case @s_name
    when "69shu"   then [] of String
    when "hetushu" then @rdoc.css(".intro > p").map(&.inner_text).to_a
    when "zhwenpg" then TextUtils.split_html(node_text("tr:nth-of-type(3)"))
    else                TextUtils.split_html(meta_data("og:description"))
    end
  end

  getter bcover : String do
    case @s_name
    when "hetushu"
      image_url = node_attr(".book_info img", "src")
      "https://www.hetushu.com#{image_url}"
    when "69shu"
      image_url = "/#{@s_nvid.to_i // 1000}/#{@s_nvid}/#{@s_nvid}s.jpg"
      "https://www.69shu.com/files/article/image/#{image_url}"
    when "zhwenpg"
      node_attr(".cover_wrapper_m img", "data-src")
    when "jx_la"
      meta_data("og:image").sub("qu.la", "jx.la")
    else
      meta_data("og:image")
    end
  end

  getter status_str : String do
    case @s_name
    when "69shu", "zhwenpg" then "连载"
    when "hetushu"
      node_attr(".book_info", "class").includes?("finish") ? "完本" : "连载"
    else meta_data("og:novel:status")
    end
  end

  getter status_int : Int32 do
    case status = status_str
    when "连载", "连载中....", "连载中", "新书上传",
         "情节展开", "精彩纷呈", "接近尾声",
         ""
      0
    when "完成", "完本", "已经完结", "已经完本",
         "完结", "已完结", "此书已完成", "已完本",
         "全本", "完结申请"
      1
    when "暂停", "暂 停", "暂　停"
      2
    else
      puts "<#{@s_name}/#{@s_nvid}> UNKNOWN STATUS: `#{status}`".colorize.red
      0
    end
  end

  getter updated_at : Time do
    return Time.utc(2020, 1, 1) if @s_name == "zhwenpg" || @s_name == "hetushu"
    return TimeUtils.parse_time(update_str) unless update_str.empty?
    puts "- ERROR: <#{RmInfo.url_for(@s_name, @s_nvid)}> missing time!"
    TimeUtils::DEF_TIME
  end

  getter update_str : String do
    case @s_name
    when "69shu"
      node_text(".mu_beizhu").sub(/.+时间：/m, "")
    when "bqg_5200"
      node_text("#info > p:last-child").sub("最后更新：", "")
    else
      meta_data("og:novel:update_time")
    end
  end

  getter last_chid : String do
    case @s_name
    when "hetushu" then extract_last_chid("#dir :last-child a:last-of-type")
    when "69shu"   then extract_last_chid(".mulu_list:first-of-type a:first-child")
    when "zhwenpg" then extract_last_chid(".fontwt0 + a")
    else                extract_last_chid_by_meta
    end
  end

  private def extract_last_chid(sel : String)
    node = find_node(sel).not_nil!
    extract_chid(node.attributes["href"])
  end

  private def extract_last_chid_by_meta
    href = meta_data("og:novel:latest_chapter_url").not_nil!
    @s_name != "bqg_5200" ? extract_chid(href) : File.basename(href, ".htm")
  end

  alias Chlist = Array(Array(String))

  getter chap_list : Chlist do
    case @s_name
    when "69shu"   then extract_69shu_chlist
    when "zhwenpg" then extract_zhwenpg_chlist
    when "duokan8" then extract_duokan8_chlist
    when "hetushu" then extract_generic_chlist("#dir")
    when "5200"    then extract_generic_chlist(".listmain > dl")
    else                extract_generic_chlist("#list > dl")
    end
  end

  def extract_generic_chlist(sel : String)
    chlist = Chlist.new
    return chlist unless node = find_node(sel)

    label = ""

    node.children.each do |node|
      case node.tag_sym
      when :dt
        label = node.inner_text.gsub(/《.*》/, "").strip
        label = "" if label == "正文"
      when :dd
        next if label.includes?("最新章节")
      end

      next unless link = node.css("a").first?
      href, text = link.attributes["href"], link.inner_text

      title, label = TextUtils.format_title(text, label)
      chlist << [extract_chid(href), title, label] unless title.empty?
    rescue err
      puts err.colorize.red
    end

    chlist
  end

  def extract_69shu_chlist
    chlist = Chlist.new
    return chlist unless nodes = @rdoc.css(".mu_contain").to_a

    nodes.shift if nodes.size > 0
    label = ""

    nodes.each do |mulu|
      mulu.children.each do |node|
        case node.tag_sym
        when :h2
          label = node.inner_text.strip
          label = "" if label == "正文"
        when :ul
          node.css("a").each do |link|
            title = link.inner_text
            next if title.starts_with?("我要报错！")
            href = link.attributes["href"]
            chlist << [extract_chid(href), title, label] unless title.empty?
          end
        end
      end
    end

    chlist
  end

  def extract_zhwenpg_chlist
    output = Chlist.new

    @rdoc.css(".clistitem > a").each do |link|
      href = link.attributes["href"]
      title, label = TextUtils.format_title(link.inner_text)
      output << [extract_chid(href), title, label] unless title.empty?
    end

    # check if the list is in correct orlder
    output.reverse! if last_chid == output[0].first

    output
  end

  private def extract_duokan8_chlist
    chlist = Chlist.new

    @rdoc.css(".chapter-list a").each do |link|
      next unless href = link.attributes["href"]?
      title, label = TextUtils.format_title(link.inner_text)
      chlist << [extract_chid(href), title, label] unless title.empty?
    end

    chlist
  end

  private def extract_chid(href : String)
    case @s_name
    when "69shu"   then File.basename(href)
    when "zhwenpg" then href.sub("r.php?id=", "")
    else                File.basename(href, ".html")
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