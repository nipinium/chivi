require "./_shared"

class Oldcv::Oldcv::LabelMap
  include OldFlatFile(String)

  getter data = Hash(String, String).new
  delegate size, to: @data
  delegate each, to: @data
  delegate has_key?, to: @data

  def fetch(key)
    @data[key]?
  end

  def load!(file : String = @file)
    read_file(file) do |key, val|
      val.nil? ? delete(key) : upsert(key, val)
    end
  end

  def upsert(key : String, val : String) : String?
    return if @data[key]?.try(&.== val)
    @data[key] = val
  end

  def delete(key : String) : Bool
    !!@data.delete(key)
  end

  def to_s(io : IO, val : String) : Void
    io << val
  end

  def to_s(io : IO) : Void
    each do |key, val|
      puts(io, key, val)
    end
  end

  # class Oldcv::methods

  DIR = "_db/_oldcv"
  FileUtils.mkdir_p(File.join(DIR, "indexes"))

  def self.path_for(name : String) : String
    File.join(DIR, "#{name}.txt")
  end

  def self.load_name(name : String, mode = 1) : self
    load(path_for(name), mode: mode)
  end

  class_getter book_slug : Oldcv::LabelMap { load_name("indexes/book_slug") }

  class_getter zh_author : Oldcv::LabelMap { load_name("_import/fixes/zh_author") }
  class_getter vi_author : Oldcv::LabelMap { load_name("_import/fixes/vi_author") }

  class_getter zh_title : Oldcv::LabelMap { load_name("_import/fixes/zh_title") }
  class_getter vi_title : Oldcv::LabelMap { load_name("_import/fixes/vi_title") }

  class_getter zh_genre : Oldcv::LabelMap { load_name("_import/fixes/zh_genre") }
  class_getter vi_genre : Oldcv::LabelMap { load_name("_import/fixes/vi_genre") }
end

# map = Oldcv::LabelMap.load("tmp/test.txt", mode: 0)

# map.upsert!("a", "b")
# map.upsert!("a", "b")
# map.upsert!("a", "c")

# map.save!