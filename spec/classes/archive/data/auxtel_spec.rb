# frozen_string_literal: true

require 'spec_helper'

describe 'profile::archive::data::auxtel' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_file('/data/repo/LATISS').with_mode('0777') }
      it { is_expected.to contain_file('/data/repo/LATISS/u').with_mode('1777') }
      it { is_expected.not_to contain_file('/data/repo/LSSTComCam') }
    end
  end
end
