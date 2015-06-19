# encoding: UTF-8

require_relative './common/config'
require_relative './common/status'
require_relative './common/logger'  #Not implemented yet.

require 'csv'
require 'json'

#JSON --> CSV is a one-way street.

class String
    def is_i?
        !!(self =~ /^[-+]?[0-9]+$/)
    end
end

class Converter

    attr_accessor :config,
                  :status,

                  :keys,        #An array that holds the flattened keys of the tweet hash.
                  :key_name,    #Name of current key we are building with dot notation.
                  :level,        #A debugging attribute, really, tracks the array/hash levels.

                  :experiment   #operates on one at a time, does not delete source.   #TODO

                  #Design/feature ideas...
                  #:source_file,
                  #:target_file

    def initialize(config, status = nil, logger = nil)
        @config = config
        @keys = Array.new

        if status.nil? then
            @status = Status.new
        else
            @status = status
        end

        if logger.nil? then
            @logger = Logger.new
        else
            @logger = logger
        end

        @keys = Array.new
        #@source_file = PtFile.new
        #@target_file = PtFile.new
    end

    def deep_copy(o)
        Marshal.load(Marshal.dump(o))
    end

    #A look before leaping function that sets root 'simple' keys.
    #Reserves all root primitive keys (like id, links, etc.) before touring any subkey hashes.
    def get_root_simple_keys(activity)

        #Tour the root level of the activity hash build the keys array.
        activity.each do |key,value|
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

    #Generates keys from an activity.  Inspects each root key and branches to handle JSON arrays or hashes.  If the
    #root key is a simple type, we are done and have the final key name.
    def get_keys(activity)

        get_root_simple_keys(activity)

        #Tour the root level of the activity hash build the keys array.
        activity.each do |key,value|
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
                    p 'ERROR: Unexpected type in activity hash.'
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
    #hash --> hash --> array --> array --> array #WHICH SEEMS WRONG, but that is what we get!
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

                    #p @key_name

                    #reset key_name back if array?
                    #begin
                    #    Float(@key_name.split(".")[-1])
                    #    @key_name = @key_name.split(".")[0..-2].join(".")
                    #rescue ArgumentError, TypeError
                    #end
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
                    p 'Unexpected type in activity array.'
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
        #p "Level coming into hash: #{@level}"

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
                    rescue ArgumentError, TypeError
                        p 'stop'
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
                    p 'Unexpected type in activity hash.'
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

        keys.each {|key|
            begin
                if @config.header_mappings.any? { |k| k.include? key} then

                   header_label = key

                   @config.header_mappings.each {| k,v|
                       if header_label.include? k then
                           header_label.gsub!(k,v)
                       end

                   }
                   names << header_label

                elsif @config.header_overrides.split(',').include?(key) then
                    names << key
                elsif key.include?('coordinates') then
                    names << key
                elsif key.split('.')[-1].is_i? then
                    names << key
                else
                    #We want to grab the last element and add it to the array.
                    name = key.split(".")[-1]

                    if !names.include?(name) then
                        names << name
                    else
                        if key.split(".")[-2].is_i? then
                            name = key.split(".")[-3..-1].join(".")
                        else
                            name = key.split(".")[-2..-1].join(".")
                        end

                        if !names.include?(name) then
                            names << name
                        else
                            name = key.split(".")[-3..-1].join(".")
                            if !names.include?(name) then
                                names << name
                            else
                                p 'Need to go deeper?'
                            end
                        end
                    end
                end
            rescue
                p "ERROR with key: #{key}"
            end
        }

        header = CSV.generate do |csv|
            csv << names
        end

        header
    end

    def get_data(activity_hash,key)

        lookup = activity_hash

        keys = key.split(".")

        #value = keys.inject(activity_hash) { |hash, key| key.get_value(hash) rescue break("not here") }
        #value = keys.inject(activity_hash) { |hash, key| hash[key] rescue break("not here") }

        keys.each { |key|

            #p key

            if key.to_f < 0 then
                p 'stop'
            end

            begin
                #if !key.is_a?(Numeric) then
                lookup = lookup[key]
            rescue
                lookup = lookup[key.to_i]
            end
        }

        begin
            if key.split(".")[-1] == "id" then
                lookup = lookup.split(":")[-1]
            end
        rescue
            #do nothing, this is a media or user_mention id, with no ":" delimiters.
        end

        #p "key #{key} has value: #{lookup} "

        #Remove newline characters on the way out.
        #TODO: gsub errors with numerics.
        begin
            if !lookup.nil? then
                lookup.gsub!(/\n/,"")
            end
        rescue
            #p "#{key} returning #{lookup}"
        end

        lookup
    end

    #Flattens an array of hashes, such as:
    # twitter_entities.hashtags
    # twitter_entities.user_mentions
    # twitter_entities.urls
    # gnip.urls
    # gnip.matching_rules
    # gnip.klout_profile.topics
    #These are specified by the @config.arrays_to_collapse setting.

    #Template activity provides the following example keys:
    #twitter_entities.hashtags.0.text
    #twitter_entities.urls.0.url
    #twitter_entities.urls.0.expanded_url
    #twitter_entities.urls.0.display_url
    #twitter_entities.user_mentions.0.screen_name
    #twitter_entities.user_mentions.0.name
    #twitter_entities.user_mentions.0.id
    #gnip.matching_rules.0.value
    #gnip.matching_rules.0.tag

    #Note that target activity will often have multiple item arrays, and those are the metadata that we are
    #flattening here.
    #TODO: confirm that since the template will never (?) have multiple arrays (really a doc issue) or the generation
    #TODO: of template keys needs to ignore items after the first one...

    def get_collapsed_array_data(activity_hash,key)
       #p "Have key: #{key}.  Need to load the data!"

       #Load array of hashes using key up to array numeric index.
       #gnip.matching_rules.0.value
       # --> gnip.matching_rules points to array of hashes.
       # --> value points to hash key to grab, once for each array member.

       parts = key.split(/\d+/)

       if parts.length == 2 then
            data_pointers = parts[0]
            data_members = parts[1]
       elsif
           p "Hmmmm...  double array needs special logic."
       end

       #Split data members' dot-notation to gets keys to traverse.
       keys = data_pointers.split('.')

       target_data = Hash.new
       target_data = activity_hash.clone
       #Use keys to get data array.
       keys.each {|index|
           target_data = target_data[index].clone

           #p target_data
       }

       #Examine data members, this should be a single entity.
       data_member = data_members.split('.')

       if data_member.length == 2 then
          data_member = data_member[-1].to_s
       elsif
            p "Hmmmm...  double data member needs special logic."
       end

       data = ""

       target_data.each { |item|

           if !item[data_member].nil? then
               data = data + item[data_member].to_s + ','
           else
               data = data + ','
           end
       }

       #Assemble comma-delimited values of hash keys.
        data.chomp(',')
    end

    def check_converted

        unconverted = 0
        converted = 0

        #count the lines in CSV files, minus header.
        Dir.glob("#{@config.dir_output}/*#{@config.job_uuid}*.json") do |file|
            unconverted = unconverted + (File.read(file).scan(/\n/).count - 1 )
        end

        #count the lines in CSV files, minus header.
        Dir.glob("#{@config.dir_input}/*#{@config.job_uuid}*.csv") do |file|
            converted = converted + (File.read(file).scan(/\n/).count - 1 )
        end

        p "Found #{converted} converted activities..."
        @status.activities_converted = converted
        @status.activities_total = converted + unconverted
        @status.save_status
    end


    #Test conversion.
    def convert_test

    end

    #Main method that manages conversion process.
    def convert_files

        #If there are CSVs files, assess how many activities have been converted already.
        check_converted

        if @status.activities_converted > 0 and (@status.activities_converted >= @status.activities_total) then
            p 'All activities already converted.'
            return
        end

        #Load keys from the Tweet Template.
        activity_template_file = @config.activity_template
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

        Dir.glob("#{@config.dir_input}/*#{@config.job_uuid}*.json") do |file|

            #p file
            csv_filename = "#{@config.dir_output}/#{File.basename(file, ".*")}.csv"
            csv_file = File.open(csv_filename, "w")
            csv_file.puts header

            #This file has one or more activities in it, with a "info" footer.
            contents = File.read(file)
            activities = []
            contents.split("\n")[0..-2].each { |line|    #drop last "info" member.
                #Dev TODO: just added the "id": match, untested
                if line.include?('"id":"') then
                    activities << line
                end
            }

            activities.each { |activity|

                #p '==== New Activity ===================='
                @status.activities_converted = @status.activities_converted + 1

                if (@status.activities_converted % 1000) == 0 then
                    @status.save_status

                    @status.get_status
                    if @status.convert == false then
                        @logger.message 'Disabled, stopping conversion and exiting.'
                        exit
                    end
                end

                begin
                    activity_hash = JSON.parse(activity)
                rescue
                    p 'Error'
                end

                keys_activity = Array.new
                keys_activity = get_keys(activity_hash)

                #Initialize @keys
                @keys = Array.new

                #OK, time to compare this activity's payload with the template and grab only the matching keys.
                csv_array = []
                #p activity_hash

                keys_template.each { |key_template|

                    if keys_activity.include?(key_template) then

                        #p "matched on #{key_template}"

                        if @config.arrays_to_collapse.split(',').any? { |item| key_template.include?(item) } then
                            #p "NEED TO HANDLE SPECIAL CASE: #{key_template}"
                            data = get_collapsed_array_data(activity_hash,key_template)
                        else
                            #Go get this data and add it to csv_array
                            data = get_data(activity_hash,key_template)
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
            File.delete(file) #Delete json version.
        end
    end
end

#--------------------------------------------------------------------------
#Exercising this object directly.
if __FILE__ == $0  #This script code is executed when running this file.

    #Config and Status objects are helpful.
    oConfig = Config.new  #Create a configuration object.
    oConfig.config_path = './config'  #This is the default, by the way, so not mandatory in this case.
    oConfig.config_name = 'config.yaml'
    oConfig.get_config_yaml

    oStatus = Status.new #Create a Status file.
    #And load its contents.
    oStatus.get_status
    oStatus.status = 'Starting. Checking for things to do.'

    convert = Converter.new(oConfig,oStatus,nil)
    convert.convert_files #Looks in oConfig data_dir and produces CSV files based on oConfig.activity_template

end
