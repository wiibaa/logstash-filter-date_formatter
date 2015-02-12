# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "logstash/timestamp"

# The date_formatter filter is used for formatting date or timestamp from fields, 
# storing formatted string in the field defined as `target`.
#
# This filter is especially useful for creating localized
# or time-zone specific date string.
#
# For example, to format @timestamp in French locale, use this configuration:
# [source,ruby]
# filter {
#   date_formatter {
#      source => "@timestamp"
#      target => "locale_timestamp"
#      pattern => "EEE, dd MMM yyyy"
#      locale => "fr-FR"
#      timezone => "Europe/Paris"
#   }
# }
#
# Another example, to format @timestamp in Japanese, use this configuration:
# [source,ruby]
# filter {
#   date_formatter {
#      source => "@timestamp"
#      target => "japan_date"
#      pattern => "yyyy'年'MM'月'dd'日'"
#      timezone => "Japan/Tokyo"
#   }
# }
#
class LogStash::Filters::DateFormatter < LogStash::Filters::Base
  if RUBY_ENGINE == "jruby"
    JavaException = java.lang.Exception
  end

  config_name "date_formatter"

  # Specify a time zone canonical ID to be used for date formatting.
  # The valid IDs are listed on the http://joda-time.sourceforge.net/timezones.html[Joda.org available time zones page].
  # If this is not specified the platform default will be used.
  # Canonical ID is good as it takes care of daylight saving time for you
  # For example, `America/Los_Angeles` or `Europe/Paris` are valid IDs.
  #
  # This configuration can be dynamic and include parts of the event using the %{field} syntax.
  config :timezone, :validate => :string

  # Specify a locale to be used for date formatting using either IETF-BCP47 or POSIX language tag.
  # Simple examples are `en`,`en-US` for BCP47 or `en_US` for POSIX.
  #
  # The locale is mostly necessary to be set for formatting month names (pattern with `MMM`) and
  # weekday names (pattern with `EEE`).
  #
  # If not specified, the platform default will be used.
  #
  # This configuration can be dynamic and include parts of the event using the %{field} syntax.
  config :locale, :validate => :string

  # The date formats allowed are anything allowed by Joda-Time (java time
  # library). You can see the docs for this format here:
  #
  # http://joda-time.sourceforge.net/apidocs/org/joda/time/format/DateTimeFormat.html[joda.time.format.DateTimeFormat]
  #
  # This configuration can be dynamic and include parts of the event using the %{field} syntax.
  config :pattern, :validate => :string, :required => true

  # The name of the logstash event field containing the date/time value
  # to be formatted.
  # If this field is an array, only the first value will be used.
  config :source, :validate => :string, :required => true

  # Store the formatted string into the given target field.
  # You cannot use `@timestamp` as a valid target!
  config :target, :validate => :string, :required => true

  # Append values to the `tags` field when date formatting fail
  config :tag_on_failure, :validate => :array, :default => ["_dateformatfailure"]

  public
  def register
    require "java"
    if @target == "@timestamp"
      raise LogStash::ConfigurationError, I18n.t("logstash.agent.configuration.invalid_plugin_register", 
        :plugin => "filter", :type => "date_formatter",
        :error => "This filter cannot write its string result to the @timestamp field")
    end

    locale = nil
    timezone = nil
    if @locale && !@locale.index("%{").nil?
      @per_event_locale = true
    else
      locale = @locale
    end

    if @timezone && !@timezone.index("%{").nil?
      @per_event_timezone = true
    else
      timezone = @timezone
    end

    if !@pattern.index("%{").nil?
      @per_event_pattern = true
    else
      begin 
        @base_formatter = localizedFormatter(createBaseFormatter(@pattern),locale,timezone)
      rescue JavaException => e
        raise LogStash::ConfigurationError, I18n.t("logstash.agent.configuration.invalid_plugin_register",
          :plugin => "filter", :type => "date_formatter",
          :error => "#{e.message} for pattern '#{@pattern}'")
      end
    end
  end 

  def createBaseFormatter(pattern)
    return org.joda.time.format.DateTimeFormat.forPattern(pattern)
  end

  def localizedFormatter(joda_formatter,locale,timezone)
    if timezone
      joda_formatter = joda_formatter.withZone(org.joda.time.DateTimeZone.forID(timezone))
    end
    if locale
      if locale.include? '_'
        @logger.warn("Date formatter filter uses BCP47 format for locale, replacing underscore with dash")
        locale.gsub!('_','-')
      end
      joda_formatter = joda_formatter.withLocale(java.util.Locale.forLanguageTag(locale))
    end
    return joda_formatter
  end
  # def register

  def getFormatter(event)
    if @per_event_pattern || @per_event_locale || @per_event_timezone
      return localizedFormatter(
        @per_event_pattern ? createBaseFormatter(event.sprintf(@pattern)) : @base_formatter,
        @per_event_locale ? event.sprintf(@locale) : @locale,
        @per_event_timezone ? event.sprintf(@timezone) : @timezone)
    else
      #base formatter is already complete
      return @base_formatter
    end
  end

  public
  def filter(event)
    return unless filter?(event)
    return unless event.include?(@source)
    src = event[@source]
    src = src.first if src.respond_to?(:each)
    target = nil
    begin 
      case src
      when LogStash::Timestamp,Time
        target = getFormatter(event).print((src.to_f * 1000.0).to_i)
      else
        @logger.warn("Unsupporter source field. It is neither a ruby Time or a Logstash::Timestamp")
      end
    rescue JavaException => e
      @logger.warn("Failed formatting date from field", :field => @src,
                   :value => src, :exception => e.message)
      # Tag this event. We can use this later to reparse+reindex logs if necessary.
      @tag_on_failure.each do |tag|
        event["tags"] ||= []
        event["tags"] << tag unless event["tags"].include?(tag)
      end
      target = nil
    end
    if target
      event[@target] = target
      filter_matched(event)
    end
    return event
  end # def filter
end # class LogStash::Filters::DateFormatter
