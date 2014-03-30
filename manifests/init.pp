# Class: bamboo
#
# This module manages Atlassian Bamboo
#
# Parameters:
#
# Actions:
#
# Requires:
#
#	Define['wget']
#
# Sample Usage:
#
# [Remember: No empty lines between comments and class definition]
class bamboo (
  $version = '4.4.0',
  $extension = 'tar.gz',
  $installdir = '/usr/local',
  $home = '/var/local/bamboo',
  $user = 'bamboo',
  $manage_user_home = false,
  $java_home = '/usr/lib/jvm/java-7-openjdk-amd64',
  $server_port = '8007',
  $http_port = '8085',
  $https_port = '8443',  
  $root_context = '',
  $prepare_for_http_proxy = false,
  $proxy_scheme = 'http',
  $proxy_name = undef,
  $proxy_port = undef,
) {

  $srcdir = '/usr/local/src'
  $dir = "${installdir}/bamboo-${version}"

  # Atlassian changed the 'webapp' directory name to 'atlassian-bamboo' from version 5.1.0.
  $versionGE510 = $version ? {
    /^(5\.[1-9]|[6-9]\.).*/ => true,
    default                 => false,
  }

  $webappDirName = $versionGE510 ? {
      true  => 'atlassian-bamboo',
      false => 'webapp'
  }

  File {
    owner  => $user,
    group  => $user,
  }

  if !defined(User[$user]) {
    user { $user:
      ensure     => present,
      home       => $home,
      managehome => $managehome,
      system     => true,
    }
  }

  wget::fetch { 'bamboo':
    source      => "http://www.atlassian.com/software/bamboo/downloads/binary/atlassian-bamboo-${version}.${extension}",
    destination => "${srcdir}/atlassian-bamboo-${version}.tar.gz",
  } ->
  file {$installdir: ensure => directory,} ->
  exec { 'bamboo':
    command => "tar zxvf ${srcdir}/atlassian-bamboo-${version}.tar.gz && mv atlassian-bamboo-${version} bamboo-${version} && chown -R ${user} bamboo-${version}",
    creates => "${installdir}/bamboo-${version}",
    cwd     => $installdir,
    logoutput => "on_failure",
  } ->
  file { $home:
    ensure => directory,
  } ->
  file { "${home}/logs":
    ensure => directory,
  } ->
  file { "${dir}/${webappDirName}/WEB-INF/classes/bamboo-init.properties":
    content => "bamboo.home=${home}/data",
  } ->
  file {"${dir}/conf/server.xml":
    content => template('bamboo/server.xml.erb'),
  } ->
  file { '/etc/init.d/bamboo':
    # note: possible dependency on File ["${dir}/bamboo.sh"] below
    ensure => link,
    target => "${dir}/bamboo.sh",
  } ->
  file { '/etc/default/bamboo':
    ensure  => present,
    content => "RUN_AS_USER=${user}
BAMBOO_PID=${home}/bamboo.pid
BAMBOO_LOG_FILE=${home}/logs/bamboo.log",
  } ->
  service { 'bamboo':
    ensure     => running,
    enable     => $versionGE510, # service bamboo does not support chkconfig
    hasrestart => true,
    hasstatus  => true,
  }


  if $versionGE510 {
    file { "${dir}/bamboo.sh":
      content => template('bamboo/bamboo.sh.erb'),
      require => Exec['bamboo'],
      before => [File['/etc/init.d/bamboo'],Service['bamboo'],],
    } 
  } 

}
