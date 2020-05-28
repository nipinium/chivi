require "json"
require "colorize"

require "../engine/convert/cv_node"

class VpText < Array(CvNodes)
  def zh_text(io : IO)
    each do |line|
      line.zh_text(io)
    end
  end

  def vi_text(io : IO)
    each do |line|
      line.vi_text(io)
    end
  end

  def to_s(io : IO)
    to_pretty_json(io)
  end

  # class methods

  DIR = File.join("data", "vp_texts")

  def self.uuid_for(buid : String, site : String, bsid : String)
    "#{buid}.#{site}.#{bsid}"
  end

  def self.path_for(uuid : String, csid : String, user = "guest")
    File.join(DIR, uuid, "#{csid}.#{user}.json")
  end

  def self.load(uuid : String, csid : String, user = "guest")
    load(file_path(uuid, csid))
  end

  def self.load(file : String)
    load!(file) if File.exists?(file)
  end

  def self.load!(file : String)
    from_json(File.read(file))
  end

  def self.save!(file : String, chap : VpText)
    # puts "- save chtext to #{file.colorize(:blue)}"
    File.write(file, chap.to_json)
  end
end