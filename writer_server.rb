#!/usr/bin/env ruby
require 'bunny'
require 'sinatra'
require 'sinatra/activerecord'
require 'byebug'
require 'time_difference'
require 'time'
require 'json'
require 'redis'
require 'set'
require_relative 'models/follow'

class FollowerServer
  def initialize(id)
    @connection = Bunny.new(id)
    @connection.start
    @channel = @connection.create_channel
  end

  def start(queue_name)
    @queue = channel.queue(queue_name)
    @exchange = channel.default_exchange
    subscribe_to_queue
  end

  def stop
    channel.close
    connection.close
  end

  private

  attr_reader :channel, :exchange, :queue, :connection, :exchange2, :queue2

  def subscribe_to_queue
    queue.subscribe(block: true) do |_delivery_info, properties, payload|
      puts "[x] Get message #{payload}. Gonna do some user service about #{payload}"
      result = process(payload)
      puts result
    end
  end

  # eg. {"leader_id":":5","user_id":"2","isFo":true}
  def process(follow_json)
    puts '#TrustTheProcess'
    puts follow_json
    input = JSON.parse follow_json
    if input['isFo'] 
      follower_follow_leader(input['user_id'], input['leader_id'])
    else
      follower_unfollow_leader(input['user_id'], input['leader_id'])
    end
  end

end

# Do follow
def follower_follow_leader(follower_id, leader_id)
  update_cache_follow(follower_id, leader_id, true)
  # update cache first, for high availibility
  puts "follower_id: #{follower_id}"
  puts "leader_id: #{leader_id}"
  link = Follow.find_by(user_id: follower_id, leader_id: leader_id)
  if link.nil?
    puts "follower_follow_leader"
    relation = Follow.new
    relation.user_id = follower_id
    relation.leader_id = leader_id
    relation.follow_date = Time.now
    bl = relation.save
    puts bl
  end
end

# Do unfollow
def follower_unfollow_leader(follower_id, leader_id)
  update_cache_follow(follower_id, leader_id, false) 
  # update cache first, for high availibility
  link = Follow.find_by(user_id: follower_id, leader_id: leader_id)
  if !link.nil?
    puts "follower_unfollow_leader"
    Follow.delete(link.id)
  end
end

# Update the cache in follow and user service
def update_cache_follow(follower_id, leader_id, isFollowing)
  redis_leader_key = "#{leader_id} followers"
  redis_user_key = "#{follower_id} leaders"

  followers_of_leader, leaders_of_user = get_leaders_followers_map(redis_leader_key, redis_user_key)

  users_info_map, leader_info_map = get_user_obj_cache(follower_id, leader_id)

  if isFollowing 
    followers_of_leader[follower_id] = true
    leaders_of_user[leader_id] = true
    users_info_map['number_of_leaders'] += 1 if !users_info_map.nil? 
    leader_info_map['number_of_followers'] += 1 if !leader_info_map.nil?
  else # We dont love anymore
    followers_of_leader.delete(follower_id)
    leaders_of_user.delete(leader_id)
    leader_info_map['number_of_followers'] -= 1 if !leader_info_map.nil?
    users_info_map['number_of_leaders'] -= 1 if !users_info_map.nil?
  end

  $redis.set(redis_user_key, leaders_of_user.to_json)
  $redis.set(redis_leader_key, followers_of_leader.to_json)
  $redisUserServiceCache.set(follower_id, users_info_map.to_json) if !users_info_map.nil?
  $redisUserServiceCache.set(leader_id, leader_info_map.to_json) if !leader_info_map.nil?
end

# Helper method
def get_leaders_followers_map(redis_leader_key, redis_user_key)
  tmp1 = $redis.get(redis_leader_key)
  tmp2 = $redis.get(redis_user_key)

  if tmp1 == nil
    tmp1 = '{}'
    $redis.set("#{redis_leader_key} leaders", '{}')
  end

  if tmp2 == nil
    puts 'make new 2'
    tmp2 = '{}'
    $redis.set("#{redis_user_key} followers", '{}')
  end
  return JSON.parse(tmp1), JSON.parse(tmp2)
end

# Helper method
def get_user_obj_cache(follower_id, leader_id)
  tmp3 = $redisUserServiceCache.get(follower_id)
  tmp4 = $redisUserServiceCache.get(leader_id)

  if tmp3 == nil
    users_info_map = nil
  else 
    users_info_map = JSON.parse tmp3
  end
  
  if tmp4 == nil 
    leader_info_map = nil
  else
    leader_info_map = JSON.parse tmp4
  end
  return users_info_map, leader_info_map
end
