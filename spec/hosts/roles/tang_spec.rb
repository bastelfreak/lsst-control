# frozen_string_literal: true

require 'spec_helper'

role = 'tang'

describe "#{role} role" do
  on_supported_os.each do |os, os_facts|
    next unless os =~ %r{almalinux-9-x86_64}

    context "on #{os}" do
      let(:facts) { os_facts }
      let(:node_params) do
        {
          role: role,
          site: site,
        }
      end

      lsst_sites.each do |site|
        fqdn = "#{role}.#{site}.lsst.org"
        override_facts(os_facts, fqdn: fqdn, networking: { fqdn => fqdn })

        describe fqdn, :sitepp do
          let(:site) { site }

          it { is_expected.to compile.with_all_deps }

          include_examples 'common', os_facts: os_facts
          include_examples 'ipset'
          include_examples 'firewall default', os_facts: os_facts
          include_examples 'firewall node_exporter scraping', site: site
          include_examples 'restic common'

          it { is_expected.to contain_class('tang') }
          it { is_expected.to contain_package('jose') }

          case site
          when 'dev'
            it do
              is_expected.to contain_firewall('200 accept tang').with(
                proto: 'tcp',
                state: 'NEW',
                ipset: 'dev src',
                dport: '7500',
                action: 'accept',
              )
            end
          when 'tu'
            it do
              is_expected.to contain_firewall('200 accept tang').with(
                proto: 'tcp',
                state: 'NEW',
                ipset: 'tufde src',
                dport: '7500',
                action: 'accept',
              )
            end
          end

          it do
            is_expected.to contain_restic__repository('awsrepo').with(
              backup_path: %w[
                /var/db/tang
              ],
              backup_timer: '*-*-* *:47:00',
              enable_forget: true,
              forget_timer: '*-*-* 15:00:00',
              forget_flags: '--keep-within 1y',
            )
          end
        end # host
      end # lsst_sites
    end # on os
  end # on_supported_os
end # role
