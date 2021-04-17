require "colorize"
require "file_utils"
require "compress/zip"

require "icu"
require "../../src/tabkv/value_map"

class CV::Zxcs::SplitText
  struct Chap
    property label : String
    property lines : Array(String)

    def initialize(@label, @lines)
    end
  end

  INP_RAR = "_db/.cache/zxcs_me/.rars"
  INP_TXT = "_db/.cache/zxcs_me/texts"

  OUT_TXT = "_db/ch_texts/origs/zxcs_me"
  OUT_IDX = "_db/ch_infos/origs/zxcs_me"

  getter csdet = ICU::CharsetDetector.new

  def extract!
    input = Dir.glob("#{INP_RAR}/*.rar").shuffle
    input.each_with_index(1) do |rar_file, idx|
      label = "#{idx}/#{input.size}"

      next unless txt_file = extract_rar!(rar_file, label: label)
      split_chaps!(txt_file, label: label)
    end
  end

  def extract_rar!(rar_file : String, label = "1/1")
    return if File.size(rar_file) < 1000

    snvid = File.basename(rar_file, ".rar")
    out_txt = "#{INP_TXT}/#{snvid}.txt"

    return out_txt if File.exists?(out_txt)
    puts "\n- <#{label}> extracting #{rar_file.colorize.blue}"

    tmp_dir = ".tmp/#{snvid}"
    FileUtils.mkdir_p(tmp_dir)

    `unrar e -o+ "#{rar_file}" #{tmp_dir}`
    inp_txt = Dir.glob("#{tmp_dir}/*.txt").first? || Dir.glob("#{tmp_dir}/*.TXT").first

    lines = read_clean(inp_txt)
    File.write(out_txt, lines.join("\n"))

    FileUtils.rm_rf(tmp_dir)
    out_txt
  rescue err
    puts err
  end

  FILE_RE_1 = /《(.+)》.+作者：(.+)\./
  FILE_RE_2 = /《(.+)》(.+)\.txt/

  private def read_clean(inp_file : String) : Array(String)
    lines = read_as_utf8(inp_file).strip.split(/\r\n?|\n/)

    if lines.first.starts_with?("===")
      3.times { lines.shift; lines.pop }

      lines.shift if lines.first.starts_with?("===")
      lines.pop if lines.last.starts_with?("===")
    end

    if match = FILE_RE_1.match(inp_file) || FILE_RE_2.match(inp_file)
      _, title, author = match
      while is_garbage?(lines.first, title, author)
        lines.shift
      end
    else
      exit(0)
    end

    while is_garbage_end?(lines.last)
      lines.pop
    end

    lines
  end

  private def read_as_utf8(txt_file : String)
    File.open(txt_file, "r") do |f|
      str = f.read_string(500)
      csm = csdet.detect(str)
      puts "- [#{File.basename txt_file}] encoding: #{csm.name} (#{csm.confidence})".colorize.green

      f.rewind
      f.set_encoding(csm.name, invalid: :skip)
      f.gets_to_end
    end
  end

  private def is_garbage?(line : String, title : String, author : String)
    return true if is_garbage_end?(line)

    case line
    when .=~(/^#{title}/),
         .=~(/《#{title}》/),
         .=~(/书名[：:]\s*#{title}/),
         .=~(/作者[：:]\s*#{author}/),
         .=~(/^分类：/),
         .=~(/^字数：：/)
      true
    else
      false
    end
  end

  private def is_garbage_end?(line : String)
    line.empty? || line.starts_with?("更多精校小说")
  end

  def split_chaps!(inp_file : String, label = "1/1")
    snvid = File.basename(inp_file, ".txt")

    out_idx = "#{OUT_IDX}/#{snvid}.tsv"
    out_dir = "#{OUT_TXT}/#{snvid}"

    return if File.exists?(out_idx)
    input = File.read(inp_file).split("\n")

    # TODO: remove this hack
    if input.first.starts_with?("字数：")
      input.shift
      while input.first.empty?
        input.shift
      end
      File.write(inp_file, input.join("\n"))
    end

    puts "\n- <#{label}> [#{INP_TXT}/#{snvid}.txt] #{input.size} lines".colorize.yellow

    return unless chaps = split_chapters(input)
    index = save_texts!(chaps, out_dir)
    File.write(out_idx, index.map(&.join('\t')).join("\n"))

    return if good_enough?(index)

    print "\nChoice (r: redo, d: delete, s: delete + exit,  else: keep): "

    STDIN.flush
    case char = STDIN.raw(&.read_char)
    when 'd', 's', 'r'
      File.delete(out_idx) if File.exists?(out_idx)
      puts "\n\n- [#{out_idx}] deleted! (choice: #{char})".colorize.red

      if char == 'r'
        split_chaps!(inp_file, label)
      elsif char == 's'
        exit(0)
      end
    else
      puts "\n\n- Entries [#{snvid}] saved!".colorize.yellow
    end
  end

  def save_texts!(input : Array(Array(String)), out_dir : String)
    chaps = format_chaps(input)

    index = [] of Tuple(Int32, String, String, String)
    FileUtils.mkdir_p(out_dir)

    chaps.each_slice(100).with_index do |slice, idx|
      out_zip = File.join(out_dir, idx.to_s.rjust(3, '0') + ".zip")

      File.open(out_zip, "w") do |file|
        Compress::Zip::Writer.open(file) do |zip|
          slice.each_with_index(1) do |chap, chidx|
            chidx = chidx + 100 * idx
            schid = chidx.to_s.rjust(4, '0')

            zip.add("#{schid}.txt", chap.lines.join('\n'))
            index << ({chidx, schid, chap.lines[0], chap.label})
          end
        end
      end
    end

    index
  end

  private def split_chapters(lines : Array(String))
    blanks_total, blanks_count, unnest_count, nested_count = 0, 0, 0, 0

    lines.each_with_index do |line, idx|
      break if idx > 200

      if line.empty?
        blanks_count += 1
        next
      end

      blanks_total += 1 if blanks_count > 1
      blanks_count = 0

      if nested?(line)
        nested_count += 1
      else
        unnest_count += 1
      end
    end

    return split_blanks(lines) if blanks_total > 1
    return split_nested(lines) if nested_count > 1 && unnest_count > 1

    puts "-- [ unsupported file format, skipping! ]".colorize.cyan
    nil
  end

  private def nested?(line : String)
    line =~ /^[　\s]{2,}/
  end

  private def split_blanks(input : Array(String))
    chaps = [] of Array(String)
    lines = [] of String

    blank = 0

    input.each do |line|
      line = line.strip

      if line.empty?
        blank += 1
        next
      end

      if blank > 1 && !lines.empty?
        chaps << lines
        lines = [] of String
      end

      blank = 0
      lines << line
    end

    chaps << lines unless lines.empty?

    puts "-- [ splited blanks: #{chaps.size} chaps ]".colorize.cyan
    chaps
  end

  private def split_nested(input : Array(String))
    chaps = [] of Array(String)
    lines = [] of String

    input.each do |line|
      next if line.empty?

      unless lines.empty? || nested?(line)
        chaps << lines
        lines = [] of String
      end

      lines << line.strip
    end

    chaps << lines unless lines.empty?

    puts "-- [ splited nested: #{chaps.size} chaps ]".colorize.cyan
    chaps
  end

  def format_chaps(input : Array(Array(String)))
    while is_intro?(input.first)
      input.shift
    end

    chaps = [] of Chap
    label = ""

    input.each do |lines|
      if lines.size == 1
        label = lines.first
      else
        chaps << Chap.new(label, lines)
      end
    end

    chaps
  end

  private def is_intro?(chap : Array(String))
    return true if chap.last =~ /^作者：/

    case chap.first
    when .includes?("简介："),
         .includes?("介绍："),
         .includes?("作品介绍"),
         .includes?("作品简介"),
         .includes?("作者简介"),
         .includes?("内容简介"),
         .includes?("内容介绍"),
         .includes?("内容说明"),
         .includes?("书籍介绍")
      true
    else
      false
    end
  end

  private def good_enough?(index : Array(Tuple(Int32, String, String, String)))
    idx, _, title, _ = index.last
    title.includes?("第#{idx}章")

    bads = [] of String

    index.each do |info|
      title = info[2]
      case title
      when "引言", "结束语", "引 子", "开始", "感言",
           .includes?("作品相关"),
           .includes?("结束感言"),
           .includes?("完本感言"),
           .includes?("完结感言"),
           .=~(/^(序|第|终卷|楔子|引子|尾声|番外|终章|末章|终曲|后记|后续)/),
           .=~(/^(最终回|最终章|终之章|大结局|人物介绍)/),
           .=~(/^\d+、/),
           .=~(/^[【\[\(]\d+[】\]\)]/),
           .=~(/^章?[零〇一二两三四五六七八九十百千+]^/)
        next
      else
        bads << title
      end
    end

    if bads.empty?
      puts "\nSeems good enough, skip checking!".colorize.green
      true
    else
      puts "\n- wrong format (#{bads.size}): ", bads.join("\n\n").colorize.red
      false
    end
  end
end

worker = CV::Zxcs::SplitText.new
worker.extract!
