# @summary
#   Common functionality needed by rke on kubernetes nodes.
#
# @param enable_dhcp
#   Enable CNI dhcp plugin
#
# @param keytab_base64
#   base64 encoded krb5 keytab for the iip user
#
class profile::core::rke(
  Boolean          $enable_dhcp   = false,
  Optional[String] $keytab_base64 = undef,
) {
  $user = 'rke'
  $uid  = 75500

  if $enable_dhcp {
    include cni::plugins
    include cni::plugins::dhcp
  }

  if $keytab_base64 {
    profile::util::keytab { $user:
      uid           => $uid,
      keytab_base64 => $keytab_base64,
    }
  }

  vcsrepo { "/home/${user}/k8s-cookbook":
    ensure             => present,
    provider           => git,
    source             => 'https://github.com/lsst-it/k8s-cookbook.git',
    keep_local_changes => true,
    user               => $user,
    owner              => $user,
    group              => $user,
  }
}