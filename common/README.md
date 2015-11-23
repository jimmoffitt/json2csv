Collection of common classes/modules/code for working with Ruby sample code...
require_relative './common/'



#### AppLogger
A singleton logger class for a Ruby 'app'. One instance shared by many instances of other classes that support AppLogger.log calls. 

require_relative './common/app_logger'

AppLogger.initialize
AppLogger.set_logger
AppLogger.log.info("Started at #{Time.now}")

Configuration details:

```
logging:
  name: json2csv.log
  log_path: ./log/
  warn_level: info
  size: 10 #MB
  keep: 2
```


AppLogger details:

```
module AppLogger

  require 'logging'   # Based on Logging Gem.  https://github.com/TwP/logging
  require 'yaml'      # Reads in yaml config file.

  class << self       # Singleton, no need to call logger = AppLogger.new
```



  
#### insight_utils


#### pt_database



