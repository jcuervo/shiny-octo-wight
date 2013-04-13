class AddPaddedIdToSurveys < ActiveRecord::Migration
  def change
    add_column :surveys, :padded_id, :string
  end
end
