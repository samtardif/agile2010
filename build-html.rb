require 'digest/sha2'
require 'json'
require 'yaml'

JSON_DATA_FILENAME = 'themes/agile2010/defaultData.js'
SPEAKER_YAML_FILENAME = 'data/speakers.yml'
TOPIC_YAML_FILENAME = 'data/topics.yml'
MANIFEST_IN_FILENAME = 'index.manifest.in'

class JSONConverter
  attr_reader :topics, :speakers

  def initialize(topics_yaml, speakers_yaml)
    @topics = YAML::load(topics_yaml) || {}
    @speakers = YAML::load(speakers_yaml) || {}

    @topics.each_pair do |t_id, data|
      begin
        t = DateTime.strptime(data['date'], '%a %I:%M%p')    # Will throw on parse error
      rescue
        puts "Topic #{t_id} has invalid date of '#{data['date']}'"
        raise
      end
      raise "Topic #{t_id} is not on Wednesday or Thursday." unless [3, 4].include? t.wday

      speakers = (data['speakers'] || '').split(',').map { |s| s.strip }.each do |s_id|
        raise "Topic #{t_id} points to a non-existant speaker #{s_id}" unless @speakers[s_id]
        raise "Speaker #{s_id} does not have a name" unless @speakers[s_id]['name']
      end
    end
  end

  def write(out)
    out.write <<-EOF
      var defaultSpeakerData = { 
        'data': #{@speakers.to_json}
      }
      var defaultSessionData = {
        'data': #{@topics.to_json}
      }
    EOF
  end
end

class ManifestProcessor
  def initialize(manifest_in)
    @lines = []

    File.open(manifest_in) do |f|
      f.readlines.each do |ln|
        ln.strip!

        if File.exists? ln
          h = Digest::SHA2.file(ln).hexdigest
          @lines << "#{ln} # #{h}"
        else
          @lines << ln
        end
      end
    end

    raise "MANIFEST template doesn't end with '.manifest.in'" unless manifest_in.end_with? '.manifest.in'
    @manifest_fn = manifest_in[/.*(?=\.in)/]
  end

  def write
    File.open(@manifest_fn, 'w') do |f|
      @lines.each { |l| f.puts l }
    end
  end
end
