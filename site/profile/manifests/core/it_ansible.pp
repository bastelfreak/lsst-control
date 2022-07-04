# @summary
#   Common functionality needed by standard nodes.
#

class profile::core::it_ansible (
) {
  $ansible_path = '/opt/ansible'
  $ansible_repo = "${ansible_path}/ansible_network"
  $ansible_plugins = [
    'cisco,nxos',
    'arista,eos',
    'cisco,ios',
    'community,network',
  ]
  $known_hosts = @("KNOWN")
    sudo -u ansible_net ssh-keyscan -t rsa github.com > ${ansible_path}/.ssh/known_hosts
    chown ansible_net:ansible_net ${ansible_path}/.ssh/known_hosts
    chmod 644 ${ansible_path}/.ssh/known_hosts
    |KNOWN

  $pip_packages = [
    'ansible',
  ]

  file { $ansible_path:
    ensure => directory,
    owner  => 'ansible_net',
    group  => 'ansible_net',
  }
  file { "${ansible_path}/.ssh":
    ensure => directory,
    owner  => 'ansible_net',
    group  => 'ansible_net',
    mode   => '0700',
  }
  -> file { "${ansible_path}/.ssh/config":
    ensure => file,
    owner  => 'ansible_net',
    group  => 'ansible_net',
    mode   => '0644',
  }
  exec { $known_hosts:
    cwd     => '/var/tmp/',
    path    => ['/sbin', '/usr/sbin', '/bin'],
    onlyif  => ["test ! -f ${ansible_path}/.ssh/known_hosts"],
    require => File["${ansible_path}/.ssh/config"],
  }
  -> vcsrepo { $ansible_repo:
    ensure   => present,
    provider => git,
    source   => 'git@github.com:lsst-it/ansible_network.git',
    identity => "${ansible_path}/.ssh/id_rsa",
    user     => 'ansible_net',
    group    => 'ansible_net',
    owner    => 'ansible_net',
    require  => File["${ansible_path}/.ssh/id_rsa"],
  }
  -> file { '/etc/ansible/ansible.cfg':
    ensure => file,
    mode   => '0644',
    source => "file:///${ansible_repo}/playbooks/ansible.cfg",
  }
  $ansible_plugins.each |$plugins| {
    $value = split($plugins,',')
    exec { "sudo -u ansible_net ansible-galaxy collection install ${value[0]}.${value[1]}":
      cwd    => '/var/tmp/',
      path   => ['/sbin', '/usr/sbin', '/bin'],
      onlyif => ["test ! -d ${ansible_path}/.ansible/collections/ansible_collections/${value[0]}/${value[1]}"],
    }
  }
  package { $pip_packages:
    ensure   => 'present',
    provider => 'pip3',
  }
}
