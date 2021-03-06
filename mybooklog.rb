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
    puts "userlist.db is imported. (#{@uh.keys.size})"
  end
  def import_db
    # data base : user, asin -> rank
    @db = Hash.new(nil)
    open("rank.db").read.split("\n").map{ |e| e.split(" ") }.each do |user, asin, rank|
      @db[user] = Hash.new(nil) if @db[user] == nil
      @db[user][asin] = rank
    end
    puts "rank.db is imported. (#{@db.keys.size})"
  end

  #### exporters ####
  # export user hash
  def export_uh
    open("userlist.db", "w") do |f|
      @uh.to_a.sort{ |a, b| b[0]<=>a[0] }.each do |tw_user, bl_user|
        f.puts "#{tw_user} #{bl_user}"
      end
    end
    puts "userlist.db is exported."
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
    puts "rank.db is exported."
  end
  # export dat files
  def export_dat(_n, _m)
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
        if books[asin] >= _n
          bid[asin] = bid.size
          f.puts "#{bid[asin]} #{asin} #{books[asin]}"
        end
      end
    end
    puts "books.dat is exported. (#{bid.size} books which appear > #{_n} times)"

    #### export as tuples [uid user #books] ####
    uid = Hash.new # uid[user] = id
    f = open("users.dat", "w")
    @db.keys.each do |user|
      if (bid.keys & @db[user].keys).size > bid.size * (_m / 1000.0)
        uid[user] = uid.size
        f.puts "#{uid[user]} #{user} #{@db[user].size}"
      end
    end
    f.close
    puts "users.dat is exported. (#{uid.size} users who has > #{bid.size * (_m / 1000.0)} books)"

    #### export as tuples [uid bid val] ####
    f = open("ranks.dat", "w")
    f.puts "2"       # dimension
    f.puts uid.size  # # users
    f.puts bid.size  # # books
    f.puts "2"       # # values 0:not high 1:high
    @db.keys.each do |user|
      @db[user].keys.each do |asin|
        next if (u = uid[user]) == nil
        next if (b = bid[asin]) == nil
        r = @db[user][asin].to_i
        #
        if 0 <= r && r <= 3
          r = 0 # not high
        elsif 4 <= r && r <= 5
          r = 1 # high
        end
        #
        f.printf("%s %s %s\n", u, b, r)
      end
    end
    f.close
    puts "ranks.dat is exported."
  end

  ########################################
  # update
  ########################################
  #### update ####
  def consistent
    users = @uh.keys.sort             # users in user hash
    flgs = MyTwitter.new.followings   # users in following

    puts "uh = #{users.size}"
    puts "db = #{@db.keys.size}"
    puts "fg = #{flgs.size}"

    #### following but not in uh/db --> unfollow ####
    puts "Update followings"
    flgs.each do |tw_user|
      bl_user = @uh[tw_user]

      if bl_user == nil  # following but not in uh
        puts "#{tw_user} is not in uh/db."
        MyTwitter.new.unfollow(tw_user)
        @uh.delete(tw_user)
        @db.delete(bl_user)
      elsif @db[bl_user] == nil # follwoing & in uh but not in db
        load_user(bl_user)
      end
    end

    #### users in uh but not following ####
    puts "Update uh keys"
    users.each do |tw_user|
      bl_user = @uh[tw_user]
      if flgs.index(tw_user) == nil
        puts "#{tw_user} is not in following."
        @uh.delete(tw_user)
        @db.delete(bl_user)
      end
    end
    users = @uh.keys.sort
    export_uh

    #### users in db but not uh ####
    puts "Update db keys"
    h = Hash.new(nil)
    users.each do |tw_user|
      bl_user = @uh[tw_user]
      h[bl_user] = tw_user
    end
    (@db.keys - h.keys).each do |bl_user|
      puts "#{bl_user} is not in uh."
      @db.delete(bl_user)
    end

    #### update amazon ####
#    puts "Update amazon database"
#    MyAmazon.new.update
  end

  #### update ####
  def update
    # consistent
    consistent

    # load
    users = @uh.keys.sort             # users in user hash
    flgs = MyTwitter.new.followings   # users in following

    #### update users ####
    puts "Update bookshelf"
    for i in 0..users.size-1
      tw_user = users[i]
      bl_user = @uh[tw_user]
      puts "update #{tw_user} = #{bl_user} (#{i+1}/#{users.size})"

      # update
      t1 = Time.now

      # tw_user is not in following
      if flgs.index(tw_user) == nil
        @uh.delete(tw_user)
        @db.delete(bl_user)
        export_uh
        export_db

      # tw_user is valid but bl_user is invalid
      elsif !MyBooklog.bl_user?(bl_user)
        remove_user(tw_user)

      # a valid user
      else
        load_user(bl_user)
      end
      t2 = Time.now
    end

    # for safe
    export_uh
    export_db
  end

  #### tw_user? ####
  def MyBooklog.tw_user?(tw_user)
    MyTwitter.new.user?(tw_user)
  end

  #### bl_user? ####
  def MyBooklog.bl_user?(bl_user)
    # try to open bl_user's page
    url  = "http://api.booklog.jp/users/#{bl_user}"
    begin
      open(url)
    rescue
      return false
    else
      return true
    end
  end

  ########################################
  # follow new users
  ########################################
  #### follow num new users
  def follow_new_users(num)
    # find new users
    users = search_users(num)
    puts "#{users.keys.size} users will be followed."

    # follow new users
    users.each do |tw_user, bl_user|
      add_user(tw_user, bl_user)
    end

    # for safe
    export_uh
    export_db
  end

  #### unfollow users
  def unfollow_users(num)
    # consistent
    consistent

    return nil if num <= 0

    # get num non-friend users
    users = @uh.to_a.sort{|a,b| @db[a[1]].size <=> @db[b[1]].size}

    #### unfollow users who do not follow me ####
    users[0..num-1].each do |tw_user, bl_user|
      remove_user(tw_user)
    end

    # for safe
    export_uh
    export_db
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
      return false
    else
      # success
      load_user(bl_user)      # load booklog user
      @uh[tw_user] = bl_user  # registrate tw_user & bl_user
      export_uh
      return true
    end
  end

  #### remove a user ####
  def remove_user(tw_user)
    bl_user = @uh[tw_user]
    puts "remove #{tw_user} = #{bl_user} who has #{@db[bl_user].size} items"

    # unfollow
    MyTwitter.new.unfollow(tw_user)

    # remove from database
    @db.delete(bl_user)
    export_db

    # remove from user hash
    @uh.delete(tw_user)
    export_uh
  end

  #### load a user
  def load_user(bl_user)
    puts "load #{bl_user}"
    mpage = 100
    count = 100
    asins = []

    am = MyAmazon.new
    @db[bl_user] = Hash.new(nil) if @db[bl_user] == nil

    # open until empty
    for page in 1..mpage
      # open page
      url  = "http://api.booklog.jp"
      path = "/users/#{bl_user}/"
      opt  = "?count=#{count}&page=#{page}"
      db = JSON.parse( open(url + path + opt).read )

      # get books
      db["books"].each do |book|
        # registrate to @db
        asin = book["asin"]
        rank = book["rank"].to_i
        @db[bl_user][asin] = rank
        asins.push(asin) if !am.asked?(asin) && rank == 5
      end

      # break if thare is no book
      break if db["books"].size < count
    end

    #### load book info from amazon ####
    if asins.size > 0
      puts "ask #{asins.size}/#{@db[bl_user].size} items"
      am.ask_asins(asins)
      export_db
    end
  end

  #### follow a user
  def follow_user(tw_user)
    puts "follow #{tw_user}"
    MyTwitter.new.follow(tw_user)
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
      am.ask_asins(asins)
      asins.each do |asin|
        item      = am.ask(asin)
        title     = item["title"]
        long_url  = item["url"]
        next if title.index(/^NULL$/) != nil # skip if title = NULL

        short_url = bl.shorten(long_url)
        text = "[#{d.strftime("%Y-%m-%d")}] ##{category} #release #{title} #{short_url} #booklog"
        tw.post(text)
      end
    end
  end

  ########################################
  # search
  ########################################
  # search users who tweet with #booklog
  def search_users(num)
    tw = MyTwitter.new
    users = Hash.new
    tw.search("#{@@query} -booklog_rec", num).each do |tweet|
      next if (ids = MyBooklog.tweet2user(tweet)) == nil # no corresponding booklog id
      tw_user = ids[0]
      bl_user = ids[1]

      next if @uh[tw_user] != nil # tw_user is already followed

      # show tweet
      puts "---- check #{tw_user}'s tweet ----"
      puts "#{tweet['text'].gsub(/\n/,"")}"
      puts " -> #{tw_user} #{bl_user}"
      users[tw_user] = bl_user
    end
    users
  end

  #### tweet to users ####
  def MyBooklog.tweet2user(tweet)
    return nil if tweet['to_user'] != nil # tweet is not a original

    tw_user = tweet['from_user']
    bl_user = nil
    text = tweet['text']

    #### registrat user if corresponding booklog user is found ####
    if text.index("http:") != nil
      url = text.gsub(/\n/, " ").gsub(/^..*http/,"http").split(/[ 　]/)[0]
      open(url).read.split("\n").each do |line|
        if line.index(/property=\"og:url\"/) != nil && line.index(/users\//) != nil
          bl_user = line.gsub(/^.*users\//,"").gsub(/\/.*$/, "").gsub(/\n/,"")
          break
        end
      end rescue bl_user = nil
    end

    # return a pair of user ids
    if bl_user != nil
      return [tw_user, bl_user]
    else
      return nil
    end
  end
end
