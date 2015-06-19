class Logger

    attr_accessor :mode #UI or (headless) script | script --> console, UI --> textbox?

    def initialize
        mode = "script"
    end

    def message(message)

        if mode == "script" then
           p message
        else
           #TODO: where to display on UI? How to 'callback'?

        end

    end

end