# frozen_string_literal: true

require 'spec_helper'

describe 'dns2.dev.lsst.org', :sitepp do
  on_supported_os.each do |os, facts|
    next if os =~ %r{centos-7-x86_64}

    context "on #{os}" do
      let(:facts) do
        override_facts(facts,
                       fqdn: 'dns2.dev.lsst.org',
                       is_virtual: true,
                       virtual: 'kvm',
                       dmi: {
                         'product' => {
                           'name' => 'KVM',
                         },
                       })
      end
      let(:node_params) do
        {
          role: 'dnscache',
          site: 'dev',
        }
      end

      it { is_expected.to compile.with_all_deps }

      include_examples 'vm'
      include_context 'with nm interface'
      it { is_expected.to have_network__interface_resource_count(0) }
      it { is_expected.to have_nm__connection_resource_count(1) }

      context 'with ens3' do
        let(:interface) { 'ens3' }

        it_behaves_like 'nm enabled interface'
        it_behaves_like 'nm ethernet interface'
        it { expect(nm_keyfile['ipv4']['address1']).to eq('139.229.134.54/24,139.229.134.254') }
        it { expect(nm_keyfile['ipv4']['dns']).to eq('139.229.134.53;139.229.135.54;139.229.135.55;') }
        it { expect(nm_keyfile['ipv4']['dns-search']).to eq('dev.lsst.org;') }
        it { expect(nm_keyfile['ipv4']['method']).to eq('manual') }
      end
    end # on os
  end # on_supported_os
end
