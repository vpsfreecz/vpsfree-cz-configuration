require 'csv'
require 'date'
require 'stringio'
require 'time'
require 'zip'

VpsAdmin::API::IncidentReports.config do
  module ParserUtils
    def strip_rt_prefix(subject)
      closing_bracket = subject.index(']')
      return subject if closing_bracket.nil?

      ret = subject[(closing_bracket+1)..-1].strip
      ret.empty? ? 'No subject' : ret
    end

    def strip_rt_header(body)
      ret = ''
      append = false

      body.split("\n").each do |line|
        if line.lstrip.start_with?('Ticket <URL: ')
          append = true
        elsif append
          ret << line
        end
      end

      ret.strip
    end
  end

  class ProkiParser < VpsAdmin::API::IncidentReports::Parser
    def parse
      incidents = []

      message.attachments.each do |attachment|
        next if !attachment.content_type.start_with?('application/zip')

        string_io = StringIO.new(attachment.decoded)

        Zip::InputStream.open(string_io) do |io|
          while entry = io.get_next_entry
            next unless entry.name.end_with?('.csv')

            csv = CSV.parse(io.read, col_sep: ',', quote_char: '"', headers: true)
            csv.each do |row|
              time = Time.iso8601(row['time_detected'])

              assignment = find_ip_address_assignment(row['ip'], time: time)

              if assignment.nil?
                warn "PROKI: IP #{row['ip']} not found"
                next
              end

              text = <<END
Česky:
Jménem Národního bezpečnostního týmu CSIRT.CZ Vám, v rámci projektu PRedikce a
Ochrana před Kybernetickými Incidenty (PROKI, ID: VI20152020026) realizovaném
v rámci Programu bezpečnostního výzkumu ČR na léta 2015 – 2020, zasíláme
souhrnný report o IP adresách z Vaší sítě, které byly vyhodnoceny jako
potenciálně škodlivé.

English:
On behalf of the National Security Team CSIRT.CZ and in connection with the
project Prediction and Protection against Cybernetic Incidents (PROKI, ID:
VI20152020026) implemented under the Security Research Program of the Czech
Republic for the years 2015–2020, we are sending you a comprehensive report on
the IP addresses from your network that have been evaluated as potentially
harmful.

Report:

END

              row.each do |k, v|
                next if k == 'raw'
                text << sprintf("%-20s: %s\n", k, v)
              end

              text << sprintf("%-20s:\n", 'raw')

              raw = CSV.parse(row['raw'], col_sep: ',', quote_char: '"', row_sep: '\n', headers: true)
              raw.each do |raw_row|
                raw_row.each do |k, v|
                  text << sprintf("  %-18s: %s\n", k, v)
                end
              end

              incidents << ::IncidentReport.create!(
                user_id: assignment.user_id,
                vps_id: assignment.vps_id,
                ip_address_assignment: assignment,
                mailbox: mailbox,
                subject: "PROKI #{row['feed_name']} #{time.strftime('%Y-%m-%d')}",
                text: text,
                codename: row['feed_name'],
                detected_at: time,
              )
            end
          end
        end
      end

      incidents
    end
  end

  class BitNinjaParser < VpsAdmin::API::IncidentReports::Parser
    include ParserUtils

    def parse
      if /Your server ([^ ]+) has been/ !~ message.subject
        warn "BitNinja: source IP not found"
        return []
      end

      addr_str = $1

      body = message.decoded

      # . is instead of nonbreaking space...
      if /Timestamp \(UTC\):.(\d+\-\d+\-\d+ \d+:\d+:\d+)/ !~ body
        warn "BitNinja: timestamp not found"
        return []
      end

      time_str = $1

      begin
        time = DateTime.strptime("#{time_str} UTC", '%Y-%m-%d %H:%M:%S %Z').to_time
      rescue Date::Error => e
        warn "BitNinja: invalid timestamp #{time_str.inspect}"
        return []
      end

      assignment = find_ip_address_assignment(addr_str, time: time)

      if assignment.nil?
        warn "BitNinja: IP #{addr_str} not found"
        return []
      end

      subject = strip_rt_prefix(message.subject)
      text = strip_rt_header(body)

      if body.empty?
        warn "BitNinja: empty message body"
        return []
      end

      [::IncidentReport.create!(
        user_id: assignment.user_id,
        vps_id: assignment.vps_id,
        ip_address_assignment: assignment,
        mailbox: mailbox,
        subject: subject,
        text: text,
        detected_at: time,
      )]
    end
  end

  class LeakIXParser < VpsAdmin::API::IncidentReports::Parser
    include ParserUtils

    def parse
      if /Critical security issue for ([^$]+)$/ !~ message.subject
        warn "LeakIX: source IP not found"
        return []
      end

      addr_str = $1

      body = message.decoded

      if /\|\s+Discovered\s+\|\s+(\d+ \w+ \d+ \d+:\d+ UTC)/ !~ body
        warn "LeakIX: timestamp not found"
        return []
      end

      time_str = $1

      begin
        time = DateTime.strptime("#{time_str} UTC", '%d %b %y %H:%M %Z').to_time
      rescue Date::Error => e
        warn "LeakIX: invalid timestamp #{$1.inspect}"
        return []
      end

      assignment = find_ip_address_assignment(addr_str, time: time)

      if assignment.nil?
        warn "LeakIX: IP #{addr_str} not found"
        return []
      end

      subject = strip_rt_prefix(message.subject)
      text = strip_rt_header(body)

      if body.empty?
        warn "LeakIX: empty message body"
        return []
      end

      [::IncidentReport.create!(
        user_id: assignment.user_id,
        vps_id: assignment.vps_id,
        ip_address_assignment: assignment,
        mailbox: mailbox,
        subject: subject,
        text: text,
        detected_at: time,
      )]
    end
  end

  handle_message do |mailbox, message|
    if /^\[rt\.vpsfree\.cz \#\d+\] PROKI - upozorneni na nalezene incidenty/ =~ message.subject \
      && message['X-RT-Originator'] == 'proki@csirt.cz'
      proki = ProkiParser.new(mailbox, message)
      next proki.parse

    elsif /^\[rt\.vpsfree\.cz \#\d+\] Your server [^ ]+ has been registered as an attack source$/ =~ message.subject \
      && message['X-RT-Originator'] == 'info@bitninja.com'
      bitninja = BitNinjaParser.new(mailbox, message)
      next bitninja.parse

    elsif /^\[rt\.vpsfree\.cz \#\d+\] \[LeakIX\] Critical security issue for / =~ message.subject \
      && message['X-RT-Originator'] == 'apiguardian@leakix.net'
      leakix = LeakIXParser.new(mailbox, message)
      next leakix.parse
    end

    []
  end
end
