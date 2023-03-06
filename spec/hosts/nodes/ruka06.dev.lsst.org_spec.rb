# frozen_string_literal: true

require 'spec_helper'

#
# Testing network interfaces from the site/dev/role/hypervisor/major/** layers.
#
describe 'ruka06.dev.lsst.org', :site do
  alma9 = FacterDB.get_facts({ operatingsystem: 'AlmaLinux', operatingsystemmajrelease: '9' }).first
  # rubocop:disable Naming/VariableNumber
  { 'almalinux-9-x86_64': alma9 }.each do |os, facts|
    # rubocop:enable Naming/VariableNumber
    context "on #{os}" do
      let(:facts) { override_facts(facts, fqdn: 'ruka06.dev.lsst.org') }
      let(:node_params) do
        {
          role: 'hypervisor',
          site: 'dev',
        }
      end

      include_context 'with nm interface'

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to have_profile__nm__connection_resource_count(7) }

      %w[
        eno1
        eno2
        eno3
        eno4
        enp10s0f1
      ].each do |i|
        context "with #{name}" do
          let(:interface) { i }

          it_behaves_like 'nm disabled interface'
        end
      end

      context 'with enp10s0f0' do
        let(:interface) { 'enp10s0f0' }

        it_behaves_like 'nm named interface'
        it { expect(nm_keyfile['connection']['type']).to eq('ethernet') }
        it { expect(nm_keyfile['connection']['autoconnect']).to be_nil }
        it { expect(nm_keyfile['connection']['master']).to eq('br2101') }
        it { expect(nm_keyfile['connection']['slave-type']).to eq('bridge') }
      end

      context 'with br2101' do
        let(:interface) { 'br2101' }

        it_behaves_like 'nm named interface'
        it { expect(nm_keyfile['connection']['type']).to eq('bridge') }
        it { expect(nm_keyfile['connection']['autoconnect']).to be_nil }
        it { expect(nm_keyfile['bridge']['stp']).to be false }
        it { expect(nm_keyfile['ipv4']['method']).to eq('auto') }
        it { expect(nm_keyfile['ipv6']['method']).to eq('disabled') }
      end
    end # on os
  end # on_supported_os
end