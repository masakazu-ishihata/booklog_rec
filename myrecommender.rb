#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

################################################################################
# require
################################################################################
require './myamazon.rb'
require './mybitly.rb'
require './mytwitter.rb'

################################################################################
# array
################################################################################
class Array
  def choice
    at( rand(size) )
  end
end

################################################################################
# MyRecommendation
################################################################################
class MyRecommender
  def initialize
    import_uh  # @uh[bl_user] = tw_user <- note that!
    import_db  # @db[user][asin] = rank
    import_dat # @n[0][user id] = user name, @n[1][book id] = asin
               # @z[0][user id] = class id, @z[1][book id] = class id
               # @c[0][class id] = [user ids], @c[1][class id] = [book ids]
               # @d[user class id][book class id] = probability

    # hisitory
    @his = Hash.new

    am = MyAmazon.new
    asins = []
    # ranked 5
    @db.keys.each do |user|
      @db[user].keys do |asin|
        asins.push(asin) if @db[user][asin] == 5 && !am.asked?(asin)
      end
    end
    # candidates
    @n[1].each do |asin|
      asins.push(asin) if !am.asked?(asin)
    end
    am.ask_asins(asins) if asins.size > 0
  end

  ########################################
  # file I/O
  ########################################
  # import user hash
  def import_uh
    # user hash : tw_user -> bl_user
    @uh = Hash.new
    open("userlist.db").read.split("\n").each do |line|
      ary = line.split(" ")
      @uh[ ary[1] ] = ary[0]
    end
    puts "userlist.db is imported. (#{@uh.size} users)"
  end

  # import database
  def import_db
    # data base : user, asin -> rank
    @db = Hash.new(nil)
    open("rank.db").read.split("\n").map{ |e| e.split(" ") }.each do |user, asin, rank|
      @db[user] = Hash.new(nil) if @db[user] == nil
      @db[user][asin] = rank
    end
    puts "rank.db is imported."
  end

  # import dat files
  def import_dat
    # @n[0][user id] = user name, @n[1][book id] = asin
    @n = [ open("users.dat").read.split("\n").map{ |e| e.split(" ")[1] }.flatten,
           open("books.dat").read.split("\n").map{ |e| e.split(" ")[1] }.flatten ]
    puts "n[0] size = #{@n[0].size}"
    puts "n[1] size = #{@n[1].size}"

    # @z[0][user id] = class id, @z[1][book id] = class id
    lines = open("ranks.out").read.split("\n")
    @z = lines[1..2].map{ |e| e.gsub(/^.*{/,"").gsub(/}/,"").split(", ").map{ |f| f.to_i} }
    puts "# users = #{@z[0].size}"
    puts "# books = #{@z[1].size}"

    # @c[0][class id] = [user ids], @c[1][class id] = [book ids]
    @c = [Hash.new, Hash.new]
    for i in 0..1
      for j in 0..@z[i].size-1
        c = @z[i][j]
        @c[i][c] = Array.new if @c[i][c] == nil
        @c[i][c].push(j)
      end
    end
    puts "# user clasters =  #{@c[0].size}"
    puts "# book clasters =  #{@c[1].size}"

    # @d[user class id][book class id] = probability
    @d = Hash.new(nil)
    lines[3..lines.size-1].each do |line|
      ary = line.gsub(/[{}]/,"").split(",")
      uc = ary[0].to_i
      bc = ary[1].to_i
      d = ary[2..ary.size-1].map{ |e| e.to_f }
      @d[uc] = Hash.new if @d[uc] == nil
      @d[uc][bc] = d
    end
  end

  ########################################
  # grouping
  ########################################
  # grouping given asins
  def grouping(asins)
    bg = Hash.new      # book groups
    am = MyAmazon.new

    asins.each do |asin|
      # group key = title body + first author
      item = am.ask(asin)
      body = item["title"].split(/[ ()<>　（）＜＞〈〉]/)[0] # first block of title
      key  = body
      if item["author"] != nil
        author = item["author"].gsub(/[ 　]/, "") # first author
        key += author
      end

      # add item to group key
      bg[key] = Array.new if bg[key] == nil
      bg[key].push(item)
    end
    bg
  end

  ########################################
  # recommendation
  ########################################
  def post_recommend(n)
    am = MyAmazon.new
    bl = MyBitly.new
    tw = MyTwitter.new
    flr = tw.followers

    # friends
    fs = []
    for ui in 0..@z[0].size-1
      bl_user = @n[0][ui]
      tw_user = @uh[bl_user]
      fs.push(ui) if flr.index(tw_user) != nil
    end

    # recommendation order
    us = []
    begin
      us += fs.shuffle
    end while us.size < n
    us = us[0..n-1]

    puts "#{fs.size} friends"
    puts "#{us.size} users"

    # recommends
    us.each do |ui|
      #### get tw_user ####
      bl_user   = @n[0][ui]
      tw_user   = @uh[bl_user]
      tw_user   = ". @" + tw_user if flr.index(tw_user) != nil

      #### recommendation for ####
      asin = get_recommend_for(ui)
      title     = am.ask(asin)["title"]
      long_url  = am.ask(asin)["url"]
      short_url = bl.shorten(long_url)
      text = "#{tw_user} さんへおすすめ：#{title} #{short_url} #booklog"
      tw.post(text)

      #### recommendation from ####
      asin = get_recommend_from(ui)
      next if asin == nil
      title     = am.ask(asin)["title"]
      long_url  = am.ask(asin)["url"]
      short_url = bl.shorten(long_url)
      text = "#{tw_user} さんの☆５：#{title} #{short_url} #booklog"
      tw.post(text)
    end
  end

  #### reccmmend for ####
  def get_recommend_for(ui)
    # user info
    uc = @z[0][ui]          # user class
    un = @n[0][ui]          # user name

    #### get distribution ####
    prb = Array.new
    s = 0
    @c[1].keys.each do |bc|
      r = @d[uc][bc][2]
      s += r
      prb.push(r)
    end
    prb.map!{ |e| e / s }

    #### choose a book ####
    begin
      r = rand
      s = 0
      bc = nil               # book class
      i = 0
      @c[1].keys.each do |c|
        s += prb[i]
        bc = c if r < s
        break  if bc != nil
        i += 1
      end

      # books
      books = []
      @c[1][bc].each do |bi|
        books.push(@n[1][bi])
      end
      can = books - @db[un].keys

      # redo if no cnadidate
      redo if (can-@his.keys) == []

      # grouping
      bg = grouping(can)

      # chose an item
      begin
        key = bg.keys.choice
        items = bg[key].sort{ |a, b| a["date"] <=> b["date"] }
        puts "key = #{key} (#{items.size} items)"
        for i in 0..items.size-1
          asin = items[i]["asin"]
          break if @his[asin] == nil
        end
        break if @his[asin] == nil
        bg.delete(key)
      end while bg.size > 0

      # already recommended?
      redo if @his[asin] != nil
    end while false

    # recommendation
    @his[asin] = true
    asin
  end

  #### reccmmend from ####
  def get_recommend_from(ui)
    # user info
    un = @n[0][ui]

    # get candidates
    can = Array.new
    @db[un].keys.each do |asin|
      can.push(asin) if @db[un][asin].to_i == 5
    end
    can -= @his.keys

    # no candidate
    return nil if can.size == 0

    # grouping
    bg = grouping(can)

    # chose a book
    key = bg.keys.choice
    b = bg[key].sort{ |a, b| a["date"] <=> b["date"] }[0]
    asin = b["asin"]

    # recommendation
    @his[asin] = true
    asin
  end

  ########################################
  # show
  ########################################
  def show
    # user class
    puts "########################################"
    puts "# user clasters =  #{@c[0].size}"
    puts "########################################"
    @c[0].to_a.sort{ |a, b| b[1].size <=> a[1].size }.each do |c, mem|
      puts "######## Class #{c} (#{mem.size}) ########"
      mem.each do |i|
        puts "#{@n[0][i]}"
      end
    end

    # book class
    am = MyAmazon.new
    puts "########################################"
    puts "# book clasters =  #{@c[1].size}"
    puts "########################################"
    @c[1].to_a.sort{ |a, b| b[1].size <=> a[1].size}.each do |c, mem|
      puts "######## Class #{c} (#{mem.size}) ########"
      mem.each do |i|
        puts "#{am.ask(@n[1][i])["title"]}"
      end
    end
  end
end
