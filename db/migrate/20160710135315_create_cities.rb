class CreateCities < ActiveRecord::Migration
  def change
    create_table :cities do |t|
      t.string :pref
      t.string :city
      t.geometry :polygon

      t.timestamps null: false
    end
  end
end
