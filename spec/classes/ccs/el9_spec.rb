# frozen_string_literal: true

require 'spec_helper'

describe 'profile::ccs::el9' do
  on_supported_os.each do |os, facts|
    next unless os =~ %r{almalinux-9-x86_64}

    context "on #{os}" do
      let(:facts) { facts }

      it { is_expected.to compile.with_all_deps }
    end # on os
  end  # on_supported_os
end
