require 'json'
require 'aws-sdk'

def send_email(event)
    event = JSON.dump(event)
    
    sender = "aws-billing-alerts@ridgway.io"
    recipient = "paul@ridgway.io"
    subject = "Amazon SES test (AWS SDK for Ruby)"
    htmlbody =
      '<h1>Amazon SES test (AWS SDK for Ruby)</h1>'\
      '<p>This email was sent with <a href="https://aws.amazon.com/ses/">'\
      'Amazon SES</a> using the <a href="https://aws.amazon.com/sdk-for-ruby/">'\
      'AWS SDK for Ruby</a>.<pre>' + event + '</pre>'
    textbody = "This email was sent with Amazon SES using the AWS SDK for Ruby.\n#{event}"
    
    # Create a new SES resource and specify a region
    ses = Aws::SES::Client.new(region: 'eu-west-1')
    
    # Try to send the email.
    begin
    
      # Provide the contents of the email.
      resp = ses.send_email({
        destination: {
          to_addresses: [
            recipient,
          ],
        },
        message: {
          body: {
            html: {
              charset: "UTF-8",
              data: htmlbody,
            },
            text: {
              charset: "UTF-8",
              data: textbody,
            },
          },
          subject: {
            charset: "UTF-8",
            data: subject,
          },
        },
      source: sender
      })
      puts "Email sent!"
    
    # If something goes wrong, display an error message.
    rescue Aws::SES::Errors::ServiceError => error
      puts "Email not sent. Error message: #{error}"
    
    end

end


def handler(event:, context:)
    send_email(event)
    { statusCode: 200, body: JSON.generate('Hello from Lambda!') }
end
