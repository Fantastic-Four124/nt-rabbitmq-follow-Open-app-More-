worker_processes Integer(ENV['UNICORN_WORKERS'] || 4)
timeout 120
preload_app true


after_fork do |server, worker|
  require_relative '../writer_server'
  # $rabbit_server = WriterServer.new(ENV["RABBITMQ_BIGWIG_RX_URL"])
  # $rabbit_server.start('writer_queue')
  # rescue Interrupt => _
  #   $rabbit_server.stop
  $server = FollowerServer.new("amqp://ivljoztm:XgUaHWXJXoB9sA3KUQuIPSjsV9kacqAg@eagle.rmq.cloudamqp.com/ivljoztm")
  
  uri = URI.parse(ENV['REDIS_FOLLOW'])
  $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  uri2 = URI.parse(ENV['REDIS_USER'])
  $redisUserServiceCache = Redis.new(:host => uri2.host, :port => uri2.port, :password => uri2.password)
 

  puts ' [x] Awaiting RPC requests'
  $server.start('rpc_queue')
end

before_exec do |server|
  ENV['BUNDLE_GEMFILE'] = "#{apppath}/current/Gemfile"
end
