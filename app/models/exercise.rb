class Exercise < ApplicationRecord
  validates :key, :name, :body_region, presence: true
end
