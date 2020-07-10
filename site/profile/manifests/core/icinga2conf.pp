# @summary
#   Ensure icinga2.conf file

class profile::core::icinga2conf (
  $icinga_user,
  $icinga_pwd,
  $icinga_db ,
  $icinga_hostname,
  $ldap_server,
  $ldap_root,
  $ldap_user,
  $ldap_pwd,
  $ldap_resource,
  $ldap_user_filter,
  $ldap_group_filter,
  $ldap_group_base,
  $ssl_name,
  $ssl_country,
  $ssl_org,
  $ssl_fqdn,
)
{
  include '::apache'
  include '::apache::mod::proxy'
  include '::apache::mod::proxy_fcgi'
  include '::apache::mod::ssl'
  include '::mysql::server'
  include '::icinga2'
  include '::icinga2::pki::ca'
  include '::icingaweb2'
  include '::openssl'

  ::apache::namevirtualhost { '*:443': }
  ::apache::listen { '443': }

  openssl::certificate::x509 { $ssl_name:
    country      => $ssl_country,
    organization => $ssl_org,
    commonname   => $ssl_fqdn,
  }

  mysql::db { $icinga_db:
    user     => $icinga_user,
    password => $icinga_pwd,
    host     => 'localhost',
    grant    => [ 'ALL' ],
  }

  class { '::icinga2::feature::idomysql':
        user          => $icinga_user,
        password      => $icinga_pwd,
        database      => $icinga_db,
        import_schema => true,
  }

  class { '::icinga2::feature::api':
    pki             => 'none',
    accept_commands => true,
    endpoints       => {
      $icinga_hostname => {},
    },
    zones           => {
      'master' => {
        'endpoints' => [$icinga_hostname],
      },
    }
  }

  icinga2::object::zone { 'global-templates':
    global => true,
  }

  icingaweb2::config::resource{ $ldap_resource:
    type         => 'ldap',
    host         => $ldap_server,
    port         => 389,
    ldap_root_dn => $ldap_root,
    ldap_bind_dn => $ldap_user,
    ldap_bind_pw => $ldap_pwd,
  }

  icingaweb2::config::authmethod { 'ldap-auth':
    backend                  => 'ldap',
    resource                 => $ldap_resource,
    ldap_user_class          => 'inetOrgPerson',
    ldap_filter              => $ldap_user_filter,
    ldap_user_name_attribute => 'uid',
    order                    => '05',
  }

  icingaweb2::config::groupbackend { 'ldap-groups':
    backend                   => 'ldap',
    resource                  => $ldap_resource,
    ldap_group_class          => 'groupOfNames',
    ldap_group_name_attribute => 'cn',
    ldap_group_filter         => $ldap_group_filter,
    ldap_base_dn              => $ldap_group_base,
  }

  icingaweb2::config::role { 'Admin User':
    groups      => 'icinga-admins',
    permissions => '*',
  }

  class {'icingaweb2::module::monitoring':
    ido_host          => 'localhost',
    ido_db_name       => $icinga_db,
    ido_db_username   => $icinga_user,
    ido_db_password   => $icinga_pwd,
    commandtransports => {
      icinga2 => {
        transport => 'api',
        username  => 'icingaweb2',
        password  => 'supersecret',
      }
    }
  }
    file { '/etc/httpd/conf.d/icingaweb2.conf':
      ensure => file,
      source => 'puppet:///modules/icingaweb2/examples/apache2/for-mod_proxy_fcgi.conf',
      notify => Service['httpd'],
    }
}
