#!/usr/bin/env ruby
require 'json'
require 'open-uri'
require 'nkf'

################################################################################
# My Bitly
################################################################################
class MyBitly
  #### new ####
  def initialize
    # load account & api_key
    ary = open("bitly_id.txt").read.split("\n")
    @account = ary[0] # bitly account
    @api_key = ary[1] # bitly api key
  end

  #### shorten ####
  def shorten(long_url)
    # make a query
    query = "longUrl=#{CGI.escape(NKF.nkf("-w -m0", long_url))}&login=#{@account}&apiKey=#{@api_key}"
    # get short url
    n_try = 1
    w_sec = 10
    begin
      # request to bitly api
      response = Net::HTTP.get("api.bit.ly", "/v3/shorten?#{query}")
      data = JSON.parse(response)

      begin
        short_url = data["data"]["url"]
      rescue
        # wait w_sec if fail
        short_url = ""
        w_sec *= (n_try += 1)
        w_sec = 3600 if w_sec > 3600
        sleep(w_sec)
      end
    end while short_url == ""

    # return the result
    short_url
  end
end
