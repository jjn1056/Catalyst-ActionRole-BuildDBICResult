#!/usr/bin/env perl

use strict;
use warnings;

my @core_requires = (
    'Moose' => '1.03',
    'Catalyst' => '5.80023',
    'Catalyst::Controller::ActionRole' => '0',
    'Perl6::Junction' => '1.40000',
);

my @test_build_requires = (
    'Test::More' => '0.94',
    'Catalyst::Test' => '0',
    'Catalyst::Controller::ActionRole' => '0',

);

use inc::Module::Install;

all_from 'lib/Catalyst/ActionRole/BuildDBICResult.pm';
requires @core_requires;
build_requires @test_build_requires;

auto_install;
WriteAll;

