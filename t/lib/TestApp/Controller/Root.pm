package TestApp::Controller::Root;

use Moose;
use namespace::autoclean;

BEGIN {
    extends 'Catalyst::Controller::ActionRole';
}

__PACKAGE__->config(
    namespace => '',
    action_args => {
        'store_action' => {
            store => {model => 'User'},
        },
        'store_actionrole' => {
            store => {model => 'User'},
        },
    },
);

use Data::Dumper;

sub store_action
    :Path('store_action') 
    :ActionClass('+TestApp::Action::BuildDBICResult')
{
    my ($self, $ctx) = @_;
    $ctx->response->body(Dumper $ctx->action->store);
}

sub store_actionrole
    :Path('store_actionrole')
    :Does('BuildDBICResult')
{
    my ($self, $ctx) = @_;
    $ctx->response->body(Dumper $ctx->action->store);
}

__PACKAGE__->meta->make_immutable;

1;
