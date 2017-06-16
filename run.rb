require 'typhoeus'
require 'nokogiri'
require 'byebug'
require 'mongo'
require 'json'

module Chupinhator
  class Stadium
    attr_accessor :client

    # complete: http://www.worldstadiums.com/
    STADIUMS_URL = "http://stadiumdb.com/stadiums"

    def run
      @client = Mongo::Client.new(['127.0.0.1:27017'], database: 'chupinhator', connect: :direct)
      countries = retrieve_countries
      stadiums = retrieve_stadiums(countries)

      puts countries.count
      puts stadiums.count
      save_countries(countries)
      save_stadiums(stadiums)
    end

    private

    def countries_request
      Nokogiri::HTML(Typhoeus.get(STADIUMS_URL, followlocation: true).body)
    end

    def countries_collection
      @client[:countries]
    end

    def stadiums_collection
      @client[:stadiums]
    end

    # STEP 1 - GET ALL THE COUNTRIES URL
    def retrieve_countries
      countries = []
      countries_request.css('.country-list li').each do |node|
        country = {}
        country[:url]     = node.css('a').map{|link| link['href']}.first
        country[:total]   = node.css('a strong').text
        node.css('a span').remove
        country[:country] = node.css('a').text
        #puts country
        countries << country
      end

      countries
    end

    # STEP 2 - VISIT THE COUNTRY URL
    def retrieve_stadiums(countries)
      stadiums = []

      countries.each do |country|
        result = Typhoeus.get(country[:url], followlocation: true).body
        doc = Nokogiri::HTML(result)
        stadium = {}
        doc.css('.table-stadiums tr').each do |node|
          next if node.css('a').empty?
          stadium[:url] = node.css('a').map{|link| link['href']}.first
          row = node.css('td').text.gsub!("\t", "").split("\n").reject!(&:empty?)
          stadium[:name] = row[0]
          stadium[:city] = row[1]
          stadium[:teams] = row[2]
          stadium[:capacity] = row[3].split(" ").join.to_i
          #puts stadium
          stadiums << stadium
        end
      end

      stadiums
    end

    def save_countries(countries)
      countries.each do |country|
        countries_collection.insert_one(country)
      end
    end

    def save_stadiums(stadiums)
      stadiums.each do |stadium|
        stadiums_collection.insert_one(stadium)
      end
    end
  end
end

Chupinhator::Stadium.new.run
