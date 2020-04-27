require 'dotenv'
Dotenv.load(
  ".env.#{ENV['APP_ENV']}.local",
  '.env.local',
  ".env.#{ENV['APP_ENV']}",
  '.env'
)
