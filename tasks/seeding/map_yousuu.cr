require "file_utils"

require "../../src/filedb/nvinit/ys_info"
require "./_info_seed.cr"

class CV::Seeds::MapYousuu
  getter source_url : ValueMap { ValueMap.new(@seeding.map_path("source_url")) }
  getter count_word : ValueMap { ValueMap.new(@seeding.map_path("count_word")) }
  getter count_crit : ValueMap { ValueMap.new(@seeding.map_path("count_crit")) }
  getter count_list : ValueMap { ValueMap.new(@seeding.map_path("count_list")) }

  def initialize
    @seeding = InfoSeed.new("yousuu")
  end

  def init!
    input = Dir.glob("_db/.cache/yousuu/infos/*.json").sort_by do |file|
      File.basename(file, ".json").to_i
    end

    puts "- Input: #{input.size} files.".colorize.cyan

    input.each_with_index do |file, idx|
      sbid = File.basename(file, ".json")

      access_tz = File.info(file).modification_time.to_unix
      next if @seeding.access_tz.ival_64(sbid) >= access_tz
      @seeding.access_tz.add(sbid, access_tz)

      next unless info = YsInfo.load(file)

      @seeding._index.add(sbid, [info.title, info.author])

      @seeding.bgenre.add(sbid, [info.genre].concat(info.tags_fixed))
      @seeding.bcover.add(sbid, info.cover_fixed)

      @seeding.status.add(sbid, info.status)
      @seeding.shield.add(sbid, info.shielded ? "1" : "0")

      @seeding.rating.add(sbid, [info.voters.to_s, info.rating.to_s])
      @seeding.update_tz.add(sbid, info.updated_at.to_unix)

      @seeding.set_intro(sbid, info.intro)

      source_url.add(sbid, info.source)
      count_word.add(sbid, info.word_count)
      count_crit.add(sbid, info.crit_count)
      count_list.add(sbid, info.addListTotal)

      if idx % 100 == 99
        puts "- [yousuu] <#{idx + 1}/#{input.size}>".colorize.cyan
        save!(mode: :upds)
      end
    rescue err
      puts "- error loading [#{sbid}]: #{err}".colorize.red
    end

    save!(mode: :full)
  end

  private def save!(mode : Symbol = :full)
    @seeding.save!(mode: mode)

    @source_url.try(&.save!(mode: mode))
    @count_word.try(&.save!(mode: mode))
    @count_crit.try(&.save!(mode: mode))
    @count_list.try(&.save!(mode: mode))
  end

  def seed!(mode : Symbol = :best)
    authors = Set(String).new(Nvinfo.author.vals.map(&.first))
    checked = Set(String).new

    input = @seeding.rating.data.to_a.map { |k, v| {k, v[0].to_i, v[1].to_i} }
    input.sort_by! { |a, b, c| -b }

    input.each_with_index do |(sbid, voters, rating), idx|
      btitle, author = @seeding._index.get(sbid).not_nil!
      btitle, author = Nvinfo::Utils.fix_nvname(btitle, author)

      nvname = "#{btitle}\t#{author}"
      next if checked.includes?(nvname)
      checked.add(nvname)

      if (voters > 10 && rating >= 3.75) || authors.includes?(author) || popular?(sbid)
        authors.add(author)

        bhash, existed = @seeding.upsert!(sbid)
        Nvinfo.set_score(bhash, voters, rating)

        origin = source_url.fval(sbid)
        Nvinfo.origin.add(bhash, origin) if origin && !origin.empty?

        Nvinfo.yousuu.add(bhash, sbid)
        Nvinfo.shield.add(bhash, @seeding.shield.fval(sbid) || "0")
      end

      if idx % 100 == 99
        puts "- [yousuu] <#{idx + 1}/#{input.size}>".colorize.blue
        Nvinfo.save!(mode: :upds)
      end
    end

    Nvinfo.save!(mode: :full)
  end

  def popular?(sbid : String)
    return true if count_crit.fval(sbid).try(&.to_i.>= 5)
    return true if count_list.fval(sbid).try(&.to_i.>= 3)
    false
  end
end

worker = CV::Seeds::MapYousuu.new
worker.init! unless ARGV.includes?("-init")
worker.seed!