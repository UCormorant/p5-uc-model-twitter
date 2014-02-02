package t::lib::MyTest::mysqld;
use strict;
use Test::mysqld;
use Test::More;
use JSON::PP qw(encode_json);

my $MYSQLD;

sub load {
    if (my $json = $ENV{TEST_MYSQLD}) {
        diag "TEST_DSN explicitly set. Not starting MySQL";
        return;
    }

    $MYSQLD = Test::mysqld->new(
        my_cnf => {
            "skip-networking" => ""
        },
    ) or diag "MyTest::mysqld: $Test::mysqld::errstr";

    $ENV{TEST_MYSQLD} = encode_json(+{ %$MYSQLD }) if $MYSQLD;
}

END { undef $MYSQLD }

1;
