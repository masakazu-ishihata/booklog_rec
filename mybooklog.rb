#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

################################################################################
# require
################################################################################
require 'json'
require 'open-uri'

# my classes
require './myamazon.rb'
require './mybitly.rb'
require './mytwitter.rb'

################################################################################
# Booklog
################################################################################
class MyBooklog
  # base query
  @@query="#booklog -rt -【本棚登録】-【読了】 -【観た】 -【聴いた】 -【プレイ】"

  #### new ####
  def initialize
    import_uh # @uh[tw_user]    = bl_user
    import_db # @db[user][asin] = rank
  end

  ########################################
  # file I/O
  ########################################
  #### importers ####
  def import_uh
    # user hash : tw_user -> bl_user
    @uh = Hash.new
    open("userlist.db").read.split("\n").each do |line|
      ary = line.split(" ")
      @uh[ ary[0] ] = ary[1]
    end
  end
  def import_db
    # data base : user, asin -> rank
    @db = Hash.new(nil)
    open("rank.db").read.split("\n").map{ |e| e.split(" ") }.each do |user, asin, rank|
      @db[user] = Hash.new(nil) if @db[user] == nil
      @db[user][asin] = rank
    end
  end

  #### exporters ####
  # export user hash
  def export_uh
    open("userlist.db", "w") do |f|
      @uh.to_a.sort{ |a, b| b[0]<=>a[0] }.each do |tw_user, bl_user|
        f.puts "#{tw_user} #{bl_user}"
      end
    end
  end
  # export tuples [user asin rank]
  def export_db
    open("rank.db", "w") do |f|
      @db.keys.each do |bl_user|
        @db[bl_user].keys.sort.each do |asin|
          f.puts "#{bl_user} #{asin} #{@db[bl_user][asin]}"
        end
      end
    end
  end
  # export dat files
  def export_dat(threshold)
    #### count # reference of all books ####
    books = Hash.new(0) # books[asin] = count
    @db.keys.each do |user|
      @db[user].keys.each do |asin|
        books[asin] += 1
      end
    end

    #### export as tuples [bid asin count] ####
    bid = Hash.new # bid[asin] = id,  bid.keys \subseteq books.keys
    open("books.dat", "w") do |f|
      books.keys.sort.each do |asin|
        if books[asin] >= threshold
          bid[asin] = bid.size
          f.puts "#{bid[asin]} #{asin} #{books[asin]}"
        end
      end
    end
    puts "books.dat is exported."

    #### export as tuples [uid user #books] ####
    uid = Hash.new # uid[user] = id
    f = open("users.dat", "w")
    @db.keys.each do |user|
      if bid.keys & @db[user].keys != []
        uid[user] = uid.size
        f.puts "#{uid[user]} #{user} #{@db[user].size}"
      end
    end
    f.close
    puts "users.dat is exported."

    #### export as tuples [uid bid val] ####
    f = open("ranks.dat", "w")
    f.puts "2"       # dimension
    f.puts uid.size  # # users
    f.puts bid.size  # # books
    f.puts "2"       # # values 0:not high 1:high
    @db.keys.each do |user|
      @db[user].keys.each do |asin|
        u = uid[user]
        b = bid[asin]
        r = @db[user][asin].to_i
        #
        if 0 <= r && r <= 3
          r = 0 # not high
        elsif 4 <= r && r <= 5
          r = 1 # high
        end
        #
        f.printf("%s %s %s\n", u, b, r) if b != nil
      end
    end
    f.close
    puts "ranks.dat is exported."
  end

  ########################################
  # update
  ########################################
  def update
    # re-load all users in uh
    @uh.keys.each do |tw_user|
      bl_user = @uh[tw_user]
      puts "update #{bl_user}"
      load_user(bl_user)
    end
    export_db
  end

  ########################################
  # follow new users
  ########################################
  #### follow num new users
  def follow_new_users(num)
    # find new users
    users = search_users(num)
    puts "#{users.keys.size} users will be added."

    # follow new users
    users.each do |tw_user, bl_user|
      next if @uh[tw_user] == bl_user # skip if already follows
      add_user(tw_user, bl_user)
    end
  end

  #### add a new user
  def add_user(tw_user, bl_user)
    puts "add #{tw_user} = #{bl_user}"
    # load users who are successfly followed
    begin
      follow_user(tw_user)    # follow twitter user
    rescue
      # fail
      puts "fail to follow #{tw_user}"
    else
      # success
      load_user(bl_user)      # load booklog user
      @uh[tw_user] = bl_user  # registrate tw_user & bl_user
      export_uh
    end
  end

  #### load a user
  def load_user(bl_user)
    mpage = 100
    count = 100
    asins = []

    am = MyAmazon.new
    @db[bl_user] = Hash.new(nil) if @db[bl_user] == nil

    # open until empty
    for page in 1..mpage
      # open page
      url  = "http://api.booklog.jp"
      path = "/users/#{bl_user}/comic?"
      opt  = "status=3&count=#{count}&page=#{page}"
      db = JSON.parse( open(url + path + opt).read )

      # get books
      db["books"].each do |book|
        # registrate to @db
        asin = book["asin"]
        rank = book["rank"]
        asins.push(asin) if am.history[asin] == nil
        @db[bl_user][asin] = rank
      end

      # break if thare is no book
      break if db["books"].size < count
    end

    #### load book info from amazon ####
    puts "ask #{asins.size} items"
    am.ask_asins(asins)
    export_db
  end

  #### follow a user
  def follow_user(tw_user)
    MyTwitter.new.follow(tw_user)
  end

  ########################################
  # unfollow users
  ########################################
  #### unfollow users
  def unfollow_users(num)
    t = MyTwitter.new
    fg_users = t.followings # users in followings
    fr_users = t.followers  # users in followers
    un_users = (fg_users - fr_users).shuffle

    #### unfollow users who do not follow me ####
    puts "#### unfollow users who is not a friend ####"
    puts "#{un_users[0..num-1].size} users will be unfollowed."
      un_users[0..num-1].each do |tw_user|
      puts "delete #{tw_user}"
      t.unfollow(tw_user)
      @db.delete(bl_user) if (bl_user = @uh[tw_user]) != nil
      @uh.delete(tw_user)
      export_uh
      sleep(30) if un_users[0..num-1].size > 350
    end
  end

  ########################################
  # new release
  ########################################
  #### get new release ####
  def MyBooklog.get_release(day, category, th)
    asins = Array.new  # books

    # open until empty
    n = 0 # previous asin.size
    for page in 1..10
      # open page
      url  = "http://booklog.jp"
      path = "/release/#{category}/#{day.strftime("%Y-%m-%d")}"
      opt  = "?threshold=#{th}&term=all&page=#{page}"

      # get books
      open(url + path  + opt).read.split("\n").each do |line|
        # get a book
        if line.index("class=\"titleLink\"") != nil
          # add to list
          asin  = line.gsub(/^.*\/1\//, "").gsub(/\".*$/,"")
          asins.push(asin)
        end
      end

      # break if final page
      break if asins.size == n
      n = asins.size
    end

    # return booklist
    asins
  end

  #### post new release
  def post_release(n, m)
    am = MyAmazon.new
    tw = MyTwitter.new
    bl = MyBitly.new
    d = Time.now + n*24*60*60

    [ "comic", "book", "game", "magazine" ].each do |category|
      asins = MyBooklog.get_release(d, category, m)
      asins.each do |asin|
        itme      = am.ask(asin)
        title     = item["title"]
        long_url  = item["url"]
        next if title.index(/^NULL$/) != nil # skip if title = NULL

        short_url = bl.shorten(long_url)
        text = "[#{d.strftime("%Y-%m-%d")}] ##{category} #release #{title} #{short_url} #booklog"
        tw.post(text)
      end
    end

    am.backup
  end

  ########################################
  # search
  ########################################
  # search users who tweet with #booklog
  def search_users(num)
    users = Hash.new
    MyTwitter.new.search("#{@@query} -booklog_rec", num).each do |tw|
      next if tw["to_user"] != nil
      tw_user = tw.from_user

      next if @uh[tw_user] != nil # is already member of uh
      puts "---- check #{tw_user}'s tweet ----"
      puts "#{tw.text.gsub(/\n/,"")}"

      bl_user = MyBooklog.tweet2users(tw)
      next if bl_user == nil      # could not find bl_user

      puts " -> #{tw_user} #{bl_user}"
      users[tw_user] = bl_user
    end
    users
  end

  # search bl_user of tw_user
  def MyBooklog.search_bl_user(tw_user)
    bl_user = nil
    MyTwitter.new.search("#{tw_user} #{@@query}", 100).each do |tw|
      break if tw_user == tw.from_user &&  (bl_user = tweet2users(tw)) != nil
    end
    bl_user
  end

  #### tweet to users ####
  def MyBooklog.tweet2users(tw)
    tw_user = tw.from_user
    bl_user = nil

    #### registrat user if corresponding booklog user is found ####
    if tw.text.index("http:") != nil
      url = tw.text.gsub(/\n/, " ").gsub(/^..*http/,"http").split(/[ 　]/)[0]
      open(url).read.split("\n").each do |line|
        if line.index(/property=\"og:url\"/) != nil && line.index(/users\//) != nil
          bl_user = line.gsub(/^.*users\//,"").gsub(/\/.*$/, "").gsub(/\n/,"")
          break
        end
      end rescue bl_user = nil
    end
    bl_user
  end
end
