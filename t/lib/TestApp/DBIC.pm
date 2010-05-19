package # hide from PAUSE
  TestApp::DBIC;

use base qw/DBIx::Class::Schema/;
__PACKAGE__->load_namespaces(default_resultset_class => 'DefaultRS');

1;

