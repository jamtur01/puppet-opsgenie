require 'puppet'
require 'net/https'
require 'uri'
require 'yaml'
require 'json'

unless Puppet.version.to_i >= '2.6.5'.to_i
  fail "This report processor requires Puppet version 2.6.5 or later"
end

Puppet::Reports.register_report(:opsgenie) do

  configfile = File.join([File.dirname(Puppet.settings[:config]), "opsgenie.yaml"])
  raise(Puppet::ParseError, "opsgenie report config file #{configfile} not readable") unless File.exist?(configfile)
  @config = YAML.load_file(configfile)
  KEY = @config[:key]
  RECIPIENTS = @config[:recipients]

  desc <<-DESC
  Send notification of failed reports to opsgenie.
  DESC

  def process
    if self.status == 'failed'
      message = "Puppet run for #{self.host} #{self.status} at #{Time.now.asctime}."
      begin
        timeout(8) do
          Puppet.debug "Sending status for #{self.host} to opsgenie."
          url = URI.parse("https://api.opsgenie.com/v1/json/alert")
          http = Net::HTTP.new(url.host, url.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          request = Net::HTTP::Post.new(url.request_uri, initheader = {'Content-Type' =>'application/json'})
          request.body = {
            "customerKey" => KEY,
            "recipients"  => RECIPIENTS,
            "source"      => self.host,
            "tags"        => "puppet",
            "message"     => message
          }.to_json
          response = http.request(request)
          if response.code == '200'
            Puppet.info "Alert posted to Opsgenie"
          else
            Puppet.info "Response #{response.code} #{response.message}: #{response.body}"
          end
        end
      rescue Timeout::Error
         Puppet.error "Failed to send report to opsgenie retrying..."
         max_attempts -= 1
         retry if max_attempts > 0
      end
    end
  end
end
