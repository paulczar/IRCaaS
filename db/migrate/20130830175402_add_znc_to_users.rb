class AddZncToUsers < ActiveRecord::Migration
  def change
    add_column :users, :znc_user, :string
    add_column :users, :znc_pass, :string
  end
end
