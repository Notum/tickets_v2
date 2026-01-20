class AddAccordionStatesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :accordion_states, :json, default: {}
  end
end
