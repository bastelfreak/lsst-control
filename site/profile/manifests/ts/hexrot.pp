# @summary
# Sets up repos and symlinks for hexrot

class profile::ts::hexrot {
  vcsrepo { '/opt/ts_config_mttcs':
    ensure             => present,
    provider           => git,
    source             => 'https://github.com/lsst-ts/ts_config_mttcs.git',
    keep_local_changes => true,
    require            => Class[profile::core::anaconda],
  }
  file { '/etc/profile.d/hexrot_path.sh':
    ensure  => file,
    mode    => '0644',
    require => Vcsrepo['/opt/ts_config_mttcs'],
    # lint:ignore:strict_indent
    content => @(ENV),
        #!/usr/bin/bash
        export QT_API="PySide2"
        export PYTEST_QT_API="PySide2"
        export TS_CONFIG_MTTCS_DIR="/opt/ts_config_mttcs"
        | ENV
    # lint:endignore
  }
  file { '/rubin/mtm2/python':
    ensure  => 'directory',
    owner   => 73006,
    group   => 73006,
    require => Class[profile::core::anaconda],
  }
  file { '/rubin/mtm2/python/run_m2gui':
    ensure => link,
    owner  => 73006,
    group  => 73006,
    target => '/opt/anaconda/envs/py311/bin/run_m2gui',
  }
}
