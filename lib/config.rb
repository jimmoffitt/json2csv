# encoding: UTF-8
require 'base64'
require 'yaml'
require 'fileutils'

class AppConfig

    attr_accessor :config_name, :config_path,
        #app/script configuration.
        :activity_template,  #Template for conversion process.
        :inbox,
        :outbox,
        :save_json,
        :processed_box,
        :compress_csv,
    
        :arrays_to_collapse,
        :header_overrides,
        :header_mappings

    def initialize
        #Defaults.
        @activity_template = './templates/tweet_standard.json'
        @config_path = './config' #Default to app config directory.
        @config_name = 'config.yaml'

        @inbox = './input'
        @outbox = './output'
        @save_json = true
        @processed_box = './input/processed'
        @retain_compression = true #TODO: gz in, gz out if true
        
        #These need to be unique, thus 'urls' require their parent object name.
        @arrays_to_collapse = 'hashtags,user_mentions,twitter_entities.urls,gnip.urls,matching_rules,topics'
        @header_overrides = 'actor.location.objectType,actor.location.displayName'
        @header_mappings = generate_special_header_mappings
    end

    #twitter_entities.hashtags.0.text               --> hashtags
    #twitter_entities.urls.0.url                    --> twitter_urls
    #twitter_entities.urls.0.expanded_url           --> twitter_expanded_urls
    #twitter_entities.urls.0.display_url            --> twitter_display_urls
    #twitter_entities.user_mentions.0.screen_name   --> user_mention_screen_names
    #twitter_entities.user_mentions.0.name          --> user_mention_names
    #twitter_entities.user_mentions.0.id            --> user_mention_ids
    #gnip.matching_rules.0.value                    --> rule_values
    #gnip.matching_rules.0.tag                      --> tag_values

    def generate_special_header_mappings

        mappings = Hash.new

        mappings['twitter_entities.hashtags.0.text'] = 'hashtags'
        mappings['twitter_entities.urls.0.url'] = 'twitter_urls'
        mappings['twitter_entities.urls.0.expanded_url'] = 'twitter_expanded_urls'
        mappings['twitter_entities.urls.0.display_url'] = 'twitter_display_urls'
        mappings['twitter_entities.user_mentions.0.screen_name'] = 'user_mention_screen_names'
        mappings['twitter_entities.user_mentions.0.name'] = 'user_mention_names'
        mappings['twitter_entities.user_mentions.0.id'] = 'user_mention_ids'
        mappings['gnip.matching_rules.0.value'] = 'rule_values'
        mappings['gnip.matching_rules.0.tag'] = 'rule_tags'
        mappings['gnip.language.value'] = 'gnip_lang'

        #Geographical metadata labels.
        mappings['location.geo.coordinates.0.0.0'] = 'box_sw_long'
        mappings['location.geo.coordinates.0.0.1'] = 'box_sw_lat'
        mappings['location.geo.coordinates.0.1.0'] = 'box_nw_long'
        mappings['location.geo.coordinates.0.1.1'] = 'box_nw_lat'
        mappings['location.geo.coordinates.0.2.0'] = 'box_ne_long'
        mappings['location.geo.coordinates.0.2.1'] = 'box_ne_lat'
        mappings['location.geo.coordinates.0.3.0'] = 'box_se_long'
        mappings['location.geo.coordinates.0.3.1'] = 'box_se_lat'
        mappings['geo.coordinates.0'] = 'point_long'
        mappings['geo.coordinates.1'] = 'point_lat'

        #These Klout topics need some help.
        mappings['gnip.klout_profile.topics.0.klout_topic_id'] = 'klout_topic_id'
        mappings['gnip.klout_profile.topics.0.display_name'] = 'klout_topic_name'
        mappings['gnip.klout_profile.topics.0.link'] = 'klout_topic_link'

        mappings
    end

    #Confirm a directory exists, creating it if necessary.
    def check_directory(directory)
        #Make sure directory exists, making it if needed.
        if not File.directory?(directory) then
            FileUtils.mkpath(directory) #logging and user notification.
        end
        directory
    end

    def config_file
        return @config_path + @config_name
    end

    
    def save_config_yaml
    #Write current config settings as YAML. #TODO: used? needed?
      
        settings = {}
        #Downloading, compression.
        settings['activity_template'] = @activity_template
        settings['dir_input'] = @inbox
        settings['dir_output'] = @outbox
        settings['save_json'] = @save_json
        settings['dir_processed'] = @processed_box

        settings['compress_csv'] = @compress_csv
               
        settings['arrays_to_collapse'] = @arrays_to_collapse
        settings['header_overrides'] = @header_overrides

        header_mappings = {}

        config = {}
        config['settings'] = settings
        config['header_mappings'] = header_mappings

        File.open(config_file, 'w') do |f|
            f.write config.to_yaml
        end
    end

    #Open YAML file and load settings into config object.
    def get_config_yaml

        begin
            config = YAML::load_file(config_file)
        rescue
            save_config_yaml
            config = YAML::load_file(config_file)
        end

        @activity_template = config['json2csv']['activity_template']
        @inbox = check_directory(config['json2csv']['inbox'])
        @outbox = check_directory(config['json2csv']['outbox'])
        @save_json = config['json2csv']['save_json']
        @processed_box = check_directory(config['json2csv']['processed_box'])
        @compress_csv = config['json2csv']['compress_csv']
       
        temp = config['json2csv']['arrays_to_collapse']
        if !temp.nil? then
            @arrays_to_collapse = temp
        end
        temp = config['json2csv']['header_overrides']
        if !temp.nil? then
            @header_overrides = temp
        end

        #Header mappings
        temp = config['header_mappings']
        if temp.length > 0 then
            @header_mappings = temp
        end
    end
end

#--------------------------------------------------------------------------
if __FILE__ == $0  #This script code is executed when running this file.
    oConfig = AppConfig.new
end


