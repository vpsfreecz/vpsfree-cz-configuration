require 'csv'
require 'stringio'
require 'time'
require 'zip'

module AbuseNoticeParser
  class Proki < VpsAdmin::API::IncidentReports::Parser
    IGNORED_CODENAMES = [
      'Accessible-FTP',
      'Accessible-HTTP',
      'Accessible-SMTP',
      'Accessible-SSH',
      'Accessible-SSL',
      'Device-Identification IPv4',
      'Device-Identification IPv6',
      'IPv6-Accessible-FTP',
      'IPv6-Accessible-HTTP',
      'IPv6-Accessible-SMTP',
      'IPv6-Accessible-SSH',
      'IPv6-Accessible-SSL',
    ]

    def self.match_subject?(subject)
      subject.start_with?('PROKI - upozorneni na nalezene incidenty')
    end

    def self.match_sender?(from)
      from == 'proki@csirt.cz'
    end

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
              codename = row['feed_name']

              if codename && IGNORED_CODENAMES.include?(codename.strip)
                warn "PROKI: ignoring codename #{codename}"
                next
              end

              begin
                time = Time.iso8601(row['time_detected'])
              rescue ArgumentError => e
                warn "PROKI: unable to parse time of detection: #{e.message}"
                next
              end

              assignment = find_ip_address_assignment(row['ip'], time: time)

              if assignment.nil?
                warn "PROKI: IP #{row['ip']} not found"
                next
              end

              key = "#{assignment.user_id}:#{assignment.vps_id}:#{assignment.ip_addr}:#{codename}"
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

              begin
                raw = CSV.parse(
                  row['raw'],
                  col_sep: ',',
                  quote_char: '"',
                  row_sep: '\n',
                  headers: true,
                )
              rescue CSV::MalformedCSVError => e
                warn "PROKI: malformed csv in raw attribute for key #{key}: #{e.message}"
                next
              end

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
                subject: "PROKI #{codename} #{time.strftime('%Y-%m-%d')}",
                text: text,
                codename: codename,
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
end
