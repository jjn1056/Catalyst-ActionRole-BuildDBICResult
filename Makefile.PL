#!/usr/bin/env perl

use strict;
use warnings;
use inc::Module::Install;

requires (
    'Moose' => '1.10',
    'MooseX::Types' => '0.23',
    'Catalyst::Runtime' => '5.80025',
    'Perl6::Junction' => '1.40000',
    'Catalyst::Controller::ActionRole' => '0.15',
    'Try::Tiny' => '0.06',
);

build_requires (
    'Test::More' => '0.94',
    'DBIx::Class' => '0.08123',
    'Catalyst::Runtime' => '5.80025',
    'Catalyst::Model::DBIC::Schema' => '0.43',
);

all_from 'lib/Catalyst/ActionRole/BuildDBICResult.pm';
auto_install;
WriteAll;

