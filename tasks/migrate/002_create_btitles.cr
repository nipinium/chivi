require "clear"

class Chivi::Migration::CreateBtitlesTable
  include Clear::Migration

  def change(dir)
    create_table(:btitles, id: :serial) do |t|
      t.column :zh_name, :citext, unique: true, null: false
      t.column :hv_name, :citext, null: false
      t.column :vi_name, :citext

      t.column :zh_name_tsv, :string, array: true, index: :gin, null: false
      t.column :hv_name_tsv, :string, array: true, index: :gin, null: false
      t.column :vi_name_tsv, :string, array: true, index: :gin

      t.timestamps
    end
  end
end
