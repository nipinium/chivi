require "./kernel/dict_repo"
require "./kernel/dict_mlog"

module DictDB
  DIC_DIR = File.join("var", "dict_repos")
  LOG_DIR = File.join("var", "dict_mlogs")

  SHARED = {} of String => DictRepo
  UNIQUE = {} of String => DictRepo

  @@cc_cedict : DictRepo? = nil
  @@trungviet : DictRepo? = nil

  def self.cc_cedict
    @@cc_cedict ||= DictRepo.load
  end

  def self.trungviet
    @@trungviet ||= @@LOOKUP["trungviet"]
  end

  def self.shared(dict : String = "combine", user = "local")
    LxPair.new(@@SHARED[dict, user], @@SHARED[dict])
  end

  def self.unique(dict : String = "tonghop", user = "local")
    LxPair.new(@@UNIQUE[dict, user], @@UNIQUE[dict])
  end

  def self.for_convert(name : String = "tonghop", user : String = "local")
    [shared("generic", user), unique(name, user)]
  end
end