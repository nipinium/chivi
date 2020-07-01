require "json"
require "colorize"
require "file_utils"
require "../utils/text_utils"

require "./chap_item"

class BookMisc::Data
  # contain book optional infomation

  include JSON::Serializable

  property uuid = ""

  property intro_zh = ""
  property intro_vi = ""

  property cover_links = [] of String
  property local_cover = ""

  property status = 0_i32
  property shield = 0_i32
  property mftime = 0_i64

  property yousuu_link = ""
  property origin_link = ""

  # seed types: 0 => remote, 1 => manual, 2 => locked
  property seed_types = {} of String => Int32
  property seed_sbids = {} of String => String
  property seed_lasts = {} of String => ChapItem

  property word_count = 0_i32
  property crit_count = 0_i32

  @[JSON::Field(ignore: true)]
  @changed = false

  def initialize(@uuid : String)
    @changed = true
  end

  def changed?
    @changed
  end

  def intro_zh=(intro : String)
    return if intro == @intro_zh
    @changed = true
    @intro_zh = intro
  end

  def intro_vi=(intro : String)
    return if intro == @intro_vi
    @changed = true
    @intro_vi = intro
  end

  def add_cover(cover : String)
    return if cover.empty? || @cover_links.includes?(cover)
    @changed = true
    @cover_links << cover
  end

  def status=(status : Int32) : Void
    return if status <= @status
    @changed = true
    @status = status
  end

  def set_seed(seed : String, sbid : String, type = 0)
    return if seed.empty? || sbid.empty?

    @seed_sbids[seed] = sbid
    @seed_types[seed] = type
    @seed_lasts[seed] ||= ChapItem.new
  end

  def mftime=(mftime : Int64) : Void
    return if @mftime >= mftime
    changed = true
    @mftime = mftime
  end

  def to_s(io : IO)
    to_json(io)
  end

  def save!(file = BookMisc.path(@uuid)) : self
    File.write(file, self)
    # puts "- <book_misc> [#{file.colorize(:cyan)}] saved."

    self
  end

  # class methods

end

class BookMiscNotFound < Exception
  def initialize(uuid : String)
    super("Book misc uuid [#{uuid}] does not exit")
  end
end

module BookMisc
  extend self

  DIR = File.join("var", "appcv", "book_miscs")
  FileUtils.mkdir_p(DIR)

  def path(uuid : String)
    File.join(DIR, "#{uuid}.json")
  end

  def exist?(uuid : String)
    File.exists?(path(uuid))
  end

  def glob_dir
    Dir.glob(File.join(DIR, "*.json"))
  end

  CACHE = {} of String => Data

  def load_all! : Void
    files = glob_dir
    files.each do |file|
      load! File.basename(file, ".json")
    end
    puts "- <book_misc> loaded `#{files.size.colorize(:cyan)}` entries."
  end

  def each(load_all : Bool = false)
    load_all! if load_all

    CACHE.each_value do |misc|
      yield misc
    end
  end

  def get!(uuid : String) : Data
    get(uuid) || raise BookMiscNotFound.new(uuid)
  end

  def get(uuid : String)
    CACHE[uuid] ||= begin
      file = path(uuid)
      return unless File.exists?(file)
      load!(file)
    end
  end

  def get_or_create!(uuid : String) : Data
    unless misc = get(uuid)
      misc = Data.new(uuid)
      CACHE[uuid] = misc
    end

    misc
  end

  def load!(file : String)
    Data.from_json(File.read(file))
  end

  def save!(misc : Data, file = path(misc.uuid)) : Void
    File.write(file, misc)
    puts "- <book_misc> [#{file.colorize(:cyan)}] saved."
  end
end
