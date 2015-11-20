# json2csv

### JSON to CSV is a one-way street...

### Overview

The 'json2csv' tool manages the conversion of Gnip Activity Stream (AS) JSON to the comma separated values (CSV) format. Tweet attributes of interest are indicated by referencing a Tweet Template of choice. If the Tweet Template has an attribute it will be written to the output CSV files. If the Template does not have the attribute, it is dropped and not written. You can design your own Tweet Template, or use one of the provided example Templates.

This tool pulls JSON Tweets from an input folder and attempts to convert all *.json and *.json.gz files it finds there, writing the 
resulting CSV files to an output folder. This tool works with Activity Stream Tweet JSON produced with Gnip Full-Archive Search, 30-Day Search, and Historical PowerTrack. This tool was designed to convert JSON tweets in bulk, and retains the JSON filename, e.g. MyTweets.json --> MyTweets.csv.
 
The json2csv tool is configured with a single [YAML](http://yaml.org/) file and provides basic logging. This tool is written in Ruby and references a few basic gems (json, csv, and logging). 

One of the first steps is to 'design' (or choose from our examples) a [Tweet Template](#tweet-templates) which identifies all the Tweet attributes that you are interested in. The conversion process uses this template and creates a CSV file with a column for every attribute in the template. The conversion process represents an opportunity to 'tune' what you want to export. For example, the standard Twitter metadata includes the numeric character position of hashtags in a tweet message. You may decide that you do not need this information, and therefore can omit those details from your Tweet template.

Before deciding to perform this type of conversion, you should consider the following trade-offs:

1. JSON data is multi-dimensional, with multiple levels of nested data. However, CSVs are two dimensional. Converting from JSON to CSV means that you are sacrificing detail and flexibility in the data by either flattening it, or discarding some fields from the data.
2. If you are consuming the data into a custom app, retaining the data in JSON provides a level of flexibility not available with CSVs.  For example, field order is not important in JSON, where column order in CSVs is very important (and therefore, arguably more fragile). 
3. It is recommended to save the source JSON. It represents all the available metadata. You may decide to go back and convert metadata you did not include the first time. 

##### Some things this tool does not do

+ May not support 'original' Tweet format. (The Converter Class knows about JSON, CSV, Hashes, and Arrays, but shouldn't care whether it is 'original' or 'Activity Stream' format.  Configured 'attribute' mappings depend on the format, but hopefully the conversion code does not. 
+ This tool does not consolidate files or compile data. See [consolidator project] for the ability to consolidate 10-minute Historical PowerTrack files into hourly or daily files, or 500-Tweet Search response files into larger files.

### Getting Started

#### Installing tool

+ Clone respository.
+ bundle install.
+ Select a Tweet Template.
+ Configure the config.yaml. Its defaults provide a place to start.
+ Place Tweet JSON files to convert in the app's inbox. This project includes an 'inbox' of Tweets. These Tweets were posted by the Gnip Twitter account during October 2015.
+ Run $ruby json2csv.rb 
+ Look for CSV files in the app's outbox.

#### Configuring json2csv

This tool defaults to ./config/config.yaml for its configuration/settings file. Below are all of the default settings. If the configured directories do not exist they will be automatically created.

```
json2csv:
  activity_template: ./templates/tweet_standard.json
  inbox: ./inbox
  outbox: ./outbox
  save_json: true
  processed_box: ./input/processed
  compress_csv: false #TODO: conventions? retain compression?

  arrays_to_collapse: hashtags,user_mentions,twitter_entities.urls,gnip.urls,matching_rules,topics
  header_overrides: actor.location.objectType,actor.location.displayName

header_mappings: {}

logging:
  name: json2csv.log
  log_path: ./log/
  warn_level: info
  size: 10 #MB
  keep: 2

```


#### Tweet Templates<a id="tweet-templates" class="tall">&nbsp;</a>

A Tweet Template is an example tweet payload in JSON that contains all the fields you want to export to the CSV files. Social activities, such as tweets, are dynamic in nature and the payloads from one tweet to another are sure to be different. One could be a geo-tagged tweet with several hashtags and mentions, while the next one is a retweet with an URL.

This example tweet is referred to as the conversion 'tweet template.' The conversion process loads this template and then tours each of your historical tweets and exports all metadata that is specified in the template. Here is a short example template that would export the bare minimum of metadata:

<pre>
{
  "id": "tag:search.twitter.com,2005:418130988250570752",
  "actor": {
    "id": "id:twitter.com:17200003",
    "preferredUsername": "jimmoffitt",
  },
  "verb": "post",
  "postedTime": "2013-12-31T21:26:10.000Z",
  "body": "Example tweet #HashTag1 #HashTag2"
   "twitter_entities": {
    "hashtags": [
      {"text": "HashTag1"},
      {"text": "HashTag2"}
    ]
}
</pre>

This would be represented in a CSV file as:

<pre>
id,actor.id,preferredUsername,verb,postedTime,body,hashtags
418130988250570752,17200003,jimmoffitt,post,2013-12-31T21:26:10.000Z,Example tweet #HashTag1 #HashTag2,"HashTag1,HashTag2"
</pre>

A couple things to note about this JSON to CSV conversion:

+ Tweet and User IDs have been stripped down to just the numeric content.
+ Dot notation is used to preserve hierarchy when needed. In this case it was used to handle the repeated use of 'id'.
+ Dot notation names can be overridden (such as hashtags in this example).
+ Arrays are stored as comma-separated values inside double quotes.


#### Example Tweet Templates

It can be difficult and time-consuming to find just the perfect tweet 'in the wild', an actual tweet that encapsulates all metadata you care about. So you may need to 'hand build' your own template tweet. The means assembling an JSON object by picking and choosing the fields you want and copying them into a JSON file. When doing this, keep the following details in mind:

+ Tweet template JSON must be valid for the conversion code to work. If the conversion code can not parse the template JSON then it will exit. There are many on-line validators to confirm your JSON is formatted correctly.
+ Order of objects does not absolutely matter.  You could have the actor object below the twitter entities object. However, the order will affect the order of the CSV columns in the output.
+ Array attributes only need an array length of one. The conversion process knows to export all array elements it finds.
+ Hierarchy matters. If you skip or add a level in the template, that 'pattern' will not be found in the processed tweets. For example:
 ```
  gnip.matching_rules.0.value != gnip.matching_rules.value
 ```
 The matching_rules attribute is an array so ```gnip.matching_rules.0.value``` will match, while ```gnip.matching_rules.value``` will not.
+ Metadata values do not have to be internally consistent since the values of the JSON name/value pairs does not matter. All that matters are the JSON names. With the template tweet examples below you will see inconsistencies. For example the geographic metadata can be inconsistent with an actor location in one place and the Gnip Profile Geo in another.

Here are several pre-built examples:

+ ['Standard' Tweet Template](https://github.com/jimmoffitt/json2csv/blob/master/templates/tweet_standard.json) (tweet_standard.json): Handles both original Tweets and Retweets. No Twitter geo metadata, all twitter entities included with select attributes (i.e., no hashtag indices), includes standard Gnip enrichments (matching rules, urls, language). Retweets are indicated by verb, original tweet id, and author name/id.
+ ['Tweet IDs' Tweet Template](https://github.com/jimmoffitt/json2csv/blob/master/templates/tweet_ids.json) (tweet_ids.json): For selecting just the numeric Tweet IDs.
+ ['User IDs' Tweet Template](https://github.com/jimmoffitt/json2csv/blob/master/templates/user_ids.json) (user_ids.json): For selecting just the numeric User IDs.
+ ['Small' Tweet Template](https://github.com/jimmoffitt/json2csv/blob/master/templates/tweet_small.json) (tweet_small.json): For selecting just the basics.
+ ['Everything' Retweet Template](https://github.com/jimmoffitt/json2csv/blob/master/templates/tweet_everything.json) (tweet_everything.json): Includes complete data, including the full Retweet and nested Tweet. Includes all Twitter entities and all attributes (like hashtag indices), Twitter geo metadata, and all Gnip enrichments.
+ ['Standard + Geo' Tweet Template](https://github.com/jimmoffitt/json2csv/blob/master/templates/tweet_standard_geo.json) (tweet_standard_geo.json): Same as the 'Standard' template, but also includes Twitter geo metadata.
+ ['Profile Geo' Tweet Template](https://github.com/jimmoffitt/json2csv/blob/master/templates/tweet_profile_geo.json) (tweet_profile_geo.json): Same as 'Standard Geo' Template, with the addition of the Profile Geo enrichment.
+ ['All gnip enrichments' Tweet Template](https://github.com/jimmoffitt/json2csv/blob/master/templates/tweet_all_enrichments.json) (tweet_all_enrichments.json): Same as 'Profile Geo' Template, with the addition of Klout Topics data.

#### Use-case Examples
+ Coverting JSON to CSV for importing into spreadsheets, relational databases, and legacy systems.
 + [tweet_ids.json](https://github.com/jimmoffitt/json2csv/blob/master/templates/tweet_standard.json) is a good place to start.
+ Extract only Tweet IDs for input into an Engagement API client.
 + [tweet_ids.json](https://github.com/jimmoffitt/json2csv/blob/master/templates/tweet_ids.json)
+ Extract only User IDs for input into an Engagement API client.
 +  [user_ids.json](https://github.com/jimmoffitt/json2csv/blob/master/templates/user_ids.json)

### Details, Details, Details

##### How are CSV column names determined?

CSV column names are generated by referencing the JSON object names and using dot notation to indicate levels and arrays of attributes. For example, here are some JSON attributes:

<pre>
{
    "id": "tag:search.twitter.com,2005:418130988250570752",
    "actor": {
        "id": "id:twitter.com:17200003"
    },
    "twitter_entities": {
        "hashtags": [
            {
                "text": "HappyNewYear",
            }
        ]
    }
}
</pre>

Using dot notation, these attributes would be represented with the following header:

<pre>
id, actor.id, twitter_entities.hashtags[0].text
</pre>


##### Is there any special parsing of JSON values?
Yes, Tweet and Actor IDs are handled specially. For these IDs, the string component is stripped off and only the numeric part is retained. So this JSON...

<pre>
{
    "id": "tag:search.twitter.com,2005:418130988250570752",
    "actor": {
        "id": "id:twitter.com:17200003"
    }
}
</pre>

... Gets converted to this CSV:

<pre>
id, actor.id
418130988250570752,17200003
</pre>


##### What if I want special names for certain columns?
With dot notation and the many levels of JSON attributes the auto-generated names can become quite long.  Therefore you may want to override these defaults with shortened versions. The conversion process already has some 're-mappings' built-in, and others can be added when wanted.  Here are some examples:

<pre>
twitter_entities.hashtags.0.text               --> hashtags
twitter_entities.urls.0.expanded_url           --> twitter_expanded_urls
twitter_entities.user_mentions.0.screen_name   --> user_mention_screen_names
gnip.matching_rules.0.value                    --> rule_values
</pre>

The following Ruby method from the ./lib/config.rb AppConfig class encapsulates all the 'header overrides'. These default overrides are stored in a hash of (key, value) pairs, where the key is the header that is 'organically' generated by as the JSON attributes are converted to dot notation names, and the value is what is instead used in the CSV header. 

If you want to extend this hash, you can either edit the ```generate_special_header_mappings``` method, or configure them in the ```config.yaml``` configuration file under the ```header_mappings:``` section:

```
   header_mappings: {"actor.summary": "profile_bio"}
```

```
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
```

##### How are arrays of metadata handled?

Twitter metadata include many attributes that have a variable length list of values. Examples include hashtags, user mentions, and URLs. These example metadata are stored in a JSON object named 'twitter_entities' and each attribute is an array of length zero or more.  Arrays in CSV are stored with double-quotes around a comma-delimited list of values. So these arrays can be thought of as a list within another list.

Using the hashtag example, multiple hashtags would be inserted into a single column with the 'hashtags' column header (relying on the built-in header override discussed above):

<pre>
id,actor.id,hashtags
418130988250570752,17200003,"HashTag1,HashTag2"
</pre>

##### How long will the conversion process take?
It depends on how many files are being processed, how many tweets are being converted, and how many attributes are included in the template tweet. If there are 10 million tweets, and 200 tweet attributes in the template, there are 2 billion attributes to process.

Using a [standard template tweet] (https://github.com/jimmoffitt/pt-dm/blob/master/schema/tweet_standard.json) approximately 5 million tweets can be processed per hour. Massive datasets can take hours to process. I wonder how fast it would run if written in Python...

##### Some coding conventions/details...

File handling:
 + name
 + dir, whether it ends with a separator should not matter.
 + path = dir + name
 + Need to document compression logic w.r.t. gz in, gz out
 + Configured directories should be created if needed.
 
Logging: 
 + gem install 'logging'
 + AppLogger is a singleton logging class. One instance per application/tool.


 








