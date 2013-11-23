class AddPortToUsers < ActiveRecord::Migration
  def change
    add_column :users, :port, :string
  end
end
