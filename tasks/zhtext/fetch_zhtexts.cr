# require "json"
# require "colorize"
# require "file_utils"
# require "option_parser"

# require "../../src/appcv/nv_info"

# require "../../src/appcv/ch_info"
# require "../../src/appcv/ch_text"
# require "../../src/seeds/rm_chtext"

# class CV::PreloadBook
#   def self.crawl!(seed : String, snvid : String, threads = 4, label = "1/1")
#     new(seed, snvid, label: label).crawl!(threads)
#   end

#   getter schids : Array(String)

#   def initialize(@sname : String, @snvid : String, label = "1/1")
#     @chinfo = Chinfo.new("generic", @sname, @snvid)
#     @schids = @chinfo.missing_schids

#     puts "- <#{label}> [#{@sname}/#{@snvid}] #{@schids.size} entries".colorize.light_cyan
#   end

#   def crawl!(threads = 4)
#     return if @schids.empty?

#     ::FileUtils.mkdir_p(@chinfo.chaps.root_dir)
#     threads = @schids.size if threads > @schids.size

#     channel = Channel(Nil).new(threads)
#     @schids.each_with_index(1) do |schid, idx|
#       channel.receive if idx > threads

#       spawn do
#         label = "#{idx}/#{@schids.size}"
#         chtext = ChText.new("_", @sname, @snvid, )
#         remote = RmChtext.new(@sname, @snvid, schid, label: label)
#         remote.save!(File.join(@chinfo.chaps.root_dir, "#{schid}.txt"))
#       rescue err
#         puts "- <#{label}> [#{@sname}/#{@snvid}/#{schid}]: #{err.message}".colorize.red
#       ensure
#         channel.send(nil)
#       end
#     end

#     threads.times { channel.receive }
#     @chinfo.chaps.compress!(mode: :archive) # save texts to zip files
#   end
# end

# class CV::PreloadSeed
#   getter snvids = [] of String

#   def initialize(@sname : String, fetch_all : Bool = false)
#     input = [] of Tuple(String, Int32)

#     NvChseed.load(sname).data.each do |bhash, value|
#       next unless fetch_all || should_crawl?(bhash)
#       input << {value.first, -NvValues.weight.ival(bhash)}
#     end

#     @snvids = input.sort_by(&.[1]).map(&.[0])
#   end

#   SORT_ORDER = {
#     "hetushu", "rengshu", "bxwxorg", "biqubao",
#     "xbiquge", "paoshu8", "5200", "bqg_5200",
#     "shubaow", "duokan8", "zhwenpg", "nofff",
#   }

#   def should_crawl?(bhash : String)
#     snames = NvChseed._index.get(bhash) || [] of String
#     return false if snames.empty?

#     case @sname
#     when "zhwenpg", "shubaow", "paoshu8", "nofff", "bqg_5200", "5200"
#       return false if snames.size > 1
#     else
#       snames = snames.sort_by { |sname| SORT_ORDER.index(sname) || 99 }
#     end

#     snames.first == @sname
#   end

#   def crawl!(threads = 4)
#     puts "[#{@sname}: #{@snvids.size} entries]".colorize.green.bold

#     @snvids.each_with_index(1) do |snvid, idx|
#       PreloadBook.crawl!(@sname, snvid, threads, label: "#{idx}/#{@snvids.size}")
#     end
#   end

#   def self.crawl!(argv = ARGV)
#     sname = "zhwenpg"

#     threads = RmSpider.ideal_workers_count_for(sname)
#     fetch_all = sname == "hetushu"

#     OptionParser.parse(argv) do |parser|
#       parser.banner = "Usage: fetch_zhtexts [arguments]"
#       parser.on("-s SNAME", "Seed name") { |x| sname = x }
#       parser.on("-a", "Fetch all") { |x| fetch_all = !!x }
#       parser.on("-t THREADS", "Parallel workers") { |x| threads = x.to_i }

#       parser.invalid_option do |flag|
#         STDERR.puts "ERROR: `#{flag}` is not a valid option."
#         STDERR.puts parser
#         exit(1)
#       end
#     end

#     puts "[#{sname} - #{fetch_all} - #{threads}]".colorize.cyan.bold
#     PreloadSeed.new(sname, fetch_all).crawl!(threads: threads)
#   end
# end

# CV::PreloadSeed.crawl!(ARGV)