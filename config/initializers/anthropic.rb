Anthropic.configure do |config|
  # With dotenv
  config.access_token = ENV.fetch("ANTHROPIC_API_KEY"),
  # OR
  # With Rails credentials
  #config.access_token = Rails.application.credentials.dig(:anthropic, :api_key),
  config.log_errors = true # Highly recommended in development, so you can see what errors Anthropic is returning. Not recommended in production because it could leak private data to your logs.
end
