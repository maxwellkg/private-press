class Leaf < ApplicationRecord
  include Editable, Positionable, Searchable

  belongs_to :book, touch: true
  delegated_type :leafable, types: Leafable::TYPES, dependent: :destroy
  positioned_within :book, association: :leaves, filter: :active

  delegate :searchable_content, to: :leafable

  enum :status, %w[ active trashed ].index_by(&:itself), default: :active

  scope :with_leafables, -> { includes(:leafable) }

  before_validation :set_default_title, if: -> { title.blank? }

  def slug
    title.parameterize.presence || "-"
  end

  private
    def set_default_title
      self.title = default_title
    end

    def default_title
      page? ? "Untitled" : leafable.model_name.human
    end
end
