package # Hide from PAUSE
  TestApp;

use Moose 1.03;
use namespace::autoclean;

extends Catalyst => { -version => 5.80 };

__PACKAGE__->config(
	name => 'TestApp',
	'Model::Schema' => {
        schema_class => 'TestApp::DBIC',
		connect_info => {
			dsn => 'dbi:SQLite:dbname=:memory',
		},
	},
);

__PACKAGE__->setup;

1;
