module ApplicationHelper
  # Override administrate's default (Rails module name "Chatwoot") for the
  # Super Admin panel page titles → FLAMAID white-label.
  def application_title
    'FLAMAID'
  end

  def available_locales_with_name
    LANGUAGES_CONFIG.map { |_key, val| val.slice(:name, :iso_639_1_code) }
  end

  def feature_help_urls
    features = YAML.safe_load(Rails.root.join('config/features.yml').read).freeze
    features.each_with_object({}) do |feature, hash|
      hash[feature['name']] = feature['help_url'] if feature['help_url']
    end
  end
end
