# @summary
#   Definition of icinga and icingaweb master module
#
# @param ldap_server
# @param ldap_root
# @param ldap_user
# @param ldap_pwd
# @param ldap_resource
# @param ldap_user_filter
# @param ldap_group_filter
# @param ldap_group_base
# @param mysql_root
# @param mysql_icingaweb_db
# @param mysql_icingaweb_user
# @param mysql_icingaweb_pwd
# @param mysql_director_db
# @param mysql_director_user
# @param mysql_director_pwd
# @param api_name
# @param api_user
# @param api_pwd
# @param ca_salt
#
class profile::icinga::master (
  String $ldap_server,
  String $ldap_root,
  String $ldap_user,
  String $ldap_pwd,
  String $ldap_resource,
  String $ldap_user_filter,
  String $ldap_group_filter,
  String $ldap_group_base,
  String $mysql_root,
  String $mysql_icingaweb_db,
  String $mysql_icingaweb_user,
  String $mysql_icingaweb_pwd,
  String $mysql_director_db,
  String $mysql_director_user,
  String $mysql_director_pwd,
  String $api_name,
  String $api_user,
  String $api_pwd,
  String $ca_salt,
) {
  include profile::core::letsencrypt
  include nginx

  # XXX EL7 specific
  service { 'rh-php73-php-fpm':
    ensure => running,
    enable => true,
  }

  # XXX icingaweb2 has dropped the `reactbundle` and `ipl` dependencies.
  # However, incubator v0.18.0 and directory v1.9.1 depenend on them as
  # libraries (not modules).  As these are dead packages, there is no reason not
  # to use the existing official RPMs. See:
  # * https://github.com/Icinga/icingaweb2-module-ipl
  # * https://github.com/Icinga/icingaweb2-module-reactbundle
  $deprecated_packages = [
    'icinga-php-library',
    'icinga-php-thirdparty',
  ]
  ensure_packages($deprecated_packages)

  #<-------------Variables Definition---------------->

  #  Implicit usage of facts
  $master_fqdn  = $facts[fqdn]
  $master_ip  = $facts[ipaddress]

  #  Letsencrypt cert path
  $le_root = "/etc/letsencrypt/live/${master_fqdn}"

  #  pnp4nagios webpage integration
  $pnp4nagios_conf = @(PNPNAGIOS/L)
    location /pnp4nagios {
            alias  /usr/share/nagios/html/pnp4nagios;
            index     index.php;
            try_files $uri $uri/ @pnp4nagios;
      }
    location @pnp4nagios {
            if ( $uri !~ /pnp4nagios/index.php(.*)) {
                    rewrite ^/pnp4nagios/(.*)$ /pnp4nagios/index.php/$1;
                    break;
            }
            root /usr/share/nagios/html/pnp4nagios;
            include /etc/nginx/fastcgi.conf;
            fastcgi_split_path_info ^(.+\.php)(.*)$;
            fastcgi_param PATH_INFO $fastcgi_path_info;
            fastcgi_param SCRIPT_FILENAME $document_root/index.php;
            fastcgi_pass 127.0.0.1:9000;
    }
    | PNPNAGIOS

  #  PNP plugin configuration
  # XXX should icinga-master.ls.lsst.org be hardcoded into the pnp config?
  $pnp_conf = @(PNP/)
    [pnp4nagios]
    config_dir = "/etc/pnp4nagios"
    base_url = "/pnp4nagios"
    menu_disabled = "0"
    default_query = "host=icinga-master.ls.lsst.org&srv=MasterPingService"
    | PNP

  #Icinga tls keys
  $ssl_cert  = '/etc/ssl/certs/icinga.crt'
  $ssl_key   = '/etc/ssl/certs/icinga.key'

  #Package installation
  $packages = [
    'git',
    'pnp4nagios',
    'nagios-plugins-all',
    'php-intl',
  ]

  #MySql options
  $override_options = {
    'mysqld' => {
      'bind_address' => '0.0.0.0',
    },
  }
  #Npcd file content
  $npcd_cont = @(NPCD/L)
    #Needs to end in newline
    user = icinga
    group = icinga
    log_level = 0
    log_type = file
    log_file = /var/log/npcd.log
    max_logfile_size = 10485760
    perfdata_spool_dir = /var/spool/icinga2/perfdata
    perfdata_file_run_cmd = /usr/libexec/pnp4nagios/process_perfdata.pl
    perfdata_file_run_cmd_args = --bulk
    identify_npcd = 1
    npcd_max_threads = 15
    sleep_time = 15
    load_threshold = 0.0
    pid_file=/var/run/npcd.pid
    perfdata_file = /var/log/pnp4nagios/perfdata.dump
    perfdata_spool_filename = perfdata
    perfdata_file_processing_interval = 15

    #MUST LEAVE newline
    | NPCD
  #<----------End Variables Definition--------------->
  #
  #
  #<-------Clasess Definition & Configuration-------->
  ##Letsencrypt cert signoff
  letsencrypt::certonly { $master_fqdn:
    plugin      => 'dns-route53',
    manage_cron => true,
  }
  ##Ensure packages
  package { $packages:
    ensure => 'present',
  }
  ##MySQL definition
  class { 'mysql::server':
    root_password           => $mysql_root,
    remove_default_accounts => true,
    restart                 => true,
    override_options        => $override_options,
  }
  ->mysql::db { $mysql_icingaweb_db:
    user     => $mysql_icingaweb_user,
    password => $mysql_icingaweb_pwd,
    host     => $master_ip,
    grant    => ['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE VIEW', 'CREATE', 'INDEX', 'EXECUTE', 'ALTER', 'REFERENCES'],
    require  => Class['mysql::server'],
  }
  ->mysql::db { $mysql_director_db:
    user     => $mysql_director_user,
    password => $mysql_director_pwd,
    host     => $master_ip,
    charset  => 'utf8',
    grant    => ['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE VIEW', 'CREATE', 'INDEX', 'EXECUTE', 'ALTER', 'REFERENCES'],
    require  => Class['mysql::server'],
  }
  ##Icinga2 Config
  class { 'icinga::repos':
    manage_epel         => false,
  }
  class { 'icinga2':
    confd     => false,
    constants => {
      'ZoneName'   => 'master',
      'TicketSalt' => $ca_salt,
    },
    features  => ['checker','mainlog','statusdata','compatlog','command'],
  }
  class { 'icinga2::feature::idomysql':
    user          => $mysql_icingaweb_user,
    password      => $mysql_icingaweb_pwd,
    database      => $mysql_icingaweb_db,
    host          => $master_ip,
    import_schema => true,
    require       => Mysql::Db[$mysql_icingaweb_db],
  }
  class { 'icinga2::feature::api':
    pki             => 'none',
    accept_config   => true,
    accept_commands => true,
    ca_host         => $master_ip,
    ensure          => 'present',
    endpoints       => {
      $master_fqdn    => {
        'host'  => $master_ip,
      },
    },
    zones           => {
      'master'    => {
        'endpoints' => [$master_fqdn],
      },
    },
  }
  include icinga2::pki::ca

  class { 'icinga2::feature::notification':
    ensure    => present,
    enable_ha => true,
  }
  icinga2::object::apiuser { $api_user:
    ensure      => present,
    password    => $api_pwd,
    permissions => ['*'],
    target      => '/etc/icinga2/features-enabled/api-users.conf',
  }
  icinga2::object::zone { 'director-global':
    global => true,
  }
  ##Icinga2 Perfdata
  class { 'icinga2::feature::perfdata':
    ensure => present,
  }
  file { '/var/lib/pnp4nagios':
    ensure  => 'directory',
    owner   => 'icinga',
    group   => 'icinga',
    mode    => '0755',
    require => Package[$packages],
    notify  => Service['npcd'],
  }
  ##IcingaWeb Config
  class { 'icingaweb2':
    manage_repo   => false,
    logging_level => 'INFO',
    require       => Class['icinga2'],
  }
  class { 'icingaweb2::module::monitoring':
    ensure            => present,
    ido_host          => $master_ip,
    ido_type          => 'mysql',
    ido_db_name       => $mysql_icingaweb_db,
    ido_db_username   => $mysql_icingaweb_user,
    ido_db_password   => $mysql_icingaweb_pwd,
    commandtransports => {
      $api_name => {
        transport => 'api',
        host      => $master_ip,
        port      => 5665,
        username  => $api_user,
        password  => $api_pwd,
      },
    },
  }
  ##IcingaWeb LDAP Config
  icingaweb2::config::resource { $ldap_resource:
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
  icingaweb2::config::role { 'Visitors':
    groups      => 'icinga-sqre,icinga-tssw,icinga-comcam',
    permissions => 'application/share/navigation,application/stacktraces,application/log,module/director,module/doc,module/incubator,module/monitoring,monitoring/*,module/pnp,module/setup,module/translation',
  }

  ##IcingaWeb Director
  class { 'icingaweb2::module::director':
    git_revision  => 'v1.9.1',
    db_host       => $master_ip,
    db_name       => $mysql_director_db,
    db_username   => $mysql_director_user,
    db_password   => $mysql_director_pwd,
    import_schema => true,
    kickstart     => true,
    endpoint      => $master_fqdn,
    api_host      => $master_ip,
    api_port      => 5665,
    api_username  => $api_user,
    api_password  => $api_pwd,
    require       => Mysql::Db[$mysql_director_db],
  }

  ##IcingaWeb PNP
  # XXX pnp4nagios is effectively dead and hasn't had a release since 2017. We
  # need to migrate away.
  icingaweb2::module { 'pnp':
    git_repository => 'https://github.com/Icinga/icingaweb2-module-pnp',
    git_revision   => '8f09274', # the v1.1.0 tag claims to be v1.0.1
  }
  -> file { '/etc/icingaweb2/modules/pnp/config.ini':
    ensure  => 'file',
    mode    => '0660',
    owner   => 'apache',
    group   => 'icingaweb2',
    content => $pnp_conf,
  }
  file { '/etc/pnp4nagios/npcd.cfg':
    ensure  => 'file',
    mode    => '0644',
    content => $npcd_cont,
    require => Package[$packages],
    notify  => Service['npcd'],
  }
  ##PNP4Nagios Configuration
  file { '/etc/nginx/sites-available/pnp4nagios.conf':
    ensure  => 'file',
    content => $pnp4nagios_conf,
    mode    => '0644',
  }

  ##IcingaWeb Incubator
  class { 'icingaweb2::module::incubator':
    git_revision => 'v0.18.0',
  }

  ##Nginx Resource Definition
  nginx::resource::server { 'icingaweb2':
    server_name          => [$master_fqdn],
    ssl                  => true,
    ssl_cert             => "${le_root}/fullchain.pem",
    ssl_key              => "${le_root}/privkey.pem",
    ssl_redirect         => true,
    index_files          => ['index.php'],
    use_default_location => false,
    www_root             => '/usr/share/icingaweb2/public',
    include_files        => ['/etc/nginx/sites-available/pnp4nagios.conf'],
  }
  nginx::resource::location { 'root':
    location    => '/',
    server      => 'icingaweb2',
    try_files   => ['$1', '$uri', '$uri/', '/index.php$is_args$args'],
    index_files => [],
    ssl         => true,
    ssl_only    => true,
  }
  nginx::resource::location { 'icingaweb':
    location       => '~ ^/icingaweb2(.+)?',
    location_alias => '/usr/share/icingaweb2/public',
    try_files      => ['$1', '$uri', '$uri/', '/icingaweb2/index.php$is_args$args'],
    index_files    => ['index.php'],
    server         => 'icingaweb2',
    ssl            => true,
    ssl_only       => true,
  }
  nginx::resource::location { 'icingaweb2_index':
    location      => '~ ^/index\.php(.*)$',
    server        => 'icingaweb2',
    ssl           => true,
    ssl_only      => true,
    index_files   => [],
    try_files     => ['$uri =404'],
    fastcgi       => '127.0.0.1:9000',
    fastcgi_index => 'index.php',
    fastcgi_param => {
      'ICINGAWEB_CONFIGDIR' => '/etc/icingaweb2',
      'REMOTE_USER'         => '$remote_user',
      'SCRIPT_FILENAME'     => '/usr/share/icingaweb2/public/index.php',
    },
  }
  ##Reload service in case any modification has occured
  service { 'npcd':
    ensure  => running,
    require => Package[$packages],
  }
  #<-----------END Clases definition----------------->
}
