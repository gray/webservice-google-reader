use strict;
use warnings;
use Test::More;

eval { require Test::Perl::Critic; 1 } or do {
    plan skip_all => "Test::Perl::Critic is not installed.";
};
Test::Perl::Critic->import( -profile => 'xt/perlcriticrc' );

all_critic_ok(qw( ex lib t xt ));
