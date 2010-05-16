use strict;
use warnings;
use Test::More;

eval "use Test::Portability::Files";
if ($@) {
    plan skip_all => 'Test::Portability::Files is not installed.';
}

run_tests();
