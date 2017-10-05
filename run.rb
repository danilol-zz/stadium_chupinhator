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
      @client = Mongo::Client.new(['127.0.0.1:27017'], database: 'stadium_app_development', connect: :direct)
      countries = retrieve_countries
      stadiums = retrieve_stadiums(countries)
    end

    def check
      url =  "http://stadiumdb.com/stadiums/bra/estadio_do_morumbi"
      #url = "http://stadiumdb.com/stadiums/bra"
      byebug
      result = Typhoeus.get(url, followlocation: true).body
      doc = Nokogiri::HTML(result)
      country =  Nokogiri::HTML(result)
      byebug
      country.css('.table-stadiums').xpath("//tr[position() > 1]").css('a').map{|link| link['href']}.each do |url|
      end
    end

    private

    def countries_request
      Nokogiri::HTML(Typhoeus.get(STADIUMS_URL, followlocation: true).body)
    end

    def countries_collection
      @client[:countries]
    end

    def stadiums_collection
      @client[:stadia]
    end

    # STEP 1 - GET ALL THE COUNTRIES URL
    def retrieve_countries
      countries = []
      countries_request.css('.country-list li').each do |node|
        country = {}
        country[:url]     = node.css('a').map{|link| link['href']}.first
        country[:total]   = node.css('a strong').text
        node.css('a span').remove
        country[:name] = node.css('a').text

        puts "Saving country: #{country[:name]}"
        save_country(country)
        countries << country
      end

      countries
    end

    # STEP 2 - VISIT THE COUNTRY URL AND GET STADIUM URL
    def retrieve_stadiums(countries)
      stadiums = []

      countries.each do |country|
        #Nokogiri::HTML(result).css('.table-stadiums tr td').each do |country_page|
        #country.css('.table-stadiums').xpath("//tr[position() > 1]").css('a').map{|link| link['href']}.each do |url|
        result = Typhoeus.get(country[:url], followlocation: true).body
        country =  Nokogiri::HTML(result)
        country.css('.table-stadiums').xpath("//tr[position() > 1]").each do |url|
          stadium_url  = url.css('a').map{|link| link['href']}.first
          real_name = url.css('a').text

          result = Typhoeus.get(stadium_url, followlocation: true).body

          doc = Nokogiri::HTML(result)
          #doc.xpath('//text()').find_all {|t| t.to_s.strip == ''}.map(&:remove)
          stadium = {}

          stadium[:capacity_total]      = doc.css('.stadium-info .capacity > td').text
          stadium[:capacity_additional] = doc.css('.stadium-info .capacity-comp > td').text
          stadium[:country]             = doc.css('.stadium-info .flag-m').css('a').text

          doc.css('.stadium-info tr').each do |row|
            stadium[:city]              = row.css('td').text if row.css('th').children.text == "City"
            stadium[:clubs]             = row.css('td').text if row.css('th').children.text == "Clubs"
            stadium[:other_names]       = row.css('td').text if row.css('th').children.text == "Other names"
            stadium[:inauguration]      = row.css('td').text if row.css('th').children.text == "Inauguration"
            stadium[:construction]      = row.css('td').text if row.css('th').children.text == "Construction"
            stadium[:cost]              = row.css('td').text if row.css('th').children.text == "Cost"
            stadium[:design]            = row.css('td').text if row.css('th').children.text == "Design"
            stadium[:contractor]        = row.css('td').text if row.css('th').children.text == "WContractor"
            stadium[:address]           = row.css('td').text if row.css('th').children.text == "Address"
            stadium[:cost]              = row.css('td').text if row.css('th').children.text == "Cost"
            stadium[:record_attendance] = row.css('td').text if row.css('th').children.text == "Record attendance"
          end

          stadium[:name]         = real_name || doc.css('.stadium-description h1').children.to_html.gsub("Description: ", "")
          stadium[:description]  = doc.css('.stadium-description p').children.to_html
          stadium[:images]       = []

          doc.css('.stadium-pictures li').children.each do |row|
            next if row.is_a?(Nokogiri::XML::Text)
            image = {}
            image[:url] = row.css('a').attr('href').text
            image[:alt] = row.css('img').attr('alt').text
            image[:caption] = row.css('figcaption').text
            stadium[:images] << image
          end

          puts "Saving stadium: #{stadium[:name]}"
          save_stadium(stadium)
          stadiums << stadium
        end
      end

      stadiums
    end

    def save_country(country)
      countries_collection.insert_one(country)
    end

    def save_stadium(stadium)
      stadiums_collection.insert_one(stadium)
    end
  end
end

Chupinhator::Stadium.new.run
#Chupinhator::Stadium.new.check
