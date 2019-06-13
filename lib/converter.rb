require_relative '../common/app_logger'
#include AppLogger

class String
  def is_i?
    !!(self =~ /^[-+]?[0-9]+$/)
  end
end

class Converter

  require 'json'
  require 'csv'
  require 'fileutils'

  attr_accessor :config,
                :keys, #An array that holds the flattened keys of the tweet hash.
                :key_name #Name of current key we are building with dot notation.

  def initialize(config)
    @config = config
    @keys = Array.new
  end

  def deep_copy(o)
    Marshal.load(Marshal.dump(o))
  end

  #A look before leaping function that sets root 'simple' keys.
  #Reserves all root primitive keys (like id, links, etc.) before touring any subkey hashes.
  def get_root_simple_keys(tweet)

    #Tour the root level of the Tweet hash build the keys array.
    tweet.each do |key, value|
      #p "keys: " + @keys.to_s
      @key_name = "" #Here at the root level so initialize.
      @level = "root"
      case value
        when Numeric, String, false, true
          #handle_simple(value)
          @keys << key #Reached end-point.
      end
    end
  end

  #Generates keys from a Tweet.  Inspects each root key and branches to handle JSON arrays or hashes.  If the
  #root key is a simple type, we are done and have the final key name.
  def get_keys(tweet)

    get_root_simple_keys(tweet)

    #Tour the root level of the Tweet hash build the keys array.
    tweet.each do |key, value|
      #p "keys: " + @keys.to_s
      @key_name = "" #Here at the root level so initialize.
      @level = "root"
      case value
        when Numeric, String, false, true
          #pass, already picked up in get_root_simple_keys.
        when Hash
          @key_name = key
          handle_hash(value) #go off and handle hashes!
        when Array
          @key_name = key
          handle_array(value) #go off and handle arrays!
        else
          AppLogger.log.warn("WARN: Unexpected type in Tweet hash: #{value}")
      end
    end

    return @keys
  end

  def primitive_array(string)
    if string.scan('{').count == 0 and string.scan('[').count == 1 then
      return true
    end
    return false
  end


  #Recursive function, called for Arrays.
  #"location": {
  #    "geo": {
  #       "coordinates": [
  #       [
  #            [
  #                -80.160648,
  #                43.286245
  #           ],
  #           [
  #                -80.160648,
  #               43.734448
  #            ],
  #           [
  #                 -79.479201,
  #                43.734448
  #           ],
  #        [
  #            -79.479201,
  #            43.286245
  #        ]
  #    ]
  #  ]
  # }
  #}
  #hash --> hash --> array --> array --> array #WHICH SEEMS WRONG, but that is what we get...
  # STILL TRUE IN ORIGINAL?
  #location.geo.coordinates.0.0.0
  #location.geo.coordinates.0.1.1
  #location.geo.coordinates.1.0.0
  #location.geo.coordinates.1.1.0
  #location.geo.coordinates.2.0.0
  #location.geo.coordinates.2.1.1
  #location.geo.coordinates.3.0.0
  #location.geo.coordinates.3.1.1


  def handle_array(array)

    name_root = @key_name
    #Now examine value to determine its type.

    @level = @level + '.array'

    #if @key_name == 'location.geo.coordinates' then
    #    p 'stop'
    #end

    #p "Level coming into array: #{@level} --> Handling array: #{array.to_s}, arriving with name: #{@key_name}"

    key = -1

    array.each { |value|

      #p array.to_s

      key = key + 1

      if primitive_array(array.to_s) and key > 0 then
        @key_name = "#{@key_name.split(".")[0..-2].join(".")}.#{key}"

      else
        @key_name = "#{@key_name}.#{key}"
      end

      case value
        when Numeric, String, NilClass, false, true
          @keys << "#{@key_name}" #Done here.

        when Hash
          #@name = "#{@name}.#{key}"
          handle_hash(value) #go off and handle hashes!
          if key == (array.length - 1) then
            @key_name = name_root.split(".")[0..-2].join(".")
          end
        when Array
          #name = "#{name}.#{key}"
          handle_array(value) #go off and handle arrays!
          if key == (array.length - 1) then
            @key_name = name_root.split(".")[0..-2].join(".")
          end
        else
          AppLogger.log.warn("WARNING: Unexpected type in Tweet array: #{value}")
      end
    }

    @key_name = name_root.split(".")[0..-2].join(".")
    @level = @level.split(".")[0..-2].join(".")
  end

  #Recursive function, called for Hashes.
  #Arrived here with a Hash key, so walk that to find "end.points" (either simple or array)
  def handle_hash(hash)

    #p "Handling hash: #{hash.to_s}, arriving with name: #{@key_name}"

    @level = @level + '.hash'

    hash_item = 0

    #Tour this hash determining the value types.
    hash.each { |key, value|

      hash_item = hash_item + 1

      case value

        when Numeric, String, NilClass, false, true
          @keys << "#{@key_name}.#{key}" #Done here.

          #reset key_name back if array?
          begin
            #Float(@key_name.split(".")[-1])
            if hash.length == hash_item then
              @key_name = @key_name.split(".")[0..-2].join(".")
            end
          rescue Exception => e
            AppLogger.log.error("Error in handle_hash method: #{e.message}")
          end

        when Hash
          @key_name = "#{@key_name}.#{key}"
          handle_hash(value) #go off and handle hashes!
          if hash_item == hash.length then
            @key_name = @key_name.split(".")[0..-2].join(".")
          end
        when Array
          @key_name = "#{@key_name}.#{key}"
          handle_array(value) #go off and handle arrays!
          if hash_item == hash.length then
            @key_name = @key_name.split(".")[0..-2].join(".")
          end
        else
          AppLogger.log.warn("WARNING: Unexpected type in Tweet hash: #{value}")
      end
    }

    @level = @level.split(".")[0..-2].join(".")
  end

  #With simple 'keys' we just add the key name to the keys array.
  def handle_simple(value)
    @keys << @key_name
  end

  #Header is built once per file set.
  def build_header(keys_template)
    header = ''
    names = []
    keys = deep_copy(keys_template)

    keys.each { |key|
      begin
        if @config.header_mappings.any? { |k| k.include? key }

          header_label = key

          @config.header_mappings.each { |k, v|
            if header_label.include? k
              header_label.gsub!(k, v)
            end

          }
          names << header_label

        elsif @config.header_overrides.split(',').include?(key)
          names << key
        elsif key.include?('coordinates')
          names << key
        elsif key.split('.')[-1].is_i?
          names << key
        else
          #We want to grab the last element and add it to the array.
          name = key.split(".")[-1]

          if !names.include?(name)
            names << name
          else
            if key.split(".")[-2].is_i?
              name = key.split(".")[-3..-1].join(".")
            else
              name = key.split(".")[-2..-1].join(".")
            end

            if !names.include?(name)
              names << name
            else
              name = key.split(".")[-3..-1].join(".")
              if !names.include?(name)
                names << name
              else
                #p "No action taken. #{name} not added to name array. (build_header)"
              end
            end
          end
        end
      rescue Exception => e
        AppLogger.log.error("ERROR in build_header method with #{key}: #{e.message}")
      end
    }

    header = CSV.generate do |csv|
      csv << names
    end

    header
  end

  def get_data(tweet_hash, key)

    lookup = tweet_hash

    keys = key.split(".")

    keys.each { |key|

      #p key

      if key.to_f < 0
        AppLogger.log.error("ERROR with negative key #{key}")
      end

      begin
        #if !key.is_a?(Numeric) then
        lookup = lookup[key]
      rescue
        lookup = lookup[key.to_i]
      end
    }

    begin
      if key.split(".")[-1] == "id"
        lookup = lookup.split(":")[-1]
      end
    rescue
      #do nothing, this is a media or user_mention id, with no ":" delimiters.
    end

    #Remove newline characters on the way out.
    #TODO: gsub errors with numerics.
    begin
      if lookup.is_a? String and !lookup.nil?
        lookup.gsub!(/\n/, "")
      end
    rescue Exception => e
      AppLogger.log.error("ERROR in get_data method, removing new lines: #{e.message}")
    end

    lookup
  end

  #Flattens an array of hashes, such as:
  # entities.hashtags
  # entities.user_mentions
  # entities.urls
  # matching_rules
  # TODO: gnip.klout_profile.topics
  #These are specified by the @config.arrays_to_collapse setting.

  #Template Tweet provides the following example keys:
  #entities.hashtags.0.text
  #entities.urls.0.url
  #entities.urls.0.expanded_url
  #entities.urls.0.display_url
  #entities.user_mentions.0.screen_name
  #entities.user_mentions.0.name
  #entities.user_mentions.0.id
  #matching_rules.0.value
  #matching_rules.0.tag

  #Note that target Tweet will often have multiple item arrays, and those are the metadata that we are
  #flattening here.
  #TODO: confirm that since the template will never (?) have multiple arrays (really a doc issue) or the generation
  #TODO: of template keys needs to ignore items after the first one...

  def get_collapsed_array_data(activity_hash, key)
    #p "Have key: #{key}.  Need to load the data!"

    #Load array of hashes using key up to array numeric index.
    #gnip.matching_rules.0.value
    # --> gnip.matching_rules points to array of hashes.
    # --> value points to hash key to grab, once for each array member.

    parts = key.split(/\d+/)

    if parts.length == 2
      data_pointers = parts[0]
      data_members = parts[1]
    elsif
      AppLogger.log.warn("WARN: in get_collapsed_array_data method, unexpected length of data member... may need special logic")
    end

    #Split data members' dot-notation to gets keys to traverse.
    keys = data_pointers.split('.')

    target_data = Hash.new
    target_data = activity_hash.clone
    #Use keys to get data array.
    keys.each { |index|
      target_data = target_data[index].clone
    }

    #Examine data members, this should be a single entity.
    data_member = data_members.split('.')

    if data_member.length == 2
      data_member = data_member[-1].to_s
    elsif
      AppLogger.log.warn("WARN: in get_collapsed_array_data method, unexpected length of data member... may need special logic")
    end

    data = ""

    target_data.each { |item|

      if !item[data_member].nil?
        data = data + item[data_member].to_s + ','
      else
        data = data + ','
      end
    }

    #Assemble comma-delimited values of hash keys.
    data.chomp(',')
  end

  #Main method that manages conversion process.
  def convert_files

    AppLogger.log.info("Starting JSON to CSV conversion.")
    start_time = Time.now

    #Load keys from the Tweet Template.
    activity_template_file = @config.tweet_template
    contents = File.read(activity_template_file)
    activity_template = JSON.parse(contents)
    keys_template = Array.new
    keys_template = get_keys(activity_template)
    #Initialize @keys
    @keys = Array.new

    #Build header based on these keys.
    header = build_header(keys_template)

    #TODO - if we are handling compressed files, unzip, convert, then rezip?

    #tour output folder with current UUID and convert files

    Dir.glob("#{@config.inbox}/*.json") do |file|

      AppLogger.log.debug("DEBUG, convert_files: Converting #{File.basename(file)} file...")


      csv_filename = "#{@config.outbox}/#{File.basename(file, ".*")}.csv"
      csv_file = File.open(csv_filename, "w")
      csv_file.puts header

      #This file has one or more activities in it, with a "info" footer.
      contents = File.read(file)

      activities = []

      #Inspect contents and determine the source of the data... Search API, HPT?
      #Markers:
      #  Search API: file starts with '{"results":[' or '{"next":['.
      #  HPT: last line is a "info" footer.
      #  Realtime: contents start with '{"id":'.  ##Not handling this yet....

      if (contents.start_with?('{"results":[') or contents.start_with?('{"next":'))

        json_contents = JSON.parse(contents)

        json_contents["results"].each do |activity|
          activities << activity.to_json
        end

      elsif contents.include?('"info":{"message":"Replay Request Completed"')

        contents.split("\r")[0..-2].each { |line| #drop last "info" member.
          #Dev TODO: just added the "id": match, untested
          if line.include?('created_at') or line.include?('postedTime')
            activities << line
          end
        }
		 
	  else

		 contents.split("\n").each { |line| #drop last "info" member.
			#Dev TODO: just added the "id": match, untested
			if line.include?('retweetCount') or line.include?('retweet_count')
			   activities << line
			end
		 }

      end

      activities.each { |activity|

        begin
          activity_hash = JSON.parse(activity)
        rescue Exception => e
          AppLogger.log.error("ERROR in convert_files: could not parse activity's JSON: #{e.message}")
        end

        keys_activity = Array.new
        keys_activity = get_keys(activity_hash)

        #Initialize @keys
        @keys = Array.new

        #OK, time to compare this activity's payload with the template and grab only the matching keys.
        csv_array = []

        keys_template.each { |key_template|

          if keys_activity.include?(key_template)

            #p "matched on #{key_template}"

            if @config.arrays_to_collapse.split(',').any? { |item| key_template.include?(item) }
              #p "NEED TO HANDLE SPECIAL CASE: #{key_template}"
              data = get_collapsed_array_data(activity_hash, key_template)
            else
              #Go get this data and add it to csv_array
              data = get_data(activity_hash, key_template)
            end

            csv_array << data
          else
            csv_array << nil
          end
        }

        #Write csv array to CSV.
        csv_activity = CSV.generate do |csv|
          csv << csv_array
        end

        csv_file.puts csv_activity.to_s
      }

      csv_file.close #Close new CSV file.


      if (!@config.save_json)
        File.delete(file) #Delete json version.
      else #Move it to 'processed' folder.
        FileUtils.mv(file, "#{@config.processed_box}/#{file.split('/')[-1]}")
      end
    end

    AppLogger.log.info("Finished JSON to CSV conversion. Conversion required #{Time.now - start_time} seconds.")

  end

end
