require "./_models"
require "./zhuser"

class Chivi::Zhlist
  include Clear::Model
  self.table = "zhlists"

  primary_key type: :serial

  belongs_to zhuser : Zhuser, foreign_key_type: Int32

  timestamps
end
