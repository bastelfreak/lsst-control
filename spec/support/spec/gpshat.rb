# frozen_string_literal: true

shared_examples 'gpshat' do
  it do
    is_expected.to contain_profile__pi__config__fragment('gpshat').with(
      content: <<~CONTENT,
      dtoverlay=pps-gpio,gpiopin=4
      enable_uart=1
      init_uart_baud=9600
      CONTENT
    )
  end

  it { is_expected.to contain_kmod__load('pps-gpio') }
end
