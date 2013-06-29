# = LocalizedCountrySelect
#
# View helper for displaying select list with countries:
#
#     localized_country_select(:user, :country)
#
# Works just like the default Rails' +country_select+ plugin, but stores countries as
# country *codes*, not *names*, in the database.
#
# You can easily translate country codes in your application like this:
#     <%= I18n.t @user.country, :scope => 'countries' %>
#
# Uses the Rails internationalization framework (I18n) for translating the names of countries.
#
# Use Rake task <tt>rake import:country_select 'de'</tt> for importing country names
# from Unicode.org's CLDR repository (http://www.unicode.org/cldr/data/charts/summary/root.html)
#
# Code adapted from Rails' default +country_select+ plugin (previously in core)
# See http://github.com/rails/country_select/tree/master/lib/country_select.rb
#

module LocalizedCountrySelect
  class << self
    # Returns array with codes and localized country names (according to <tt>I18n.locale</tt>)
    # for <tt><option></tt> tags
    def localized_countries_array(options={})
      exclude = Array(options[:exclude]).map {|code| code.to_s.upcase }

      if(options[:description]==:abbreviated)
        I18n.translate(:countries).map { |key, value| [key.to_s.upcase] if !exclude.include?(key.to_s.upcase) }
      else
        I18n.translate(:countries).map { |key, value| [value, key.to_s.upcase] if !exclude.include?(key.to_s.upcase) }
      end.compact.sort_by { |country| country.first.parameterize }
    end
    # Return array with codes and localized country names for array of country codes passed as argument
    # == Example
    #   priority_countries_array([:TW, :CN])
    #   # => [ ['Taiwan', 'TW'], ['China', 'CN'] ]
    def priority_countries_array(country_codes=[],options={})
      if(options[:description]==:abbreviated)
        country_codes.map { |code| [code.to_s.upcase] }
      else
        countries = I18n.translate(:countries)
        country_codes.map { |code| [countries[code.to_s.upcase.to_sym], code.to_s.upcase] }
      end
    end
  end
end

module ActionView
  module Helpers

    module FormOptionsHelper

      # Return select and option tags for the given object and method, using +localized_country_options_for_select+
      # to generate the list of option tags. Uses <b>country code</b>, not name as option +value+.
      # Country codes listed as an array of symbols in +priority_countries+ argument will be listed first
      # TODO : Implement pseudo-named args with a hash, not the "somebody said PHP?" multiple args sillines
      def localized_country_select(object, method, priority_countries = nil, options = {}, html_options = {})
        tag = if defined?(ActionView::Helpers::InstanceTag) &&
                ActionView::Helpers::InstanceTag.instance_method(:initialize).arity != 0

                InstanceTag.new(object, method, self, options.delete(:object))
              else
                CountrySelect.new(object, method, self, options)
              end

        tag.to_localized_country_select_tag(priority_countries, options, html_options)
      end
      alias_method :country_select, :localized_country_select

      # Return "named" select and option tags according to given arguments.
      # Use +selected_value+ for setting initial value
      # It behaves likes older object-binded brother +localized_country_select+ otherwise
      # TODO : Implement pseudo-named args with a hash, not the "somebody said PHP?" multiple args sillines
      def localized_country_select_tag(name, selected_value = nil, priority_countries = nil, html_options = {})
        select_tag name.to_sym, localized_country_options_for_select(selected_value, priority_countries).html_safe, html_options.stringify_keys
      end
      alias_method :country_select_tag, :localized_country_select_tag

      # Returns a string of option tags for countries according to locale. Supply the country code in upper-case ('US', 'DE')
      # as +selected+ to have it marked as the selected option tag.
      # Country codes listed as an array of symbols in +priority_countries+ argument will be listed first
      def localized_country_options_for_select(selected = nil, priority_countries = nil, options={})
        country_options = "".html_safe
        if priority_countries
          country_options += options_for_select(LocalizedCountrySelect::priority_countries_array(priority_countries, options), selected)
          country_options += "<option value=\"\" disabled=\"disabled\">-------------</option>\n".html_safe
          return country_options + options_for_select(LocalizedCountrySelect::localized_countries_array(options) - LocalizedCountrySelect::priority_countries_array(priority_countries, options), selected)
        else
          return country_options + options_for_select(LocalizedCountrySelect::localized_countries_array(options), selected)
        end
      end
      alias_method :country_options_for_select, :localized_country_options_for_select

    end

    module ToCountrySelectTag
      def to_localized_country_select_tag(priority_countries, options, html_options)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        value = value(object)
        content_tag("select",
          add_options(
            localized_country_options_for_select(value, priority_countries, options).html_safe,
            options, value
          ), html_options
        )
      end
    end

    if defined?(ActionView::Helpers::InstanceTag) &&
        ActionView::Helpers::InstanceTag.instance_method(:initialize).arity != 0
      class InstanceTag
        include ToCountrySelectTag
      end
    else
      class CountrySelect < Tags::Base
        include ToCountrySelectTag
      end
    end

    class FormBuilder
      def localized_country_select(method, priority_countries = nil, options = {}, html_options = {})
        @template.localized_country_select(@object_name, method, priority_countries, options.merge(:object => @object), html_options)
      end
      alias_method :country_select, :localized_country_select
    end

  end
end

if defined?(Rails)
  require "localized_country_select/railtie"
end
