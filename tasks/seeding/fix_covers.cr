require "file_utils"
require "../../src/filedb/nvinfo"

class CV::Seeds::FixCovers
  getter chseed : ValueMap = Nvinfo.chseed

  DIR = "_db/nvdata/_covers"
  ::FileUtils.mkdir_p("#{DIR}/_chivi")

  def fix!
    @chseed.data.each_with_index do |(bhash, seeds), idx|
      covers = {} of String => String

      if ybid = Nvinfo.yousuu.fval(bhash)
        covers["yousuu"] = ybid
      end

      seeds.each_with_object() do |x, h|
        seed, sbid = x.split("/")
        covers[seed] = sbid
      end

      bcover = nil
      mwidth = 0

      covers.each do |seed, sbid|
        next unless cover_file = cover_path(seed, sbid)
        cover_width = image_width(cover_file)

        if cover_width > mwidth
          bcover = cover_file
          mwidth = cover_width
        end
      end

      next unless bcover && Nvinfo.bcover.add(bhash, bcover.sub("#{DIR}/", ""))

      out_file = "#{DIR}/_chivi/#{bhash}.webp"
      convert_img(bcover, out_file)

      if idx % 100 == 99
        puts "- [fix_intros] <#{idx + 1}/#{@chseed.size}>".colorize.blue
        save!(mode: :upds)
      end
    end

    save!(mode: :full)
  end

  def cover_path(seed : String, sbid : String)
    {"gif", "png", "tiff", "jpg"}.each do |ext|
      file = "#{DIR}/#{seed}/#{sbid}.#{ext}"
      return file if File.exists(file)
    end

    nil
  end

  private def image_width(file : String) : Int32
    `identify -format '%w %h' "#{file}"`.split(" ").first.try(&.to_i?) || 0
  end

  private def convert_img(inp_file : String, out_file : String)
    `convert "#{inp_file}" -resize "400>x" "#{out_file}"`
  rescue err
    puts err
  end

  def save!(mode : Symbol = :full)
    Nvinfo.bcover.save!(mode: mode)
  end
end

worker = CV::Seeds::FixCovers.new
worker.fix!