# @summary
#   Installs anaconda
#
# @param python_env_name
#   if exist, sets the name of the virtual environment
#
# @param python_env_version
#   if exist, sets the version of python for the virtual environment
#
# @param conda_packages
#   if contains at least 1 tuple (name and channel), will install the package
#    
class profile::core::anaconda (
  String $python_env_name,
  String $python_env_version,
  Tuple   $conda_packages,
) {
  case $facts['os']['family'] {
    'RedHat': {
      ensure_packages('wget')
      exec { 'install_anaconda':
        command => '/bin/wget https://repo.anaconda.com/archive/Anaconda3-2023.07-2-Linux-x86_64.sh -O /tmp/anaconda_installer.sh && /bin/bash /tmp/anaconda_installer.sh -b -p /opt/anaconda',
        creates => '/opt/anaconda/bin/conda',
        path    => '/usr/bin:/bin:/opt/anaconda/bin',
        require => Package['wget'],
      }
    }
    default: {
      notify { 'unsupported_os':
        message => 'This Anaconda installation is only for RedHat family',
      }
    }
  }
  # Create a Conda environment with Python if parameters are set
  if ($python_env_name and $python_env_version) {
    exec { 'create_conda_env':
      command => "/opt/anaconda/bin/conda create -y --name ${python_env_name} python=${python_env_version}",
      creates => "/opt/anaconda/envs/${python_env_name}/",
      require => Exec['install_anaconda'],
    }
    file { '/etc/profile.d/conda_source.sh':
      ensure  => file,
      mode    => '0644',
      require => Exec['create_conda_env'],
      # lint:ignore:strict_indent
      content => @("SOURCE"),
          #!/usr/bin/bash
          source /opt/anaconda/bin/activate ${python_env_name}
          | SOURCE
      # lint:endignore
    }
    # Install libmamba inside the environment with conda
    exec { 'install_libmamba_env':
      command => "/opt/anaconda/bin/conda install -y -n ${python_env_name} conda-libmamba-solver",
      creates => "/opt/anaconda/envs/${python_env_name}/lib/libmamba.so",
      require => Exec['create_conda_env'],
      path    => ['/usr/bin', '/bin', '/opt/anaconda/bin'],
    }
    # Sets libmamba as dependencies solver
    exec { 'set_libmamba':
      command => 'conda config --set solver libmamba',
      require => Exec['install_libmamba_env'],
      unless  => 'conda config --get solver | grep libmamba',
      path    => ['/usr/bin', '/bin', '/opt/anaconda/bin'],
    }
  }
  #cycle and install conda stuff
  if !empty($conda_packages) {
    $conda_packages.each |$package_info| {
      exec { "install_${package_info['name']}_via_conda":
        command => "conda install -y -n ${python_env_name} -c ${package_info['channel']} ${package_info['name']}",
        path    => ['/usr/bin', '/bin', '/opt/anaconda/bin'],
        require => Exec['set_libmamba'],
        unless  => "conda list -n ${python_env_name} | grep ${package_info['name']}",
      }
    }
  }
}
