package # hide from PAUSE
  TestApp::DBIC;

use base qw/DBIx::Class::Schema/;
__PACKAGE__->load_namespaces(default_resultset_class => 'DefaultRS');

sub installdb_and_deploy_seed {
    my $class = shift @_;

}

1;

