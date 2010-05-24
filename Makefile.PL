#!/usr/bin/env perl

use strict;
use warnings;

my @core_requires = (
    'Moose' => '1.03',
    'Catalyst::Runtime' => '5.80024',
    'Catalyst::Controller::ActionRole' => '0',
    'Perl6::Junction' => '1.40000',
);

my @test_build_requires = (
    'Test::More' => '0.94',
    'DBIx::Class' => '0.08121',
    'Catalyst::Runtime' => '5.80024 ',
    'Catalyst::Controller::ActionRole' => '0',
    'Catalyst::Model::DBIC::Schema' => '0.41',
);

use inc::Module::Install;

all_from 'lib/Catalyst/ActionRole/BuildDBICResult.pm';
requires @core_requires;
build_requires @test_build_requires;

auto_install;
WriteAll;

