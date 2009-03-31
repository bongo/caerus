class AddTitleToAccount < ActiveRecord::Migration
  def self.up
    add_column :accounts, :title, :string
  end

  def self.down
    remove_column :accounts, :title
  end
end
