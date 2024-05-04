class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable, :confirmable,
    :invitable, :omniauthable, :trackable, :lockable

  has_many :tracks
  has_many :playlists
  has_many :reposts
  has_many :reposted_tracks, through: :reposts, source: :track
  has_many :track_comments
  has_many :posts
  has_many :photos
  has_many :listening_events
  has_many :invitations, class_name: to_s, as: :invited_by
  has_many :oauth_credentials
  has_many :events
  has_many :event_hosts
  has_many :hosted_events, through: :event_hosts
  has_many :purchases
  has_many :comments

  
  has_many :connected_accounts, foreign_key: :parent_id

  has_many :child_accounts, through: :connected_accounts, source: :user

  has_many :spotlights, autosave: true
  # has_many :spotlighted_tracks, through: :spotlight_tracks, source: :spotlight_tracks
  has_one_attached :profile_header
  has_one_attached :avatar

  acts_as_followable
  acts_as_follower
  acts_as_liker
  acts_as_mentionable

  include User::OmniAuthExtension

  store_attribute :notification_settings, :new_follower_email, :boolean
  store_attribute :notification_settings, :new_follower_app, :boolean
  store_attribute :notification_settings, :repost_of_your_post_email, :boolean
  store_attribute :notification_settings, :repost_of_your_post_app, :boolean
  store_attribute :notification_settings, :new_post_by_followed_user_email, :boolean
  store_attribute :notification_settings, :new_post_by_followed_user_app, :boolean
  store_attribute :notification_settings, :like_and_plays_on_your_post_app, :boolean
  store_attribute :notification_settings, :comment_on_your_post_email, :boolean
  store_attribute :notification_settings, :comment_on_your_post_app, :boolean
  store_attribute :notification_settings, :suggested_content_email, :boolean
  store_attribute :notification_settings, :suggested_content_app, :boolean
  store_attribute :notification_settings, :new_message_email, :boolean
  store_attribute :notification_settings, :new_message_app, :boolean
  store_attribute :notification_settings, :like_and_plays_on_your_post_email, :boolean

  store_attribute :settings, :pst_enabled, :boolean
  store_attribute :settings, :tbk_commerce_code, :string
  store_attribute :settings, :tbk_test_mode, :boolean

  accepts_nested_attributes_for :photos, allow_destroy: true

  scope :artists, -> { where(role: "artist").where.not(username: nil) }
  # Ex:- scope :active, -> {where(:active => true)}
  def has_invitations_left?
    true
  end

  def avatar_url(size = :medium)
    url = case size
    when :medium
      avatar.variant(resize_to_fill: [200, 200]) # &.processed&.url

    when :large
      avatar.variant(resize_to_fill: [500, 500]) # &.processed&.url

    when :small
      avatar.variant(resize_to_fill: [50, 50]) # &.processed&.url

    else
      avatar.variant(resize_to_fill: [200, 200]) # &.processed&.url
    end

    url || "daniel-schludi-mbGxz7pt0jM-unsplash-sqr-s-bn.png"
  end

  def self.track_preloaded_by_user(id)
    # Track.left_outer_joins(:reposts, :likes)
    # .where("reposts.user_id = :id OR likes.liker_id = :id OR reposts.user_id IS NULL OR likes.liker_id IS NULL", id: id)
    # .includes(:audio_blob, :cover_blob, user: :avatar_attachment)

    tracks = Track.arel_table
    users = User.arel_table
    reposts_alias = Repost.arel_table.alias("r")
    likes_alias = Like.arel_table.alias("l")

    reposts_join = tracks
      .join(reposts_alias, Arel::Nodes::OuterJoin)
      .on(reposts_alias[:track_id].eq(tracks[:id])
      .and(reposts_alias[:user_id].eq(id)))
      .join_sources

    likes_join = tracks
      .join(likes_alias, Arel::Nodes::OuterJoin)
      .on(likes_alias[:likeable_id].eq(tracks[:id])
      .and(likes_alias[:likeable_type].eq("Track"))
      .and(likes_alias[:liker_id].eq(id))
      .and(likes_alias[:liker_type].eq("User")))
      .join_sources

    result = Track.includes(:audio_blob, :cover_blob, user: :avatar_attachment)
      .joins(reposts_join, likes_join)
      .select("tracks.*, r.id as repost_id, l.id as like_id")
      .references(:r, :l)
  end

  def reposts_preloaded
    User.track_preloaded_by_user(id)
      .joins(:reposts)
      .where("reposts.user_id =?", id)
  end

  def is_publisher?
    is_admin?
  end

  def is_admin?
    role == "admin"
  end

  def profile_header_url(size)
    url = case size
    when :medium
      profile_header.variant(resize_to_fill: [600, 200])&.processed&.url

    when :large
      profile_header.variant(resize_to_fill: [1200, 500])&.processed&.url

    when :small
      profile_header.variant(resize_to_fill: [300, 100])&.processed&.url

    else
      profile_header.variant(resize_to_fill: [300, 100])&.processed&.url
    end

    url || "daniel-schludi-mbGxz7pt0jM-unsplash-sqr-s-bn.png"
  end

  def is_creator?
    username.present? && role == "artist" || role == "admin"
  end

  def user_sales_for(kind = "Track")
    purchased_items = PurchasedItem.joins(
      "INNER JOIN tracks ON purchased_items.purchased_item_id = tracks.id AND purchased_items.purchased_item_type = '#{kind}'"
    )
      .where(tracks: {user_id: id})
  end


  def active_connected_accounts(user)
    ConnectedAccount.where(parent_id: user.id, state: 'active').includes(:user)
  end

  def is_child_of?(child_user_id)
    ConnectedAccount.exists?(parent_id: self.id, state: 'active', user_id: child_user_id)
  end

  def to_combobox_display
    self.username
  end

  def find_artists_excluding_children(q = nil)
    # Get IDs of all child accounts for the current user
    child_account_ids = self.child_accounts.pluck(:id)
  
    # Base query adjusted to exclude child account IDs
    artists = User.where(role: "artist")
                  .where.not(username: nil)
                  #.where.not(label: true)
                  .where.not(id: child_account_ids)
  
    # Apply search filter if 'q' is provided
    if q.present?
      artists = artists.where("username ILIKE :q OR email ILIKE :q", q: "%#{q}%")
    end
  
    artists
  end

  # def password_required?
  #  false
  # end
end



class ExistingArtist
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attribute :username, :string
  attribute :ticket_id, :integer
  attribute :email, :string # Assuming you intend to use it given the validate_email function

  validates :username, presence: true
  validates :ticket_id, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 160 }

  # Custom validation method if you have additional logic
  # validate :custom_validation_method

  private

  # Example custom validation method
  # def custom_validation_method
  #   errors.add(:base, "Custom validation error message") if some_condition
  # end
end


class NewArtist
  include ActiveModel::Model
  include ActiveModel::Validations
  include ActiveModel::Attributes

  attribute :username, :string
  attribute :genre, :string
  attribute :hidden, :string

  validates :username, presence: true
  validate :validate_email

  def validate_email
    # Similar assumption about the `email` attribute
    if email.present? && !email.match?(/\A[^\s]+@[^\s]+\z/)
      errors.add(:email, "must have the @ sign and no spaces")
    end
    if email.length > 160
      errors.add(:email, "is too long (maximum is 160 characters)")
    end
  end
end