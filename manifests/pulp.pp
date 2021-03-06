#
# === Class: profile::pulp
#
# Setup Pulp Server
#
# === Parameters
#  - rpmrepos - HASH - passed to pulp_rpmrepo provider
#. - rpmrepos_defualts - HASH - passed as defaults to create_resources
#
# === Sample invocation
#
# [*Puppet*]
#   class { 'profile::pulp': }
#
#
class profile::pulp (
  $rpmrepos = {},
  $rpmrepos_defaults = {},
  $internal_repos = false,
) {

  # LVM: DataDisk Mounts - please see hieradata/role/pulp.yaml
  include ::lvm

  # SELECT INTNERNAL OR EXTERNAL REPOS
  if $internal_repos {
    include ::repos::pulp2
    include ::repos::epel
  } else {
    include ::pulp::repo::upstream
    include ::epel
  }

  include ::pulp
  include ::pulp::admin


  # Populate RPM-GPG-KEY files
  file {'/var/lib/pulp/static/rpm-gpg':
    ensure  => 'directory',
    owner   => 'apache',
    group   => 'apache',
    source  => "puppet:///modules/${module_name}/pulp/rpm-gpg",
    recurse => true,
  }

  file {'/root/sync.sh':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    source  => 'puppet:///modules/profile/pulp/sync.sh',
    replace => false,

  }

  # RPM Repos
  create_resources('pulp_rpmrepo', $rpmrepos, $rpmrepos_defaults)

  # Ordering
  Class['lvm'] -> Class['pulp'] -> File['/var/lib/pulp/static/rpm-gpg'] -> Pulp_rpmrepo <| |> -> Pulp_schedule <| |>

  # Firewall
  firewall { '100 INPUT allow http(s) from all':
    dport  => [ '80', '443' ],
    proto  => 'tcp',
    action => 'accept',
    chain  => 'INPUT',
  }

  firewall { '100 INPUT allow http(s) from all IPv6':
    dport    => [ '80', '443' ],
    proto    => 'tcp',
    action   => 'accept',
    chain    => 'INPUT',
    provider => 'ip6tables',
  }
  
  # Rubygems hosting rule, we should review this
  firewall { '150 INPUT allow http(s) from all':
    dport  => [ '8808' ],
    proto  => 'tcp',
    action => 'accept',
    chain  => 'INPUT',
  }

  firewall { '200 OUTPUT allow http(s) to all':
    dport  => [ '80', '443' ],
    proto  => 'tcp',
    action => 'accept',
    chain  => 'INPUT',
  }

  firewall { '200 OUTPUT allow http(s) to all IPv6':
    dport    => [ '80', '443' ],
    proto    => 'tcp',
    action   => 'accept',
    chain    => 'INPUT',
    provider => 'ip6tables',
  }

  # firewall { '200 OUTPUT allow pulp/qpid ports from all':
  #   dport  => '5672',
  #   proto  => 'tcp',
  #   action => 'accept',
  #   chain  => 'INPUT',
  # }

  if str2bool($::settings::storeconfigs) {
    # Let other systems connect outbound to us.
    @@firewall { "200 OUTPUT Software Updates (pulp) at ${::ipaddress}:80/443":
      dport       => [80, 443],
      proto       => 'tcp',
      action      => 'accept',
      chain       => 'OUTPUT',
      destination => $::ipaddress,
      tag         => 'fw_pulp_out',
    }
  }
}
