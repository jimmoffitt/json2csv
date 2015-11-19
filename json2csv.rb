# encoding: UTF-8

require_relative './lib/converter'
require_relative './lib/config'
require_relative './common/app_logger'

#JSON --> CSV is a one-way street.

#--------------------------------------------------------------------------
#Exercising this object directly.
if __FILE__ == $0 #This script code is executed when running this file.
  
  puts "Starting..."

  oConfig = AppConfig.new #Create a configuration object.
  oConfig.get_config_yaml #defaults to './config/config.yaml'

  AppLogger.initialize
  AppLogger.set_config
  AppLogger.set_logger
  AppLogger.log.info("Started at #{Time.now}")

  convert = Converter.new(oConfig)
  convert.convert_files #Looks in oConfig data_dir and produces CSV files based on oConfig.activity_template

  AppLogger.log.info("Finished at #{Time.now}")
  
end
