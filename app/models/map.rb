class Map < ApplicationRecord
  belongs_to :user
  # 存在性のバリデーション
  validates :latitude, presence: true
  validates :longitude, presence: true

  # バリデーションの前に送信されたaddressの値によってジオコーディング(緯度経度の算出)を行う
  geocoded_by :address
  before_validation :geocode
end
