require 'json'
require 'aws-sdk'
require 'logger'

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

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
    logger.info('Email sent!')
  rescue Aws::SES::Errors::ServiceError => error
    logger.error("Email not sent. Error message: #{error}")
    raise error
  end
end

def handler(event:, context:)
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

  send_email(sender: 'billing-alerts@ridgway.io', recipient: 'paul@ridgway.io', subject: 'AWS Billing Alert', text: 'Some body', html: 'Some html')

  {statusCode: 200, body: JSON.generate('Hello from Lambda!')}
end
