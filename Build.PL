use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Uc::Twitter::Schema',
    license             => 'perl',
    dist_author         => 'U=Cormorant <u@chimata.org>',
    dist_version_from   => 'lib/Uc/Twitter/Schema.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'Uc-Twitter-Schema-*' ],
);

$builder->create_build_script();
