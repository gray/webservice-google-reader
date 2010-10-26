use strict;
use warnings;
use Test::More;

eval "use Test::Portability::Files; 1" or do {
    plan skip_all => 'Test::Portability::Files is not installed.';
};

run_tests();
