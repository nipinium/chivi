require "myhtml"
require "colorize"
require "file_utils"

require "../cutil/http_utils"
require "../cutil/file_utils"
require "../cutil/time_utils"
require "../cutil/path_utils"

module CV::RmUtil
  extend self

  def fetch(file : String, link : String, sname : String, valid = 1.week, label = "1/1")
    expiry = sname == "jx_la" ? Time.utc(2010, 1, 1) : Time.utc - valid

    unless html = FileUtils.read_gz(file, expiry)
      encoding = HttpUtils.encoding_for(sname)
      html = HttpUtils.get_html(link, encoding: encoding, label: label)

      ::FileUtils.mkdir_p(File.dirname(file))
      FileUtils.save_gz(file, html)
    end

    html
  end

  def fetch_all(input : Array(Tuple(String, String)), sname : String, limit : Int32? = nil)
    limit ||= ideal_workers_count_for(sname)
    limit = input.size if limit > input.size

    channel = Channel(Nil).new(limit + 1)
    encoding = HttpUtils.encoding_for(sname)
    ::FileUtils.mkdir_p(File.dirname(input.first))

    input.each_with_index(1) do |(file, link), idx|
      channel.receive if idx > limit

      spawn do
        html = HttpUtils.get_html(link, encoding, label: "#{idx}/#{input.size}")
        File.write(file, html)
        sleep ideal_delayed_time_for(sname)
      rescue err
        puts err
      ensure
        channel.send(nil)
      end
    end

    limit.times { channel.receive }
  end

  def ideal_workers_count_for(sname : String) : Int32
    case sname
    when "zhwenpg", "shubaow"  then 1
    when "paoshu8", "bqg_5200" then 2
    when "duokan8", "69shu"    then 4
    else                            6
    end
  end

  def ideal_delayed_time_for(sname : String)
    case sname
    when "shubaow"
      Random.rand(1000..2000).milliseconds
    when "zhwenpg"
      Random.rand(500..1000).milliseconds
    when "bqg_5200"
      Random.rand(200..500).milliseconds
    else
      10.milliseconds
    end
  end

  def remote?(sname : String, power : Int32 = 4)
    case sname
    when "chivi", "local", "zxcs_me", "zadzs", "thuyvicu", "hotupub"
      false
    when "5200", "bqg_5200", "rengshu", "nofff"
      true
    when "hetushu", "biqubao", "bxwxorg", "xbiquge"
      power > 0
    when "zhwenpg", "69shu", "paoshu8", "duokan8"
      power > 1
    else
      power > 3
    end
  end

  def nvinfo_file(sname : String, snvid : String, gzip = true)
    ext = gzip ? "html.gz" : "html"
    PathUtils.cache_file(sname, "infos/#{snvid}.#{ext}")
  end

  def chinfo_file(sname : String, snvid : String, gzip = true)
    # TODO: update for 69shu
    nvinfo_file(sname, snvid, gzip: gzip)
  end

  def chtext_file(sname : String, snvid : String, schid : String, gzip = false)
    ext = gzip ? "html.gz" : "html"
    PathUtils.cache_file(sname, "texts/#{snvid}/#{schid}.#{ext}")
  end

  def nvinfo_link(sname : String, snvid : String) : String
    case sname
    when "nofff"    then "https://www.nofff.com/#{snvid}/"
    when "69shu"    then "https://www.69shu.com/#{snvid}/"
    when "jx_la"    then "https://www.jx.la/book/#{snvid}/"
    when "qu_la"    then "https://www.qu.la/book/#{snvid}/"
    when "rengshu"  then "http://www.rengshu.com/book/#{snvid}"
    when "xbiquge"  then "https://www.xbiquge.so/book/#{snvid}/"
    when "biqubao"  then "https://www.biqubao.com/book/#{snvid}/"
    when "bxwxorg"  then "https://www.bxwxorg.com/read/#{snvid}/"
    when "zhwenpg"  then "https://novel.zhwenpg.com/b.php?id=#{snvid}"
    when "hetushu"  then "https://www.hetushu.com/book/#{snvid}/index.html"
    when "duokan8"  then "http://www.duokanba.info/#{scoped(snvid)}/"
    when "paoshu8"  then "http://www.paoshu8.com/#{scoped(snvid)}/"
    when "5200"     then "https://www.5200.tv/#{scoped(snvid)}/"
    when "shubaow"  then "https://www.shubaow.net/#{scoped(snvid)}/"
    when "bqg_5200" then "https://www.biquge5200.com/#{scoped(snvid)}/"
    else                 raise "Unsupported remote source <#{sname}>!"
    end
  end

  def chinfo_link(sname : String, snvid : String) : String
    # TODO: update for 69shu
    nvinfo_link(sname, snvid)
  end

  def chtext_link(sname : String, snvid : String, schid : String) : String
    case sname
    when "nofff"    then "https://www.nofff.com/#{snvid}/#{schid}/"
    when "69shu"    then "https://www.69shu.com/txt/#{snvid}/#{schid}"
    when "jx_la"    then "https://www.jx.la/book/#{snvid}/#{schid}.html"
    when "qu_la"    then "https://www.qu.la/book/#{snvid}/#{schid}.html"
    when "rengshu"  then "http://www.rengshu.com/book/#{snvid}/#{schid}"
    when "xbiquge"  then "https://www.xbiquge.so/book/#{snvid}/#{schid}.html"
    when "biqubao"  then "https://www.biqubao.com/book/#{snvid}/#{schid}.html"
    when "bxwxorg"  then "https://www.bxwxorg.com/read/#{snvid}/#{schid}.html"
    when "zhwenpg"  then "https://novel.zhwenpg.com/r.php?id=#{schid}"
    when "hetushu"  then "https://www.hetushu.com/book/#{snvid}/#{schid}.html"
    when "duokan8"  then "http://www.duokanba.info/#{scoped(snvid)}/#{schid}.html"
    when "paoshu8"  then "http://www.paoshu8.com/#{scoped(snvid)}/#{schid}.html"
    when "5200"     then "https://www.5200.tv/#{scoped(snvid)}/#{schid}.html"
    when "shubaow"  then "https://www.shubaow.net/#{scoped(snvid)}/#{schid}.html"
    when "bqg_5200" then "https://www.biquge5200.com/#{scoped(snvid)}/#{schid}.html"
    else
      raise "Unsupported remote source <#{sname}>!"
    end
  end

  private def scoped(snvid : String)
    "#{snvid.to_i // 1000}_#{snvid}"
  end

  def fix_mftime(update_str : String, sname : String)
    return 0_i64 if sname == "hetushu" || sname == "zhwenpg"

    updated_at = TimeUtils.parse_time(update_str)
    updated_at += 12.hours if sname == "bqg_5200"

    upper_time = Time.utc
    updated_at < upper_time ? updated_at.to_unix : upper_time.to_unix
  rescue
    0_i64
  end

  def index_url(sname : String) : String
    case sname
    when "hetushu"  then "https://www.hetushu.com/book/index.php"
    when "rengshu"  then "http://www.rengshu.com/"
    when "xbiquge"  then "https://www.xbiquge.so/"
    when "biqubao"  then "https://www.biqubao.com/"
    when "5200"     then "https://www.5200.tv/"
    when "duokan8"  then "http://www.duokan8.com/"
    when "nofff"    then "https://www.nofff.com/"
    when "bqg_5200" then "https://www.biquge5200.com/"
    when "bxwxorg"  then "https://www.bxwxorg.com/"
    when "shubaow"  then "https://www.shubaow.net/"
    when "paoshu8"  then "http://www.paoshu8.com/"
    else                 raise "Unsupported source name!"
    end
  end
end
