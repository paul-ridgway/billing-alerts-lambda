require 'json'
require 'aws-sdk'
require 'logger'

class Notify

  L = begin
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    logger
  end

  def run
    L.info("run")

    subject = 'AWS Billing Alert'

    html = process_template(template_file: 'template.html', substitutions: {subject: subject, balance: 0.99, checked: 'just now'})
    text = ''
    self.send_email(from: 'billing-alerts@ridgway.io', to: 'paul@ridgway.io', subject: subject,
                    text: text, html: html)
  end

  def process_template(template_file:, substitutions:)
    template = File.read(template_file)
    matches = template.scan(/\$\$([A-Z]{1,20})\$\$/)
    matches = Hash[matches.flatten.uniq.map {|m| [m.to_s.downcase.to_sym, m]}]
    missing = matches.keys - substitutions.keys
    if missing.size > 0
      L.warn("Missing template keys in substitutions: #{missing.join(', ')}")
    end
    matches.each {|sym, str| template.gsub!("$$#{str}$$", substitutions[sym].to_s)}
    template
  end

  def send_email(from:, to:, subject:, html:, text:)
    ses = Aws::SES::Client.new(region: 'eu-west-1')

    to = to.is_a?(Array) ? to : [to]
    begin
      options = {
        destination: {
          to_addresses: to
        },
        message: {
          body: {
            html: {
              charset: 'UTF-8',
              data: html
            },
            text: {
              charset: 'UTF-8',
              data: text
            }
          },
          subject: {
            charset: 'UTF-8',
            data: subject
          }
        },
        source: from
      }
      resp = ses.send_email(options)
      L.info('Email sent!')
    rescue Aws::SES::Errors::ServiceError => error
      L.error("Email not sent. Error message: #{error}")
      raise error
    end
  end

end

def handler(event: nil, context: nil)
  # The event payload will look something like this
  # {
  #   "version": "0",
  #   "id": "47df9fb6-e2dc-b381-7201-2ff06e9579af",
  #   "detail-type": "Scheduled Event",
  #   "source": "aws.events",
  #   "account": "181984840591",
  #   "time": "2019-02-10T13:55:32Z",
  #   "region": "eu-west-1",
  #   "resources": ["arn:aws:events:eu-west-1:181984840591:rule/billing-alert"],
  #   "detail": {}
  # }

  Notify.new.run

  {statusCode: 200, body: JSON.generate('Hello from Lambda!')}
end

unless ENV['AWS_LAMBDA_FUNCTION_NAME']
  puts "Not in lambda, running locally!"
  handler(event: {}, context: {})
end