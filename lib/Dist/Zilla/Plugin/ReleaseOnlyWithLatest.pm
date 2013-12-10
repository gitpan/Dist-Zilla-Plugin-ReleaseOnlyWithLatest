package Dist::Zilla::Plugin::ReleaseOnlyWithLatest;
BEGIN {
  $Dist::Zilla::Plugin::ReleaseOnlyWithLatest::AUTHORITY = 'cpan:GETTY';
}
{
  $Dist::Zilla::Plugin::ReleaseOnlyWithLatest::VERSION = '0.002';
}
# ABSTRACT: Release the distribution only if specific modules are at latest state

use Moose;

with qw(
  Dist::Zilla::Role::BeforeRelease
);

use version;
use LWP::Simple;
use Parse::CPAN::Packages::Fast;
use File::Temp qw/ :POSIX /;
use namespace::autoclean;

around mvp_multivalue_args => sub {
  my ($orig, $self) = @_;
  $self->$orig, qw( package );
};

has package => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub {[]} );
has index => ( is => 'ro', isa => 'Str', default => sub {
  'http://www.cpan.org'
} );

has index_url => ( is => 'ro', lazy => 1,
  default => sub { shift->index.'/modules/02packages.details.txt.gz' }
);

sub before_release {
  my ( $self ) = @_;
  my $url = $self->index_url;
  if (@{$self->package}) {
    my $packages;
    my $tempfile = tmpnam;
    if (is_success(getstore($url,$tempfile))) {
      $packages = Parse::CPAN::Packages::Fast->new($tempfile);
    } else {
      $self->log_fatal("Failed to download $url!");
    }
    for (@{$self->package}) {
      my @packages = split(/,/,$_);
      for my $package (@packages) {
        my $version = version->parse($packages->package($package)->version);
        $self->log_fatal("Wasn't able to find $package version on $url!") unless $version;
        my $installed_version = version->parse($self->get_local_version($package));
        if ($installed_version != $version) {
          $self->log_fatal("You need $version of $package, but you have $installed_version!");
        }
      }
    }
  }
}
 
sub get_local_version {
  my ( $self, $module ) = @_;
  require Module::Data;
  my $v;
  {
    local $@;
    eval {
      my $m = Module::Data->new( $module );
      $m->require;
      $v = $m->version;
      1
    } or return;
  };
  return unless defined $v;
  return version->parse($v) unless ref $v;
  return $v;
}


1;

__END__

=pod

=head1 NAME

Dist::Zilla::Plugin::ReleaseOnlyWithLatest - Release the distribution only if specific modules are at latest state

=head1 VERSION

version 0.002

=head1 SYNOPSIS

  # Requires latest release from CPAN
  [ReleaseOnlyWithLatest]
  package = Dist::Zilla::PluginBundle::Author::YOU

  # Requires latest release from a custom CPAN
  [ReleaseOnlyWithLatest]
  index = http://duckpan.org
  package = Dist::Zilla::Plugin::UploadToDuckPAN

  # Several ways to add several modules
  [ReleaseOnlyWithLatest]
  package = Package::A,Package::B
  package = Package::C,Package::D  

=head1 DESCRIPTION

=head1 AUTHOR

Torsten Raudssus <torsten@raudss.us>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
