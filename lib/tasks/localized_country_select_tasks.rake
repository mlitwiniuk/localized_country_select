require 'rubygems'
require 'open-uri'

# Rake task for importing country names from Unicode.org's CLDR repository
# (http://www.unicode.org/cldr/data/charts/summary/root.html).
# 
# It parses a HTML file from Unicode.org for given locale and saves the 
# Rails' I18n hash in the plugin +locale+ directory
# 
# Don't forget to restart the application when you add new locale to load it into Rails!
# 
# == Parameters
#   LOCALE (required): Sets the locale to use. Output file name will include this.
#   FORMAT (optional): Output format, either 'rb' or 'yml'. Defaults to 'rb' if not specified.
#   WEB_LOCALE (optional): Forces a locale code to use when querying the Unicode.org CLDR archive.
#
# == Examples
#   rake import:country_select LOCALE=de
#   rake import:country_select LOCALE=pt-BR WEB_LOCALE=pt FORMAT=yml
# 
# The code is deliberately procedural and simple, so it's easily
# understandable by beginners as an introduction to Rake tasks power.
# See https://github.com/svenfuchs/ruby-cldr for much more robust solution

namespace :import do

  desc "Import country codes and names for various languages from the Unicode.org CLDR archive. Depends on Hpricot gem."
  task :country_select do
    begin
      require 'hpricot'
    rescue LoadError
      puts "Error: Hpricot library required to use this task (import:country_select)"
      exit
    end
    
    # TODO : Implement locale import chooser from CLDR root via Highline
    
    # Setup variables
    locale = ENV['LOCALE']
    unless locale
      puts "\n[!] Usage: rake import:country_select LOCALE=de\n\n"
      exit 0
    end

    # convert locale code to Unicode.org CLDR acceptable code
    web_locale = if ENV['WEB_LOCALE'] then ENV['WEB_LOCALE']
                 elsif %w(zht zhtw).include?(locale.downcase.gsub(/[-_]/,'')) then 'zh_Hant'
                 elsif %w(zhs zhcn).include?(locale.downcase.gsub(/[-_]/,'')) then 'zh_Hans'
                 else locale.underscore.split('_')[0] end

    # ----- Get the CLDR HTML     --------------------------------------------------
    begin
      puts "... getting the HTML file for locale '#{web_locale}'"
      doc = Hpricot( open("http://www.unicode.org/cldr/data/charts/summary/#{web_locale}.html") )
    rescue => e
      puts "[!] Invalid locale name '#{web_locale}'! Not found in CLDR (#{e})"
      exit 0
    end


    # ----- Parse the HTML with Hpricot     ----------------------------------------
    puts "... parsing the HTML file"
    countries = []
    doc.search("//tr").each do |row|
      if row.search("td[@class='n']") && 
         row.search("td[@class='n']").inner_html =~ /^namesterritory$/ && 
         row.search("td[@class='g']").inner_html =~ /^[A-Z]{2}/
        code   = row.search("td[@class='g']").inner_text
        code   = code[-code.size, 2]
        name   = row.search("td[@class='v']").inner_text
        countries << { :code => code.to_sym, :name => name.to_s }
        print " ... #{name}"
      end
    end


    # ----- Prepare the output format     ------------------------------------------

    format = if ENV['FORMAT'].nil?||%(rb ruby).include?(ENV['FORMAT'].downcase) then :rb
             elsif %(yml yaml).include?(ENV['FORMAT'].downcase) then :yml end

    unless format
      puts "\n[!] FORMAT must be either 'rb' or 'yml'\n\n"
      exit 0
    end

    if format==:yml
      output =<<HEAD
#{locale}:
  countries:
HEAD
      countries.each do |country|
        output << "    #{country[:code]}: \"#{country[:name]}\"\n"
      end

    else # rb format
    output = "#encoding: UTF-8\n"
    output <<<<HEAD
{ :#{locale} => {

    :countries => {
HEAD
    countries.each do |country|
      output << "\t\t\t:#{country[:code]} => \"#{country[:name]}\",\n"
    end
    output <<<<TAIL
    } 

  }
}
TAIL
    end

    # ----- Write the parsed values into file      ---------------------------------
    puts "\n... writing the output"
    filename = Rails.root.join('config', 'locales', "countries.#{locale}.#{format}")
    if filename.exist?
      filename = Pathname.new("#{filename.to_s}.NEW")
    end
    File.open(filename, 'w+') { |f| f << output }
    puts "\n---\nWritten values for the '#{locale}' into file: #{filename}\n"
    # ------------------------------------------------------------------------------
  end

end
