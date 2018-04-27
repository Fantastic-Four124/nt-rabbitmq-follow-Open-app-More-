# server.rb literaliy does nothing in this case.
# One of the annoything thing about the RabbitMQ is that
# The service is always in sleep and it's managed by Heroku.
# We have to do REST call maually to wake up the service. 
# Calling /status will wake up the servie. 
# Only listening to the queue not enought for the lazy rabbit. 

require 'sinatra'

set :bind, '0.0.0.0'
set :port, 8085

get '/status' do
  'ready'
end
