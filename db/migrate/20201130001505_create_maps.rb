class CreateMaps < ActiveRecord::Migration[5.2]
  def change
    create_table :maps do |t|
      t.references :user, foreign_key: true
      t.integer :plot_no
      t.text :address
      t.float :latitude
      t.float :longitude
      t.float :altitude

      t.timestamps
    end
  end
end
