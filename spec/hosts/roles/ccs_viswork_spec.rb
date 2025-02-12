# frozen_string_literal: true

require 'spec_helper'

role = 'ccs-viswork'

describe "#{role} role" do
  on_supported_os.each do |os, os_facts|
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
          include_examples 'ccs common', os_facts: os_facts
          include_examples 'x2go packages', os_facts: os_facts
        end # host
      end # lsst_sites
    end # on os
  end # on_supported_os
end # role
