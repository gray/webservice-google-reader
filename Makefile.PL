use strict;
use warnings;
use ExtUtils::MakeMaker;

my @prereq;
unless (eval { require IO::Socket::SSL; 1 }) {
    push @prereq, 'Crypt::SSLeay' => 0;
}

my %conf = (
    NAME          => 'WebService::Google::Reader',
    AUTHOR        => 'gray <gray@cpan.org>',
    LICENSE       => 'perl',
    VERSION_FROM  => 'lib/WebService/Google/Reader.pm',
    ABSTRACT_FROM => 'lib/WebService/Google/Reader.pm',
    PREREQ_PM     => {
        'Class::Accessor::Fast' => 0,
        'Encode'                => 0,
        'HTTP::Cookies'         => 0,
        'HTTP::Request::Common' => 0,
        'JSON'                  => 0,
        'LWP::UserAgent'        => 0,
        'URI'                   => 0,
        'URI::Escape'           => 0,
        'URI::QueryParam'       => 0,
        'XML::Atom'             => 0,
        'XML::LibXML'           => 0,
        @prereq
    },
    BUILD_REQUIRES => {
        'Test::More' => 0.82,
    },
    META_MERGE     => {
        resources  => {
            repository => 'http://github.com/gray/webservice-google-reader',
        },
        recommends => {
            'JSON::XS' => 2.0,
        },
    },
    dist          => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean         => { FILES => 'WebService-Google-Reader-*' },
);

my $eumm_version=$ExtUtils::MakeMaker::VERSION;
delete $conf{META_MERGE} if $eumm_version < 6.46;
$conf{PREREQ_PM} = {
    %{ $conf{PREREQ_PM} || {} }, %{ delete $conf{BUILD_REQUIRES} },
} if ($conf{BUILD_REQUIRES} and $eumm_version < 6.5503);

WriteMakefile(%conf);


sub MY::postamble {
    return <<"    MAKE_FRAG";
authortest:
\t\$(MAKE) -e \$(TEST_TYPE) TEST_FILES="xt/*.t"
    MAKE_FRAG
}

sub MY::dist_test {
    my $self = shift;
    return $self->MM::dist_test . <<"    MAKE_FRAG";
\tcd \$(DISTVNAME) && \$(MAKE) authortest \$(PASTHRU)
    MAKE_FRAG
}
