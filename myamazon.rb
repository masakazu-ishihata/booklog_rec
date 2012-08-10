#!/usr/bin/env ruby

################################################################################
# require
################################################################################
require 'amazon/ecs'

################################################################################
# My Amazon
################################################################################
class MyAmazon
  @@log = nil

  #### new ####
  def initialize
    # load keys
    ary = open("./ids/amazon_id.txt").read.split("\n")
    @atag = ary[0]
    @akey = ary[1]
    @skey = ary[2]

    # options
    Amazon::Ecs.options = {
      :associate_tag     => @atag,
      :AWS_access_key_id => @akey,
      :AWS_secret_key    => @skey
    }

    # load log
    if @@log == nil
      @@log = Hash.new
      open("myamazon.log").read.split("\n").each do |line|
        puts line if line.split(", ").size % 2 == 1
        h = Hash[ *line.split(", ") ]
        asin = h["asin"]
        @@log[asin] = h if @@log[asin] == nil
      end
      puts "myamazon.log is loaded."
    end
  end

  #### history ####
  def history
    @@log
  end

  #### asked? ####
  def asked?(asin)
    @@log[asin] != nil
  end

  #### show ####
  def show
    puts "#{@@log.size} items"
    @@log.values.each do |item|
      puts "#{item.to_a.join(", ")}"
    end
  end

  #### backup ####
  def backup
    f = open("myamazon.log", "w")
    @@log.values.each do |b|
      f.puts b.to_a.join(", ")
    end
    f.close
  end

  #### ask ####
  def ask(asin)
    # asin in log
    return @@log[asin] if @@log[asin] != nil

    # init item info.
    item = Hash.new
    item['asin']   = asin    # ASIN
    item['title']  = 'NULL'  # Title
    item['author'] = 'NULL'  # Authors
    item['date']   = 'NULL'  # date
    item['url']    = 'NULL'  # url

    # ask to amazon
    n_try = 0
    w_sec = 10
    while true
      begin
        res = Amazon::Ecs.item_lookup(asin, { :response_group => 'Medium', :country => 'jp' })
      rescue
        # wait w_sec if fail
        w_sec *= (n_try += 1)
        w_sec = 3600 if w_sec > 3600
        puts "wait #{w_sec} sec (#{Time.now})"
        sleep(w_sec)
        redo
      else
        # success
        if res.items.size > 0
          res.items.each do |i|
            item['asin']   = i.get('ASIN')
            item['title']  = i.get('ItemAttributes/Title')
            item['author'] = i.get('ItemAttributes/Author')
            item['date']   = i.get('ItemAttributes/PublicationDate')
            item['url']    = i.get('DetailPageURL')

            # remove ',' from title & author
            item['title'].gsub!(/,/, "")  if item['title'] != nil
            item['author'].gsub!(/,/, "") if item['author'] != nil
          end
        end
        break
      end
    end

    # add item to log
    @@log[asin] = item

    # return the result
    item
  end

  #### ask_asins ####
  def ask_asins(asins)
    return 0 if asins.size == 0
    n = 0
    asins.each do |asin|
      next if @@log[asin] != nil
      puts "ask #{asin} = #{ask(asin)["title"]}"
      backup if (n += 1) % 100 == 0
    end
    backup
    n
  end
end
