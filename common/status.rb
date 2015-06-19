# encoding: UTF-8

require 'yaml'

class Status

    attr_accessor :status_name, :status_path,

        #Process modes. UI sets to true to trigger a process.
        # Process sets to false when done.
        :convert,
        :consolidate,

        :job_uuid,

        #File conversion stats --> Progress bar.
        :activities_total,
        :activities_converted,
        :files_total,
        :files_consolidated,
        
        :file_current,
        :status,
        :error

    def initialize
        @status_name = "status.yaml"
        @status_path = "./"
        @job_uuid = ""
        @status = ""
        @files_total = 0
        @files_consolidated = 0
        @error = ""
    end

    def status_file
        return @status_path + @status_name
    end

    #read file.
    def save_status

        status_hash = {}
        status_hash["job_uuid"] = @job_uuid
        #Download stats.
        status_hash["files_total"] = @files_total

        #Conversion stats.
        status_hash["activities_total"] = @activities_total
        status_hash["activities_converted"] = @activities_converted

        #Consolidation stats
        status_hash["files_consolidated"] = @files_consolidated

        #General details.
        status_hash["file_current"] = @file_current
        status_hash["status"] = @status
        status_hash["error"] = @error

        #Process modes.
        status_hash["convert"] = @convert
        status_hash["consolidate"] = @consolidate

        File.open(status_file, 'w') do |f|  #This should NEVER append.
            f.write status_hash.to_yaml
        end
    end

    #Open YAML file and load settings into config object.
    def get_status

        #Create status file if needed...
        begin
            status_hash = YAML::load_file(status_file)
        rescue
            save_status
            status_hash = YAML::load_file(status_file)
        end

        @job_uuid = status_hash["job_uuid"]

        @files_total = status_hash["files_total"]

        #Conversion stats.
        @activities_total = status_hash["activities_total"]
        @activities_converted = status_hash["activities_converted"]

        #Consolidation stats.
        @files_consolidated = status_hash["files_consolidated"]

        @file_current = status_hash["file_current"]
        @status = status_hash["status"]
        @error = status_hash["error"]

        #Process modes.
        @convert = status_hash["convert"]
        @consolidate = status_hash["consolidate"]
    end
end

#-------------------------------------------------
# Application UI code:
if __FILE__ == $0  #This script code is executed when running this file.

    oStatus = Status.new
    oStatus.files_total=2000

    #Exercise some methods.
    oStatus.save_status
    oStatus.get_status

    oStatus.files_total=100000

    oStatus.save_status

    oStatus.status = "this status"

    p oStatus.status

    p "Have converted #{oStatus.activities_converted} out of #{oStatus.activities_total} items..."

end