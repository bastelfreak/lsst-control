# @summary
#   Manages Adafruit Ultimate GPS HAT for Raspberry Pi.
#
#   See https://learn.adafruit.com/adafruit-ultimate-gps-hat-for-raspberry-pi
#
class profile::pi::gpshat {
  profile::pi::config::fragment { 'gpshat':
    # lint:ignore:strict_indent
    content => @("CONTENT"),
      dtoverlay=pps-gpio,gpiopin=4
      enable_uart=1
      init_uart_baud=9600
      | CONTENT
    # lint:endignore
  }

  kmod::load { 'pps-gpio': }

  augeas { 'gpsd options':
    context => '/files/etc/sysconfig/gpsd',
    changes => 'set OPTIONS \'"-n /dev/ttyS0 /dev/pps0"\'',
  }
}
