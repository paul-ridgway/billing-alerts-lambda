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
    @dynamodb = Aws::DynamoDB::Client.new(region: 'eu-west-1')

    @account_id = ENV['ACCOUNT_ID'] || raise('ACCOUNT_ID not specified')
    @budget_name = ENV['BUDGET_NAME'] || raise('BUDGET_NAME not specified')
    @history_table = ENV['HISTORY_TABLE'] || raise('HISTORY_TABLE not specified')
    @minimum_delta = (ENV['MINIMUM_DELTA'] || raise('MINIMUM_DELTA not specified')).to_f
    @account_name = ENV['ACCOUNT_NAME'] || raise('ACCOUNT_NAME not specified')
    @email_from = ENV['EMAIL_FROM'] || raise('EMAIL_FROM not specified')
    @email_to = ENV['EMAIL_TO'] || raise('EMAIL_TO not specified')
  end

  def run
    L.info("run, Account ID: #@account_id, Budget Name: #@budget_name")

    previous_spend = query_spend
    L.info("Previous spend: #{previous_spend}")

    budget = @budgets.describe_budget({account_id: @account_id, budget_name: @budget_name})
    budget = budget[:budget]

    L.info("Budget data: #{budget}")

    raise "Budget type must be COST" unless budget[:budget_type] == 'COST'

    spend = budget[:calculated_spend]
    actual_spend = spend[:actual_spend]

    delta = actual_spend[:amount].to_f - previous_spend.to_f

    L.info("Delta: #{delta}")

    if (delta < @minimum_delta)
      L.info("Delta is less than minimum delta of #{@minimum_delta}, nothing to do")
      record_spend(spend) if delta < 0
      return
    end

    date = DateTime.now.strftime('%H:%M:%S')
    data = {
        subject: "#{$lambda ? '' : '[DEV] '}[#{@account_name}] AWS Billing Alert at #{date}",
        actual: to_currency(actual_spend),
        forecast: (spend[:forecasted_spend][:amount].to_f <= 0) ? 'Unknown' : to_currency(spend[:forecasted_spend]),
        account: @account_name,
        checked: date}

    html = process_template(template_file: 'template.html', substitutions: data)
    text = ''

    self.send_email(from: @email_from, to: @email_to, subject: data[:subject],
                    text: text, html: html)

    record_spend(spend)

    data
  end

  def to_currency(obj)
    Money.new(obj[:amount].to_f * 100.0, obj[:unit]).format
  end

  def query_spend
    params = {
        table_name: @history_table,
        key_condition_expression: '#mon = :v1',
        expression_attribute_values: {
            ":v1" => month_key
        },
        expression_attribute_names: {
            '#mon' => 'month'
        },
        scan_index_forward: false
    }

    L.debug "Querying for movies from 1992 - titles A-L, with genres and lead actor"

    begin
      result = @dynamodb.query(params)
      L.info "Query succeeded."

      if (item = result.items.first)
        return item['actual']
      end

    rescue Aws::DynamoDB::Errors::ServiceError => error
      L.error("Query error. Error message: #{error}")
      raise error
    end
    0
  end

  def month_key
    DateTime.now.strftime('%b%Y')
  end

  def record_spend(spend)
    item = {
        month: month_key,
        timestamp: Time.now.to_i,
        actual: spend[:actual_spend][:amount],
        forecast: spend[:forecasted_spend][:amount]
    }

    begin
      result = @dynamodb.put_item({
                                      table_name: @history_table,
                                      item: item
                                  })
      L.info "Added history record: #{item}, result: #{result}"
    rescue Aws::DynamoDB::Errors::ServiceError => error
      L.error("Unable to add record. Error message: #{error}")
      raise error
    end
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
