class Track < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  belongs_to :user
  has_many :track_comments
  has_many :track_playlists
  has_many :playlists, through: :track_playlists
  has_many :listening_events
  has_many :reposts
  has_many :purchased_items, as: :purchased_item
  has_many :likes, as: :likeable
  has_many :comments, as: :commentable
  has_one :track_peak
  has_many :spotlights, as: :spotlightable
  # has_many :spotlighted_tracks, through: :spotlight_tracks


  has_one_attached :cover
  has_one_attached :audio
  has_one_attached :mp3_audio
  has_one_attached :zip

  validates :cover, presence: false, blob: {content_type: :web_image} # supported options: :web_image, :image, :audio, :video, :text

  validates :audio, presence: false, blob: {content_type: :audio, size_range: 1..(400.megabytes)} # supported options: :web_image, :image, :audio, :video, :text

  acts_as_likeable

  attr_accessor :step, :tab

  scope :published, -> { where(private: false) }
  # scope :private, -> { where.not(:private => true)}
  scope :latests, -> { order("id desc") }

  # store_attribute :metadata, :ratio, :integer, limit: 1
  # store_attribute :metadata, :login_at, :datetime
  # #store_attribute :metadata, :active, :boolean
  # store_attribute :metadata, :color, :string, default: "red"
  # store_attribute :metadata, :colors, :json, default: ["red", "blue"]
  # store_attribute :metadata, :data, :datetime, default: -> { Time.now }

  # store_attribute :metadata, :peaks, :json, default: []
  store_attribute :metadata, :contains_music, :boolean
  store_attribute :metadata, :artist, :string
  store_attribute :metadata, :publisher, :string
  store_attribute :metadata, :isrc, :string
  store_attribute :metadata, :composer, :string
  store_attribute :metadata, :release_title, :string
  store_attribute :metadata, :buy_link, :string
  store_attribute :metadata, :buy_link_title, :string
  store_attribute :metadata, :buy, :boolean
  store_attribute :metadata, :album_title, :string
  store_attribute :metadata, :record_label, :string
  store_attribute :metadata, :release_date, :date
  store_attribute :metadata, :barcode, :string
  store_attribute :metadata, :iswc, :string
  store_attribute :metadata, :p_line, :string
  store_attribute :metadata, :contains_explicit_content, :boolean
  store_attribute :metadata, :copyright, :string
  store_attribute :metadata, :genre, :string
  store_attribute :metadata, :direct_download, :boolean
  store_attribute :metadata, :display_embed, :boolean
  store_attribute :metadata, :enable_comments, :boolean, default: true
  store_attribute :metadata, :display_comments, :boolean, default: true
  store_attribute :metadata, :display_stats, :boolean
  store_attribute :metadata, :include_in_rss, :boolean
  store_attribute :metadata, :offline_listening, :boolean
  store_attribute :metadata, :enable_app_playblack, :boolean
  store_attribute :metadata, :attribution, :boolean
  store_attribute :metadata, :noncommercial, :boolean
  store_attribute :metadata, :non_derivative_works, :boolean
  store_attribute :metadata, :share_alike, :boolean
  store_attribute :metadata, :copies, :string
  store_attribute :metadata, :price, :decimal
  store_attribute :metadata, :name_your_price, :boolean

  include AASM

  after_create :reprocess_async

  aasm column: :state do
    state :pending, initial: true
    state :processed

    event :run do
      transitions from: :pending, to: :processed
    end

    event :sleep do
      transitions from: :running, to: :sleeping
    end
  end

  def peaks
    self.track_peak&.data || []
  end

  def peaks=(peaks)
    if self.track_peak.blank?
      self.build_track_peak(data: peaks) 
    else
      self.track_peak.update(data: peaks) 
    end
  end

  def cover_url(size = nil)
    url = case size
    when :medium
      cover.variant(resize_to_limit: [200, 200])

    when :large
      cover.variant(resize_to_limit: [500, 500])

    when :small
      cover.variant(resize_to_limit: [50, 50])

    else
      cover.variant(resize_to_limit: [200, 200])
    end

    return Rails.application.routes.url_helpers.rails_storage_proxy_url(url) if url.present?

    url || "daniel-schludi-mbGxz7pt0jM-unsplash-sqr-s-bn.png"
  end

  def self.permission_definitions
    [
      {
        name: :direct_download,
        wrapper_class: "sm:col-span-2",
        type: :checkbox,
        checked_hint:
          "This track will be available for direct download in the original format it was uploaded.",
        unchecked_hint:
          "This track will not be available for direct download in the original format it was uploaded."
      },
      {
        name: :display_embed,
        wrapper_class: "sm:col-span-2",
        type: :checkbox,
        checked_hint: "This track’s embedded-player code will be displayed publicly.",
        unchecked_hint: "This track’s embedded-player code will only be displayed to you."
      },
      {
        name: :enable_comments,
        wrapper_class: "sm:col-span-2",
        type: :checkbox,
        checked_hint: "Enable comments",
        unchecked_hint: "Comments disabled."
      },
      {
        name: :display_comments,
        wrapper_class: "sm:col-span-2",
        type: :checkbox,
        checked_hint: "Display comments",
        unchecked_hint: "Don't display public comments."
      },
      {
        name: :display_stats,
        wrapper_class: "sm:col-span-2",
        type: :checkbox,
        checked_hint: "Display public stats",
        unchecked_hint: "Don't display public stats."
      },
      {
        name: :include_in_rss,
        wrapper_class: "sm:col-span-2",
        type: :checkbox,
        checked_hint: "This track will be included in your RSS feed if it is public.",
        unchecked_hint: "This track will not be included in your RSS feed."
      },
      {
        name: :offline_listening,
        wrapper_class: "sm:col-span-2",
        type: :checkbox,
        checked_hint: "This track can be played on devices without an internet connection.",
        unchecked_hint:
          "Playing this track will not be possible on devices without an internet connection."
      },
      {
        name: :enable_app_playblack,
        field_type: :text_fiel,
        wrapper_class: "sm:col-span-2",
        type: :checkbox,
        checked_hint: "This track will be playable outside of Rauversion and its apps.",
        unchecked_hint: "This track will not be playable outside of Rauversion and its apps."
      }
    ]
  end

  def update_peaks
    peaks = process_audio_peaks

    update(peaks: peaks, state: "processed")
  end

  def reprocess_async
    TrackProcessorJob.perform_later(id)
  end

  def reprocess!
    return if audio.blob.blank?
    update_mp3
    update_peaks
  end

  def process_with_mp3

    temp_file = Tempfile.new(["audio", ".mp3"], binmode: true)

    # Download the blob to the temp file in chunks
    mp3_audio.download do |chunk|
      temp_file.write(chunk)
    end

    temp_file.rewind

    update_peaks
  end

  def update_mp3(temp_file = nil)
    if temp_file.nil?
      # Create a temp file
      temp_file = Tempfile.new(["audio", ".mp3"], binmode: true)

      # Download the blob to the temp file in chunks
      audio.download do |chunk|
        temp_file.write(chunk)
      end

      temp_file.rewind
    end
    # Use the path of the temp file in the Mp3Converter
    mp3_path = Mp3Converter.new(temp_file.path).run
    mp3_file = File.open(mp3_path)

    # Attach the MP3 file to the Track model
    mp3_audio.attach(io: mp3_file, filename: "converted_audio.mp3", content_type: "audio/mpeg")

    FileUtils.remove_entry mp3_path
    # Ensure the temp file is removed after the Mp3Converter has finished
    temp_file.close
    temp_file.unlink
  end

  def process_audio_peaks(temp_file = nil)
    # Create a temp file
    if temp_file.nil?
      temp_file = Tempfile.new(["audio", ".mp3"], binmode: true)

      # Download the blob to the temp file in chunks
      audio.download do |chunk|
        temp_file.write(chunk)
      end

      temp_file.rewind
    end

    # Use the path of the temp file in the PeaksGeneratorService
    peaks = PeaksGenerator.new(temp_file.path).run

    # Ensure the temp file is removed after the PeaksGeneratorService has finished
    temp_file.close
    temp_file.unlink

    peaks
  end

  def self.top_tracks(profile_id)
    Track.joins(:listening_events)
      .where(listening_events: {resource_profile_id: profile_id})
      .group(:id)
      .limit(10)
      .select("tracks.*, COUNT(listening_events.id) as count")
      .order("count DESC")
      .includes(:cover_blob, user: :avatar_blob)
  end

  def self.top_listeners(profile_id)
    User.joins(:listening_events)
      .where(listening_events: {resource_profile_id: profile_id})
      .group(:id)
      .limit(10)
      .select("users.*, COUNT(listening_events.id) as count")
      .order("count DESC")
      .includes(:avatar_blob)
  end

  def self.top_countries(profile_id)
    ListeningEvent.where(resource_profile_id: profile_id)
      .group(:country)
      .limit(10)
      .select("country, COUNT(country) as count")
      .order("count DESC")
  end

  def self.series_by_month(profile_id, range: 12)
    ListeningEvent.where(resource_profile_id: profile_id)
      .group_by_month(:created_at, range: range.months.ago.midnight..Time.now).count
      .map { |k, v|
      {count: v, day: k}
    }
  end

  def tags=(list)
    self[:tags] = list.map(&:downcase).reject { |item| item.empty? }
  end

  def iframe_code_string(url)
    <<-HTML
    <iframe width="100%" height="100%" scrolling="no" frameborder="no" allow="autoplay" src="#{url}"></iframe>
    <div 
      style="font-size: 10px; color: #cccccc;line-break: anywhere;word-break: normal;overflow: hidden;white-space: nowrap;text-overflow: ellipsis; font-family: Interstate,Lucida Grande,Lucida Sans Unicode,Lucida Sans,Garuda,Verdana,Tahoma,sans-serif;font-weight: 100;">
      <a href="#{user.username}" title="#{user.username}" 
        target="_blank" 
        style="color: #cccccc; text-decoration: none;">
        #{user.username}
      </a> · 
      <a href="#{url}" title="#{title}" target="_blank" style="color: #cccccc; text-decoration: none;">
        #{title}
      </a>
    </div>
    HTML
  end

  def self.get_tracks_by_tag(tag)
    tag = tag.downcase
    includes(:user).where("? = ANY (tags)", tag)
  end
end
