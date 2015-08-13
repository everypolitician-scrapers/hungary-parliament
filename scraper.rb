#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'
require 'cgi'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

@BASE = 'http://www.parlament.hu/en/web/house-of-the-national-assembly/list-of-mps'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
  # Nokogiri::HTML(open(url).read, nil, 'utf-8')
end

def scrape_list(url)
  noko = noko_for(url)
  noko.xpath('.//div[@class="kepviselo-lista"]//table//tr[td]//a').each do |a|
    scrape_mp(a.text, a.attr('href'))
  end
end

def scrape_mp(name, url)
  noko = noko_for(url)

  data = { 
    id: url[/p_azon%3D(.*?)%/, 1],
    name: name,
    image: noko.css('.kepviselo-foto/@src').text,
    email: noko.xpath('.//table[.//th[contains(.,"E-mail")]]//a').text,
    term: 40,
    source: @BASE,
  }

  group_mems = noko.xpath('.//table[.//th[contains(.,"Group membership")]]//tr[td]').select { |tr| tr.css('td').first.text.include? '2014-' }
  group_mems.each do |gm|
    tds = gm.css('td')
    mem = data.merge({ 
      party: tds[1].text.tidy,
      start_date: tds[2].text.split('-').reverse.join('-'),
      end_date: tds[3].text.split('-').reverse.join('-').tidy,
    })
    ScraperWiki.save_sqlite([:id, :term], mem)
  end
end

scrape_list(@BASE)
