# @summary
#   Settings for hosts that should run in graphical mode.
#
# @param install
#   Boolean, false means do nothing.
# @param officeapps
#   Boolean, true means install libreoffice etc.
#
class profile::ccs::graphical (
  Boolean $install = true,
  Boolean $officeapps = false,
) {
  if $install {
    ensure_packages(['gdm'])

    service { 'gdm':
      enable => true,
    }

    exec { 'Set graphical target':
      path    => ['/usr/sbin', '/usr/bin'],
      command => 'systemctl set-default graphical.target',
      unless  => 'sh -c "systemctl get-default | grep -qF graphical.target"',
    }

    ## Slow. Maybe better done separately?
    ## Don't want this on servers.
    ## Although people sometimes want to eg use vnc,
    ## so it does end up being needed on servers too.
    ## "Server with GUI" instead? Not much smaller.
    # Packages not present on EL8 or EL9
    if fact('os.release.major') == '7' {
      yum::group { 'GNOME Desktop':
        ensure  => present,
        timeout => 1800,
      }
      yum::group { 'MATE Desktop':
        ensure  => present,
        timeout => 900,
      }
    }
    else {
      yum::group { 'Server with GUI':
        ensure  => present,
        timeout => 900,
      }
      ensure_packages(['mate-desktop'])
    }

    package { 'gnome-initial-setup':
      ensure => purged,
    }

    ensure_packages(['x2goclient', 'x2goserver', 'x2godesktopsharing'])

    ensure_packages(['icewm'])
  }

  if $officeapps {
    ensure_packages(['libreoffice-base'])

    $zoomrpm = 'zoom.x86_64.rpm'
    $zoomfile = "/var/tmp/${zoomrpm}"

    archive { $zoomfile:
      ensure   => present,
      source   => "${profile::ccs::common::pkgurl}/${zoomrpm}",
      username => $profile::ccs::common::pkgurl_user,
      password => $profile::ccs::common::pkgurl_pass,
    }

    ## TODO use a local yum repository?
    package { 'zoom':
      ensure   => 'installed',
      provider => 'rpm',
      source   => $zoomfile,
    }
  }
}
