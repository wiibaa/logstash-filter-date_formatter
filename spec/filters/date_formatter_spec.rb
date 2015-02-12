# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/filters/date_formatter"

puts "Skipping date formatter tests because this ruby is not jruby" if RUBY_ENGINE != "jruby"
RUBY_ENGINE == "jruby" and describe LogStash::Filters::DateFormatter do

  describe "formatting to localized pattern EEE, MMM" do
    config <<-CONFIG
      filter {
        date_formatter {
          source => "mydate"
          target => "locale_date"
          pattern => "EEEE, dd MMMM yyyy"
          locale => "fr-FR"
          timezone => "Europe/Paris"
        }
      }
    CONFIG

    sample({ "mydate" => LogStash::Timestamp.at(1423718682)}) do
      expect(subject["locale_date"]).to eq("jeudi, 12 février 2015")
    end
  end
  
  describe "Using a specific timezone" do
    config <<-CONFIG
      filter {
        date_formatter {
          source => "mydate"
          target => "locale_date"
          pattern => "yyyy-MM-dd'T'HH:mm:ss.SSSZZ"
          timezone => "Europe/Paris"
        }
      }
    CONFIG

    sample({ "mydate" => LogStash::Timestamp.at(1423718682)}) do
      expect(subject["locale_date"]).to eq("2015-02-12T06:24:42.000+01:00")
    end
  end

  describe "Using characters in the pattern" do
    config <<-CONFIG
      filter {
        date_formatter {
          source => "mydate"
          target => "japan_date"
          pattern => "yyyy'年'MM'月'dd'日'"
          timezone => "Asia/Tokyo"
        }
      }
    CONFIG

    sample({ "mydate" => LogStash::Timestamp.at(1423718682)}) do
      expect(subject["japan_date"]).to eq("2015年02月12日")
    end
  end

   describe "Supported input times are (Logstash::Timestamp, Ruby::Time)" do
    config <<-CONFIG
      filter {
        date_formatter {
          source => "mydate"
          target => "locale_date"
          pattern => "yyyy-MM-dd'T'HH:mm:ss.SSSZZ"
          timezone => "Europe/Paris"
        }
      }
    CONFIG

    sample({ "mydate" => LogStash::Timestamp.at(1423718682)}) do
      expect(subject["locale_date"]).to eq("2015-02-12T06:24:42.000+01:00")
    end
    sample({ "mydate" => Time.at(1423718682)}) do
      expect(subject["locale_date"]).to eq("2015-02-12T06:24:42.000+01:00")
    end
    sample({ "mydate" => "any string"}) do
      expect(subject["locale_date"]).to be_nil
    end
  end

  describe "Using locale and timezone from event" do
    config <<-CONFIG
      filter {
        date_formatter {
          source => "mydate"
          target => "locale_date"
          pattern => "EEEE, dd MMMM yyyy ZZ"
          locale => "%{locale}"
          timezone => "%{timezone}"
        }
      }
    CONFIG

    sample({ "mydate" => LogStash::Timestamp.at(1423718682), "locale" => "fr-Fr", "timezone" => "Europe/Paris"}) do
      expect(subject["locale_date"]).to eq("jeudi, 12 février 2015 +01:00")
    end
    sample({ "mydate" => LogStash::Timestamp.at(1423718682), "locale" => "en-US", "timezone" => "America/Los_Angeles"}) do
      expect(subject["locale_date"]).to eq("Wednesday, 11 February 2015 -08:00")
    end
  end

  describe "Using pattern from event" do
    config <<-CONFIG
      filter {
        date_formatter {
          source => "mydate"
          target => "locale_date"
          pattern => "%{pattern}"
          locale => "en-US"
          timezone => "America/Los_Angeles"
        }
      }
    CONFIG

    sample({ "mydate" => LogStash::Timestamp.at(1423718682), "pattern" => "EEEE, dd MMMM yyyy ZZ"}) do
       expect(subject["locale_date"]).to eq("Wednesday, 11 February 2015 -08:00")
    end
    sample({ "mydate" => LogStash::Timestamp.at(1423718682), "pattern" => "yyyy-MM-dd'T'HH:mm:ss.SSSZZ"}) do
       expect(subject["locale_date"]).to eq("2015-02-11T21:24:42.000-08:00")
    end
  end

  context "error handling" do
    describe "Raise configuration error when targetting @timestamp" do
      config <<-CONFIG
        filter {
          date_formatter {
            source => "mydate"
            target => "@timestamp"
            pattern => "yyyy-MM-dd"
          }
        }
      CONFIG

      sample "not_really_important" do
        expect{subject}.to raise_error(LogStash::ConfigurationError)
      end
    end

    describe "Raise configuration error for invalid pattern in #register" do
      config <<-CONFIG
        filter {
          date_formatter {
            source => "mydate"
            target => "@timestamp"
            pattern => "yyyy-MM-ddabcdef"
          }
        }
      CONFIG

      sample "not_really_important" do
        expect{subject}.to raise_error(LogStash::ConfigurationError)
      end
    end

    describe "Do not raise configuration but tag event for invalid pattern in #filter" do
      config <<-CONFIG
        filter {
          date_formatter {
            source => "mydate"
            target => "dateformatted"
            pattern => "%{pattern}"
          }
        }
      CONFIG

      sample({ "mydate" => LogStash::Timestamp.at(1423718682), "pattern" => "yyyy-MM-ddabcdef"}) do
        expect(subject["dateformatted"]).to be_nil
        expect(subject["tags"]).to include("_dateformatfailure")
      end
    end
  end
end
