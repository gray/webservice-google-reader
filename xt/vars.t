use strict;
use warnings;
use Test::More;

eval "use Test::Vars; 1" or do {
    plan skip_all => 'Test::Vars is not installed.';
};

all_vars_ok();
