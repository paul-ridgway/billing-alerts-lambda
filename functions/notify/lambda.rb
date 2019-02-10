require 'securerandom'
require 'logger'
require_relative 'log_helper'
require_relative 'notify'

L = LogHelper::logger("lambda-#{SecureRandom.uuid[-6..-1]}")

NOTIFY = Notify.new

def handler(event: , context: )
  L.info("Request received, event: #{JSON.dump(event)}, context: #{JSON.dump(context)}")

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

  NOTIFY.run

  {statusCode: 200, body: JSON.generate('Hello from Lambda!')}
end

Signal.trap(0, proc { puts "Terminating: #{$$}" })

L.info "Checking environment"
if ENV['AWS_LAMBDA_FUNCTION_NAME']
  L.info "Running in lambda"
else
  L.info "Not in lambda, running locally!"
  handler(event: {}, context: {})
end

