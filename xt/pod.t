use strict;
use warnings;
use Test::More;

eval "use Test::Pod 1.00; 1" or do {
    plan skip_all => 'Test::Pod 1.00 required for testing POD';
};

all_pod_files_ok();
