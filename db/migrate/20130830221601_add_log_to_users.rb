class AddLogToUsers < ActiveRecord::Migration
  def change
    add_column :users, :log, :string
  end
end
