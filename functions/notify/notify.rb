require 'aws-sdk'
require 'json'
require 'time'
require 'money'
require_relative 'log_helper'

Money.locale_backend = nil

class Notify

  L = LogHelper::logger(self)

  def initialize
    @ses = Aws::SES::Client.new(region: 'eu-west-1')
    @budgets = Aws::Budgets::Client.new(region: 'us-east-1')

    @account_id = ENV['ACCOUNT_ID'] || raise('ACCOUNT_ID not specified')
    @budget_name = ENV['BUDGET_NAME'] || raise('BUDGET_NAME not specified')
  end

  def run
    L.info("run, Account ID: #@account_id, Budget Name: #@budget_name")

    budget = @budgets.describe_budget({account_id: @account_id, budget_name: @budget_name})
    budget = budget[:budget]

    L.info("Budget data: #{budget}")

    raise "Budget type must be COST" unless budget[:budget_type] == 'COST'

    spend = budget[:calculated_spend]
    date = DateTime.now.strftime('%H:%M:%S')
    data = {
        subject: "#{$lambda ? '' : '[DEV] '}AWS Billing Alert at #{date}",
        actual: to_currency(spend[:actual_spend]),
        forecast: to_currency(spend[:forecasted_spend]),
        checked: date}

    html = process_template(template_file: 'template.html', substitutions: data)
    text = ''

    self.send_email(from: 'billing-alerts@ridgway.io', to: 'paul@ridgway.io', subject: data[:subject],
                    text: text, html: html)
  end

  def to_currency(obj)
    Money.new(obj[:amount].to_f * 100.0, obj[:unit]).format
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
      resp = @ses.send_email(options)
      L.info("Email sent - #{resp}")
    rescue Aws::SES::Errors::ServiceError => error
      L.error("Email not sent. Error message: #{error}")
      raise error
    end
  end

end
