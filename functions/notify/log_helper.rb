require 'logging'

module LogHelper
  # here we setup a color scheme called 'bright'
  Logging.color_scheme('bright',
                       :levels => {
                           :info => :green,
                           :warn => :yellow,
                           :error => :red,
                           :fatal => [:white, :on_red]
                       },
                       :date => :blue,
                       :logger => :cyan,
                       :message => :white
  )

  Logging.appenders.stdout(
      'stdout',
      :layout => Logging.layouts.pattern(
          :pattern => '[%d] %-5l %c - %m\n',
          :color_scheme => 'bright'
      )
  )

  def self.logger(identifier)
    log = Logging.logger[identifier]
    log.add_appenders 'stdout'
    log.level = :info
    log
  end

end
