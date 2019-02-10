require 'aws-sdk'
require_relative 'log_helper'
require 'json'
require 'time'

class Notify

  L = LogHelper::logger(self)

  def initialize
    @ses = Aws::SES::Client.new(region: 'eu-west-1')

    @account_id = ENV['ACCOUNT_ID'] || raise('ACCOUNT_ID not specified')
    @budget_name = ENV['BUDGET_NAME'] || raise('BUDGET_NAME not specified')
  end

  def run
    L.info("run, Account ID: #@account_id, Budget Name: #@budget_name")

    date = DateTime.now.strftime('%H:%M:%S')
    subject = "AWS Billing Alert at #{date}"
    html = process_template(template_file: 'template.html', substitutions: {subject: subject, balance: 0.99, checked: date})
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
