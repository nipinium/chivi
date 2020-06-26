require "json"
require "colorize"
require "file_utils"

class BookOrderIndex
  ROOT  = File.join("data", "books", "indexes", "orders")
  TYPES = {"access", "update", "rating", "points"}

  def self.setup!
    FileUtils.mkdir_p(ROOT)
  end

  @@access : BookOrderIndex?
  @@update : BookOrderIndex?
  @@rating : BookOrderIndex?
  @@weight : BookOrderIndex?

  def self.load!(type : String)
    case type
    when "access" then @@access ||= new("access", true)
    when "update" then @@update ||= new("update", true)
    when "rating" then @@rating ||= new("rating", true)
    when "weight" then @@weight ||= new("weight", true)
    else               raise "unknown order type!"
    end
  end

  struct Index
    SEP = "ǁ"

    getter uuid : String
    getter genre : String
    getter value : Float64

    def self.parse!(line : String)
      uuid, genre, value = line.split(SEP, 3)
      value = value.try(&.to_f) || 0.0
      new(uuid, genre, value)
    end

    def initialize(@uuid, @genre, @value)
    end

    def same?(other : Index)
      return true if @value >= other.value
      @genre == other.genre
    end

    def match?(genre : String)
      return true if genre.empty?
      genre == @genre
    end

    def to_s(io : IO)
      io << uuid << SEP << genre << SEP << value
    end
  end

  @data = [] of Index

  include Enumerable(Index)
  delegate each, to: @data

  def initialize(@type : String, preload : Bool = false)
    @file = File.join(ROOT, "#{@type}.txt")
    load! if preload
  end

  def load!(reorder : Bool = false)
    if File.exists?(@file)
      lines = File.read_lines(@file)
      lines.each do |line|
        upsert(Index.parse!(line), reorder: false)
      end

      reorder! if reorder
      puts "- <book_order_index> [#{@type.colorize(:cyan)}] loaded."
    else
      puts "- <book_order_index> [#{@type.colorize(:red)}] not found!"
    end

    self
  end

  # return true if changed
  def upsert(entry : Index, reorder : Bool = true) : Bool
    if idx = index(entry.uuid)
      older = @data[idx]
      return false if older.same?(entry)
      @data[idx] = entry
    else
      @data << entry
    end

    reorder! if reorder
    true
  end

  def index(uuid : String)
    @data.index { |x| uuid == x.uuid }
  end

  def save! : self
    File.open(@file, "w") do |io|
      @data.each { |entry| io.puts(entry) }
    end

    puts "- <book_order_index> [#{@type.colorize(:cyan)}] saved."
    self
  end

  def reorder!
    @data.sort_by!(&.value)
  end

  def fetch(size : Int32 = 20, skip : Int32 = 0, genre : String = "")
    @data.reverse_each do |item|
      next unless item.match?(genre)

      if skip > 0
        skip -= 1
      else
        size -= 1
        break unless limit > 0
        yield item.uuid
      end
    end
  end
end