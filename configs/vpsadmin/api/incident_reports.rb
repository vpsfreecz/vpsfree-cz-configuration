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

      body.each_line do |line|
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
      incidents = {}

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

              key = "#{assignment.user_id}:#{assignment.vps_id}:#{assignment.ip_addr}:#{row['feed_name']}"
              incident = incidents[key]

              next if incident && incident.detected_at > time

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
                  begin
                    text << sprintf("  %-18s: %s\n", k, v)
                  rescue Encoding::CompatibilityError
                    next
                  end
                end
              end

              incidents[key] = ::IncidentReport.new(
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

      incident_list = incidents.values.sort do |a, b|
        a.detected_at <=> b.detected_at
      end

      now = Time.now
      proki_cooldown = ENV['PROKI_COOLDOWN'] ? ENV['PROKI_COOLDOWN'].to_i : 7*24*60*60

      incident_list.select! do |incident|
        existing = ::IncidentReport.where(
          user_id: incident.user_id,
          vps_id: incident.vps_id,
          ip_address_assignment_id: incident.ip_address_assignment_id,
          codename: incident.codename,
        ).order('created_at DESC').take

        if existing && existing.created_at + proki_cooldown > now
          warn "PROKI: found previous incident ##{existing.id} for "+
               "user=#{existing.user_id} vps=#{existing.vps_id} "+
               "ip=#{existing.ip_address_assignment.ip_addr} code=#{existing.codename}"
          next(false)
        else
          incident.save! unless dry_run?
          next(true)
        end
      end

      if incident_list.empty?
        warn "PROKI: no new incidents found"
      end

      incident_list
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

      incident = ::IncidentReport.new(
        user_id: assignment.user_id,
        vps_id: assignment.vps_id,
        ip_address_assignment: assignment,
        mailbox: mailbox,
        subject: subject,
        text: text,
        detected_at: time,
      )

      incident.save! unless dry_run?
      [incident]
    end
  end

  class Fail2BanParser < VpsAdmin::API::IncidentReports::Parser
    include ParserUtils

    def parse
      body = message.decoded

      if /^This is an email abuse report about the IP address (.+) generated at ([^$]+?)$/ !~ body
        warn "Fail2Ban: IP / date not found"
        return []
      end

      addr_str = $1
      time_str = $2

      begin
        # Fri Sep 15 18:55:37 EEST 2023
        time = DateTime.strptime(time_str, '%a %b %d %H:%M:%S %Z %Y').to_time
      rescue Date::Error => e
        warn "Fail2Ban: invalid timestamp #{time_str.inspect}"
        return []
      end

      assignment = find_ip_address_assignment(addr_str, time: time)

      if assignment.nil?
        warn "Fail2Ban: IP #{addr_str} not found"
        return []
      end

      subject = strip_rt_prefix(message.subject)
      text = strip_rt_header(body)

      if body.empty?
        warn "Fail2Ban: empty message body"
        return []
      end

      incident = ::IncidentReport.new(
        user_id: assignment.user_id,
        vps_id: assignment.vps_id,
        ip_address_assignment: assignment,
        mailbox: mailbox,
        subject: subject,
        text: text,
        detected_at: time,
      )

      incident.save! unless dry_run?
      [incident]
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

      incident = ::IncidentReport.new(
        user_id: assignment.user_id,
        vps_id: assignment.vps_id,
        ip_address_assignment: assignment,
        mailbox: mailbox,
        subject: subject,
        text: text,
        detected_at: time,
      )

      incident.save! unless dry_run?
      [incident]
    end
  end

  class SpamCopParser < VpsAdmin::API::IncidentReports::Parser
    include ParserUtils

    def parse
      body = message.decoded

      if /^Email from ([^\s]+) \/ ([^$]+?)$/ !~ body
        warn "SpamCop: IP / date not found"
        return []
      end

      addr_str = $1
      time_str = $2

      begin
        time = DateTime.rfc2822(time_str).to_time
      rescue Date::Error => e
        warn "SpamCop: invalid timestamp #{time_str.inspect}"
        return []
      end

      assignment = find_ip_address_assignment(addr_str, time: time)

      if assignment.nil?
        warn "SpamCop: IP #{addr_str} not found"
        return []
      end

      subject = strip_rt_prefix(message.subject)
      text = strip_rt_header(body)

      if body.empty?
        warn "SpamCop: empty message body"
        return []
      end

      incident = ::IncidentReport.new(
        user_id: assignment.user_id,
        vps_id: assignment.vps_id,
        ip_address_assignment: assignment,
        mailbox: mailbox,
        subject: subject,
        text: text,
        detected_at: time,
      )

      incident.save! unless dry_run?
      [incident]
    end
  end

  class UsGoParser < VpsAdmin::API::IncidentReports::Parser
    include ParserUtils

    def parse
      if !message.multipart? || message.parts.length < 3
        warn "USGO: expected a 3-part message, got #{message.parts.length} parts"
        return []
      end

      feedback = message.parts[1].decoded

      if /^Source-IP: ([^$]+?)$/ !~ feedback
        warn "USGO: IP not found"
        return []
      end

      addr_str = $1

      if /^Received-Date: ([^\(]+)/ !~ feedback
        warn "USGO: datetime not found"
        return []
      end

      time_str = $1

      begin
        time = DateTime.rfc2822(time_str).to_time
      rescue Date::Error => e
        warn "USGO: invalid timestamp #{time_str.inspect}"
        return []
      end

      assignment = find_ip_address_assignment(addr_str, time: time)

      if assignment.nil?
        warn "USGO: IP #{addr_str} not found"
        return []
      end

      body = message.parts[0].decoded

      subject = strip_rt_prefix(message.subject)
      text = strip_rt_header(body)

      spam_body = message.parts[2].decoded
      text << "\n\nOffending message:\n\n#{spam_body}"

      if body.empty?
        warn "USGO: empty message body"
        return []
      end

      incident = ::IncidentReport.new(
        user_id: assignment.user_id,
        vps_id: assignment.vps_id,
        ip_address_assignment: assignment,
        mailbox: mailbox,
        subject: subject,
        text: text,
        detected_at: time,
      )

      incident.save! unless dry_run?
      [incident]
    end
  end

  handle_message do |mailbox, message, dry_run:|
    check_sender = ENV['CHECK_SENDER'] ? %w(y yes 1).include?(ENV['CHECK_SENDER']) : true
    processed = true

    incidents =
      if /^\[rt\.vpsfree\.cz \#\d+\] PROKI \- upozorneni na nalezene incidenty/ =~ message.subject \
        && (!check_sender || message['X-RT-Originator'].to_s == 'proki@csirt.cz')
        proki = ProkiParser.new(mailbox, message, dry_run: dry_run)
        proki.parse

      elsif /^\[rt\.vpsfree\.cz \#\d+\] Your server [^ ]+ has been registered as an attack source$/ =~ message.subject \
        && (!check_sender || message['X-RT-Originator'].to_s == 'info@bitninja.com')
        bitninja = BitNinjaParser.new(mailbox, message, dry_run: dry_run)
        bitninja.parse

      elsif /^\[rt\.vpsfree\.cz \#\d+\] \[LeakIX\] Critical security issue for / =~ message.subject \
        && (!check_sender || message['X-RT-Originator'].to_s == 'apiguardian@leakix.net')
        leakix = LeakIXParser.new(mailbox, message, dry_run: dry_run)
        leakix.parse

      elsif /^\[rt\.vpsfree\.cz \#\d+\] \[SpamCop \(/ =~ message.subject \
        && (!check_sender || message['X-RT-Originator'].to_s.end_with?('@reports.spamcop.net'))
        spamcop = SpamCopParser.new(mailbox, message, dry_run: dry_run)
        spamcop.parse

      elsif /^\[rt\.vpsfree\.cz \#\d+\] Abuse Feedback Report for / =~ message.subject \
        && (!check_sender || message['X-RT-Originator'].to_s == 'DoNotReply@USGOabuse.net')
        usgo = UsGoParser.new(mailbox, message, dry_run: dry_run)
        usgo.parse

      elsif /^\[rt\.vpsfree\.cz \#\d+\] Automatic abuse report for IP address / =~ message.subject \
        && (!check_sender || message['X-RT-Originator'].start_with?('fail2ban@'))
        f2b = Fail2BanParser.new(mailbox, message, dry_run: dry_run)
        f2b.parse
      else
        warn "#{mailbox.label}: unidentified message subject=#{message.subject.inspect}, originator=#{message['X-RT-Originator']}"
        processed = false
        []
      end

    VpsAdmin::API::IncidentReports::Result.new(
      incidents: incidents,
      reply: {
        from: 'vpsadmin@vpsfree.cz',
        to: ['abuse-komentare@vpsfree.cz'],
      },
      processed: processed,
    )
  end
end
