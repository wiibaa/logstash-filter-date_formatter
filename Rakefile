@files=[]

task :default do
  system("rake -T")
end

#require "logstash/devutils/rake"

raise "Only JRuby is supported at this time." unless RUBY_PLATFORM == "java"
require "gem_publisher"

# gem_publisher uses Open3.capture3 to call git binary
# this does not work on jruby. Open3.popen3 works
if RUBY_PLATFORM == "java"
  module GemPublisher
    class CliFacade
      def execute(*arguments)
      	puts "HELLO",arguments
      	if (arguments[0] == "gem")
      		puts "replace call to gem"
      		arguments[0] = "D:\\dev\\tools\\jruby-1.7.18\\bin\\gem.bat"
      	end
        cmd = Shellwords.join(arguments)
        Open3.popen3(cmd) do |_i, stdout, stderr, thr|
          output = [stderr.read, stdout.read].join.strip
          raise Error, output if thr.value.exitstatus > 0
          return output
        end
      end
    end
  end
end

desc "Publish gem to RubyGems.org"
task :publish_gem do |t|
  gem_file = Dir.glob("*.gemspec").first
  if gem_file.nil?
    raise "Cannot find any gemspec, checked for '*.gemspec.'" 
  end
  gem = GemPublisher.publish_if_updated(gem_file, :rubygems)
  puts "Published #{gem}" if gem
end
