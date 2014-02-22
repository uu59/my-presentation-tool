# -- coding: utf-8

require "grill"

Grill.implant <<-G
gem "haml", "~> 4.0.0"
gem "slim", "~> 2.0.2"
gem "sprockets", "~> 2.11.0"
gem "sass"
gem "pry"
gem "sinatra", "~> 1.4.4", :require => "sinatra/base"
gem "coffee-script"
gem "pygments.rb", :require => "pygments"
gem "httpclient"
gem "nokogiri"
G

map '/assets' do
  environment = Sprockets::Environment.new
  environment.append_path 'src/assets/js'
  environment.append_path 'src/assets/css'
  environment.append_path 'src/assets/images'
  Dir.glob("bower_components/*/dist/").each{|d| environment.append_path d}
  run environment
end

class Myapp < Sinatra::Base
  set :haml, :format => :html5, :layout_options => { :views => "src/layout" }
  set :layout_engine => :haml
  set :views, settings.root + "/src/texts"

  helpers do
    def highlight(lang, code)
      Pygments.highlight(strip_heredoc(code), :lexer => lang)
        .sub("<pre>", "<pre>\n") # なんかズレるのでhack
    end

    def strip_heredoc(str)
      # http://apidock.com/rails/String/strip_heredoc
      indent = (str.scan(/^[ \t]*(?=\S)/).min || "").size || 0
      str.gsub(/^[ \t]{#{indent}}/, '')
    end
  end

  get "/:name" do |name|
    type, _ = Tilt.mappings.find do |ext, engines|
      path = ::File.join(settings.views, "#{name}.#{ext}")
      ::File.exists?(path)
    end
    halt 404 unless type
    @title = name
    send(type, name.to_sym)
  end

  get "/:name/build" do |name|
    fetch = proc do |path|
      url = path.start_with?("http") ? path : "http://#{env["HTTP_HOST"]}#{path}"
      HTTPClient.get(url).body
    end
    html = fetch["/#{name}"]

    doc = Nokogiri::HTML.parse(html)
    doc.xpath('//script[@src] | //link[@href] | //img[@src]').each do |asset|
      key = asset[:src] ? :src : :href
      path = asset[key]
      if path.match(/\.js$/)
        asset.remove_attribute(key.to_s)
        asset.content = fetch[path]
      else
        content = fetch[path]
        content.scan(%r!url\((.*?)\)!).each do |matches|
          url = matches.first
          content.gsub!(url, "data:image/png;base64," << [fetch[url]].pack("m").tr("\n",""))
        end
        data = [content].pack('m').tr("\n","")
        asset[key] = "data:text/css;base64,#{data}"
      end
    end
    doc.to_html
  end
end

map "/" do
  run Myapp
end
