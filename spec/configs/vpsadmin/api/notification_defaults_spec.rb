# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../configs/vpsadmin/api/notification_defaults'

module NotificationDefaultsSpec
  class EventRoute
    attr_reader :notification_receiver
  end

  class NotificationReceiver
    def self.ensure_defaults_for!(*); end
  end

  class ActiveRoutes
    def find_by(*); end
  end

  class UserRoutes
    def create!(*); end
  end

  class User
    attr_reader :event_routes

    def with_lock; end
  end
end

RSpec.describe Object, '#ensure_vpsfree_oom_event_route!' do
  let(:active_routes) { instance_double(NotificationDefaultsSpec::ActiveRoutes) }
  let(:user_routes) { instance_double(NotificationDefaultsSpec::UserRoutes) }
  let(:user) { instance_double(NotificationDefaultsSpec::User, event_routes: user_routes) }

  before do
    stub_const('EventRoute', NotificationDefaultsSpec::EventRoute)
    stub_const('NotificationReceiver', NotificationDefaultsSpec::NotificationReceiver)

    allow(user).to receive(:with_lock).and_yield
    allow(EventRoute).to receive_messages(
      active: active_routes,
      subject_scopes: { 'self' => 0 }
    )
  end

  it 'keeps an existing grouped OOM route unchanged' do
    route = instance_double(EventRoute)
    allow(active_routes).to receive(:find_by).and_return(route)
    allow(NotificationReceiver).to receive(:ensure_defaults_for!)
    allow(user_routes).to receive(:create!)

    expect(ensure_vpsfree_oom_event_route!(user)).to eq(route)
    expect(NotificationReceiver).not_to have_received(:ensure_defaults_for!)
    expect(user_routes).not_to have_received(:create!)
  end

  it 'creates the grouped OOM route from the default administrator receiver' do
    receiver = instance_double(NotificationReceiver)
    default_route = instance_double(EventRoute, notification_receiver: receiver)
    route = instance_double(EventRoute)

    allow(active_routes).to receive(:find_by).and_return(nil)
    allow(NotificationReceiver).to receive(:ensure_defaults_for!).with(user)
    allow(EventRoute).to receive(:default_admin_route_for).with(user).and_return(default_route)
    allow(EventRoute).to receive(:prepend_position_for).with(user).and_return(-1)
    allow(user_routes).to receive(:create!).and_return(route)

    expect(ensure_vpsfree_oom_event_route!(user)).to eq(route)
    expect(user_routes).to have_received(:create!).with(
      notification_receiver: receiver,
      label: 'OOM report notifications',
      position: -1,
      event_type: 'vps.oom_report',
      grouping_enabled: true,
      group_by: ['vps_id'],
      group_wait_seconds: 60,
      group_interval_seconds: 10_800
    )
  end
end
