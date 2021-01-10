require "json"
require "file_utils"

require "./stores/*"

class CV::Chinfo
  DIR = "_db/nvdata/chinfos"
  ::FileUtils.mkdir_p(DIR)

  getter seed : String
  getter sbid : String

  getter index : OrderMap { OrderMap.new(map_path("index"), mode: 1) }
  getter trans : ValueMap { ValueMap.new(map_path("trans"), mode: 1) }
  getter stats : ValueMap { ValueMap.new(map_path("stats"), mode: 1) }

  def initialize(@seed, @sbid)
    @dir = "#{DIR}/#{@seed}/#{@sbid}"
    ::FileUtils.mkdir_p(@dir) unless File.exists?(@dir)
  end

  private def map_path(name : String)
    File.join(@dir, "#{name}.tsv")
  end

  def each(skip : Int32 = 0, take : Int32 = 30, reverse : Bool = false)
    iter = reverse ? index._idx.reverse_each : index._idx.each
    iter = iter.skip(skip)
    iter.first(take) do |node|
      yield({node.key, index.get(node.key)})
    end
  end

  def save!(mode : Symbol = :full)
    @index.try(&.save!(mode: mode))
    @trans.try(&.save!(mode: mode))
    @stats.try(&.save!(mode: mode))
  end

  @@cache = {} of String => self

  def self.load(seed : String, sbid : String) : self
    @@cache["#{seed}/#{sbid}"] ||= new(seed, sbid)
  end
end