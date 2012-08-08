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
  #### update ####
  def update
    # re-load all users in uh
    @uh.keys.each do |tw_user|
      if user?(tw_user)
        # reload if tw_user is a valid id
        bl_user = @uh[tw_user]
        puts "update #{bl_user}"
        load_user(bl_user)
      else
        # remove if tw_user is an invalid id
        remove_user(tw_user)
      end
    end
    export_db
  end

  #### user? ####
  def user?(tw_user)
    # tw_user is not a user of Twitter
    return false if !MyTwitter.new.user?(tw_user)

    # bl_user is not a user of Booklog
    bl_user = @uh[tw_user]

    # try t