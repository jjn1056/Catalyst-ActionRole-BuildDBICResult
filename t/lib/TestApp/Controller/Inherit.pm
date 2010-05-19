package TestApp::Controller::Inherit;

use Moose;
use namespace::autoclean;

BEGIN {
    extends 'Catalyst::Controller';
}

__PACKAGE__->config(
    action_args => {
        'defaults' => {
            store => {model => 'User'},
        },
    },
);

use Data::Dumper;

sub defaults
    :Path('defaults') 
    :ActionClass('+TestApp::Action::BuildDBICResult')
{
    my ($self, $ctx) = @_;
    $ctx->response->body(Dumper $ctx->action);
}


__PACKAGE__->meta->make_immutable;

1;
