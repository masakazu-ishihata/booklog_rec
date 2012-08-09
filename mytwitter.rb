#!/usr/bin/env ruby

################################################################################
# require
################################################################################
require 'twitter'

################################################################################
# twitter
################################################################################
class MyTwitter
  #### new ####
  def initialize
    # files
    @topost = "topost.txt"

    # load id
    ary = open("./ids/twitter_id.txt").read.split("\n")

    # initialize
    @user = ary[0]
    Twitter.configure do |cnf|
      cnf.consumer_key       = ary[1]
      cnf.consumer_secret    = ary[2]
      cnf.oauth_token        = ary[3]
      cnf.oauth_token_secret = ary[4]
    end
  end

  #### search query ####
  def search(query, num)
    ary = []
    for i in 1..10 # max = 1000
      break if num <= 0
      ary += Twitter.search(query, {:rpp => num, :page => i})
      num -= 100
    end
    ary
  end

  #### timeline ####
  def timeline(num)
    ary = []
    for i in 1..5 # max = 1000
      break if num <= 0
      ary += Twitter.user_timeline(@user, {:count => num, :page => i})
      num -= 200
    end
    ary
  end

  #### ids => names ####
  def ids2names(ids)
    ary = Array.new
    i = 0
    while i < ids.size
      Twitter.users(ids[i..i+99]).each do |user|
        ary.push(user.screen_name)
      end
      i += 100
    end
    ary
  end

  #### followers ####
  def followers
    ids2names( Twitter.follower_ids(@user, options={})["ids"] )
  end

  #### followings ####
  def followings
    ids2names( Twitter.friend_ids(@user, options={})["ids"] )
  end

  #### follow ####
  def follow(user)
    if !Twitter.friendship?(@user, user)
      puts "follow #{user}"
      Twitter.follow(user)
    end
  end

  #### unfollow ####
  def unfollow(user)
    if Twitter.friendship?(@user, user)
      puts "unfollow #{user}"
      Twitter.unfollow(user)
    end
  end

  #### user? ####
  def user?(user)
    Twitter.user?(user)
  end

  #### friend? ####
  def friend?(user)
    Twitter.friendship?(@user, user)
  end

  #### post ####
  def post(str)
    puts "#{str} (#{str.size})"
    open(@topost, "a").puts str
  end

  #### post num tweets / min mins from @topost ####
  def post_from_list(num, mim)
    begin
      # load topost
      topost = open(@topost).read.split("\n") - open(@posted).read.split("\n")

      puts "#{topost.size} tweets will be posted." if topost.size > 0

      while topost.size > 0
        # first num tweets
        tws = []
        while (tw = topost.shift) != nil && tws.size < num
          tws.push(tw)
        end

        # post
        tws.each do |tw|
          puts "#{tw} (#{Time.now})"
          Twitter.update(tw) if tw.size <= 140 rescue puts "fail to post \"#{tw}\""
          open(@posted, "a").puts tw
        end

        # wait
        sleep(60 * min)
      end

      # wait
      sleep(300)
    end while true
  end
end
