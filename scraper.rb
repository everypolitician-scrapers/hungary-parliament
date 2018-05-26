#!/bin/env ruby
# encoding: utf-8

require 'nokogiri'
require 'open-uri'
require 'scraped'
require 'scraperwiki'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def members_data(url)
  noko = noko_for(url)
  noko.xpath('.//div[@class="kepviselo-lista"]//table//tr[td]//a').flat_map do |a|
    member_data(a.text, a.attr('href'))
  end
end

def member_data(name, url)
  noko = noko_for(url)

  data = {
    id: url[/p_azon%3D(.*?)%/, 1],
    name: name,
    image: noko.css('.kepviselo-foto/@src').text,
    email: noko.xpath('.//table[.//th[contains(.,"E-mail")]]//a').text,
    source: url,
    term: 41,
  }

  group_mems = noko.xpath('.//table[.//th[contains(.,"Group membership")]]//tr[td]').select { |tr| tr.css('td').first.text.include? '2018-' }
  group_mems.map do |gm|
    tds = gm.css('td')
    mem = data.merge({
      party: tds[1].text.tidy,
      start_date: tds[2].text.split('-').reverse.join('-'),
      end_date: tds[3].text.split('-').reverse.join('-').tidy,
    })
  end
end

url = 'http://www.parlament.hu/en/web/house-of-the-national-assembly/list-of-mps'
data = members_data(url)
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite([:id, :term, :start_date], data)
