package TestApp::Controller::Root;

use Moose;
use namespace::autoclean;
use Data::Dumper;

BEGIN {
    extends 'Catalyst::Controller::ActionRole';
}

__PACKAGE__->config(
    namespace => '',
    action_args => {
        'store_action' => {
            store => {model => 'User'},
        },
    },
);

sub store_action :Path :Does('BuildDBICResult') {
    my ($self, $ctx) = @_;
    $ctx->response->body(Dumper $ctx->action->store);
}


__PACKAGE__->meta->make_immutable;

1;
