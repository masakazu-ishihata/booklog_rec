#!/usr/bin/env ruby
require 'amazon/ecs'

################################################################################
# My Amazon
################################################################################
class MyAmazon
  #### new ####
  def initialize
    # load keys
    ary = open("amazon_id.txt").read.split("\n")
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
    @file = "myamazon.log"
    @log = Hash.new
    open(@file).read.split("\n").each do |line|
      puts line if line.split(", ").size % 2 == 1
      h = Hash[ *line.split(", ") ]
      asin = h["asin"]
      @log[asin] = h if @log[asin] == nil
    end
  end

  #### show_log ####
  def show_log
    puts "#{@log.size} items"
    @log.values.each do |book|
      puts "#{book.to_a.join(", ")}"
    end
  end

  #### export_log ####
  def export_log
    open(@file, "w") do |f|
      @log.values.each do |b|
        f.puts b.to_a.join(", ")
      end
    end
  end

  #### ask ####
  def ask(asin)
    # asin in log
    return @log[asin] if @log[asin] != nil

    # init book info.
    book = Hash.new
    book['asin']   = asin    # ASIN
    book['title']  = 'NULL'  # Title
    book['author'] = 'NULL'  # Authors
    book['date']   = 'NULL'  # date
    book['url']    = 'NULL'  # url


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
        sleep(w_sec)
        redo
      else
        # success
        if res.items.size > 0
          res.items.each do |item|
            book['asin']   = item.get('ASIN')
            book['title']  = item.get('ItemAttributes/Title')
            book['author'] = item.get('ItemAttributes/Author')
            book['date']   = item.get('ItemAttributes/PublicationDate')
            book['url']    = item.get('DetailPageURL')

            # remove ',' from title & author
            book['title'].gsub!(/,/, "") if book['title'] != nil
            book['author'].gsub!(/,/, "") if book['author'] != nil
          end
        end
        break
      end
    end

    # add book to log
    @log[asin] = book
    export_log

    # return the result
    book
  end
end
