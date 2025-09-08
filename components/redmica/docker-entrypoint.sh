#!/bin/bash
# Simple Docker entrypoint using standard tools
set -e

# Use envsubst for configuration templating (standard tool)
envsubst < /app/config/configuration.yml.envsubst > /app/config/configuration.yml

# Wait for database using dockerize (standard tool)
if command -v dockerize >/dev/null 2>&1; then
    dockerize -wait tcp://${DATABASE_HOST}:${DATABASE_PORT:-5432} -timeout 60s
fi

# Use Rails built-in database tasks
bundle exec rake db:create db:migrate

# Use Rails built-in seeding if seed file exists
if [ -f db/seeds.rb ]; then
    bundle exec rake db:seed
fi

# Start application
exec "$@"
