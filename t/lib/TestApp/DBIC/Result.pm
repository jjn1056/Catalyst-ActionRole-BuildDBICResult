package # Hide from PAUSE
  TestApp::DBIC::Result;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components(qw/PK::Auto InflateColumn::DateTime/);

1;

