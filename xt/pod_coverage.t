use strict;
use warnings;
use Test::More;

eval "use Test::Pod::Coverage 1.00; 1" or do {
    plan skip_all => 'Test::Pod::Coverage 1.00 is not installed.';
};

all_pod_coverage_ok();
