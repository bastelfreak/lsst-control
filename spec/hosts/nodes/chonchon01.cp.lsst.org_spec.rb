# frozen_string_literal: true

require 'spec_helper'

describe 'chonchon01.cp.lsst.org', :sitepp do
  on_supported_os.each do |os, os_facts|
    next unless os =~ %r{almalinux-9-x86_64}

    context "on #{os}" do
      let(:facts) do
        override_facts(os_facts,
                       fqdn: 'chonchon01.cp.lsst.org',
                       is_virtual: false,
                       virtual: 'physical',
                       dmi: {
                         'product' => {
                           'name' => 'PowerEdge R730xd',
                         },
                       })
      end
      let(:node_params) do
        {
          role: 'rke',
          site: 'cp',
          cluster: 'chonchon',
        }
      end

      it { is_expected.to compile.with_all_deps }

      include_examples 'baremetal'
      include_context 'with nm interface'

      it do
        is_expected.to contain_class('profile::core::sysctl::rp_filter').with_enable(false)
      end

      it do
        is_expected.to contain_class('clustershell').with(
          groupmembers: {
            'chonchon' => {
              'group' => 'chonchon',
              'member' => 'chonchon[01-03]',
            },
          },
        )
      end

      it do
        is_expected.to contain_class('profile::core::rke').with(
          enable_dhcp: true,
          version: '1.3.12',
        )
      end

      it do
        is_expected.to contain_class('cni::plugins').with(
          version: '1.2.0',
          checksum: 'f3a841324845ca6bf0d4091b4fc7f97e18a623172158b72fc3fdcdb9d42d2d37',
          enable: ['macvlan'],
        )
      end

      it { is_expected.to have_nm__connection_resource_count(6) }

      %w[
        em2
        em3
        em4
      ].each do |i|
        context "with #{i}" do
          let(:interface) { i }

          it_behaves_like 'nm disabled interface'
        end
      end

      context 'with em1' do
        let(:interface) { 'em1' }

        it_behaves_like 'nm enabled interface'
        it_behaves_like 'nm dhcp interface'
        it_behaves_like 'nm ethernet interface'
      end

      context 'with em2.1800' do
        let(:interface) { 'em2.1800' }

        it_behaves_like 'nm enabled interface'
        it_behaves_like 'nm vlan interface', id: 1800, parent: 'em2'
        it_behaves_like 'nm bridge slave interface', master: 'br1800'
      end

      context 'with br1800' do
        let(:interface) { 'br1800' }

        it_behaves_like 'nm enabled interface'
        it_behaves_like 'nm no-ip interface'
        it_behaves_like 'nm bridge interface'
        it { expect(nm_keyfile['ipv4']['route1']).to eq('139.229.180.0/24') }
        it { expect(nm_keyfile['ipv4']['route1_options']).to eq('table=1800') }
        it { expect(nm_keyfile['ipv4']['route2']).to eq('0.0.0.0/0,139.229.180.254') }
        it { expect(nm_keyfile['ipv4']['route2_options']).to eq('table=1800') }
        it { expect(nm_keyfile['ipv4']['routing-rule1']).to eq('priority 100 from 139.229.180.0/26 table 1800') }
      end
    end # on os
  end # on_supported_os
end
