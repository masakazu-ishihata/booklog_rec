#!/usr/bin/env ruby
require 'optparse'
require './mybooklog.rb'
require './myrecommender.rb'

################################################################################
# Arguments
################################################################################
@n = 1
@m = 3
OptionParser.new { |opts|
  # options
  opts.on("-h","--help","Show this message") {
    puts opts
    exit
  }
  opts.on("-n [int]", "interger"){ |f|
    @n = f.to_i
  }
  opts.on("-m [int]", "interger"){ |f|
    @m = f.to_i
  }
  #### update db file ####
  opts.on("--update", "update users' info."){
    bl = MyBooklog.new
    bl.update
  }
  #### export dat files ####
  opts.on("--export", "export database with thresould n"){
    MyBooklog.new.export_dat(@n)
  }
  #### follow users who tweet with #booklog ####
  opts.on("--follow", "follow users found from recent n tweets with #booklog"){
    bl = MyBooklog.new
    bl.follow_new_users(@n)
  }
  #### unfollow users who is not a friend ####
  opts.on("--unfollow", "unfollow non-friend users"){
    bl = MyBooklog.new
    bl.unfollow_users(@n)
  }
  #### post new releases ####
  opts.on("--release", "Post new releases after n days with thresould m"){
    MyBooklog.new.post_release(@n, @m)
  }
  #### post recommendations ####
  opts.on("--rec", "Post recommendations of n users"){
    MyRecommender.new.post_recommend(@n)
  }
  #### show resut ####
  opts.on("--show", "show co-clustering result"){
    MyRecommender.new.show
  }
  # parse
  opts.parse!(ARGV)
}
################################################################################
