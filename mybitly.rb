#!/usr/bin/env ruby

################################################################################
# require
################################################################################
require "net/http"
#require 'open-uri'
require "cgi"
require "nkf"
require "json"

################################################################################
# My Bitly
################################################################################
class MyBitly
  #### new ####
  def initialize
    # load account & api_key
    ary = open("./ids/bitly_id.txt").read.split("\n")
    @account = ary[0] # bitly account
    @api_key = ary[1] # bitly api key
  end

  #### shorten ####
  def shorten(long_url)
    # make a query
    query = "login=#{@account}&apiKey=#{@api_key}"
    query += "&longUrl=#{CGI.escape(NKF.nkf("-w -m0", long_url))}"

    # get short url
    n_try = 0
    w_sec = 10
    begin
      begin
        # request to bitly api
        response = Net::HTTP.get("api.bit.ly", "/v3/shorten?#{query}")
        data = JSON.parse(response)
        short_url = data["data"]["url"]
      rescue
        # wait w_sec if fail
        puts "status = #{data["status_txt"]} (#{data["status_code"]})"
        if data["status_code"].to_i == 500
          puts "long_url = #{long_url}"
        end
        short_url = ""
        w_sec *= (n_try += 1)
        w_sec = 3600 if w_sec > 3600
        puts "wait #{w_sec} sec (#{Time.now})"
        sleep(w_sec)
      end

      sleep(0) # wait for safe
    end while short_url == ""

    # return the result
    short_url
  end
end
