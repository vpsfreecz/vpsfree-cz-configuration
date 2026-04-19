# frozen_string_literal: true

require 'require_all'

require_relative '../../../../configs/vpsadmin/api/incident_reports'

RSpec.describe VpsAdmin::API::IncidentReports do
  it 'routes a recognized Request Tracker message to its parser' do
    register_assignment('10.42.9.42')

    result = described_class.handle_message(
      mailbox,
      fixture_message('fail2ban'),
      dry_run: true
    )

    expect(result).to be_processed
    expect(result.reply).to eq(
      from: 'vpsadmin@vpsfree.cz',
      to: ['abuse-komentare@vpsfree.cz']
    )
    expect(result.incidents.size).to eq(1)
    expect(result.incidents.first.subject).to eq('Automatic abuse report for IP address 10.42.9.42')
  end

  it 'does not route recognized subjects from unexpected senders by default' do
    message = fixture_message('fail2ban')
    message['X-RT-Originator'] = 'attacker@example.test'

    result = described_class.handle_message(mailbox, message, dry_run: true)

    expect(result).not_to be_processed
    expect(result.incidents).to be_empty
  end
end
