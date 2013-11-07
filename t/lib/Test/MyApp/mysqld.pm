package Test::MyApp::mysqld;
use strict;
use warnings;
use Test::mysqld;
use JSON::PP;
use DBI;

our $SKIP_DROP_DB_MAP = {
    information_schema => 1,
    mysql              => 1,
    test               => 1,
};

my $tempfile = File::Spec->catfile(File::Spec->tmpdir, 'test_mysqld.json');

sub setup {
    my ($class, %config) = @_;

    my $mysqld;

    if ( -e $tempfile ) {
        open my $fh, '<', $tempfile or die $!;
        my $obj = decode_json(join '', <$fh>);
        $mysqld = bless $obj, 'Test::mysqld';
    }
    elsif ( my $json = $ENV{TEST_MYSQLD} ) {
        my $obj = decode_json($json);
        $mysqld = bless $obj, 'Test::mysqld';
    }
    else {
        $mysqld = Test::mysqld->new(my_cnf => {
            'skip-networking' => '',
            %config,
        }) or die $Test::mysqld::errstr;
    }

    return $mysqld;
}

sub cleanup {
    my ($class, $mysqld) = @_;
    my $dbh = DBI->connect($mysqld->dsn, '', '', {
        AutoCommit => 1,
        RaiseError => 1,
    });

    my $rs = $dbh->selectall_hashref('SHOW DATABASES', 'Database');
    for my $dbname (keys %$rs) {
        next if $SKIP_DROP_DB_MAP->{$dbname};
        $dbh->do("DROP DATABASE $dbname");
    }
}

1;
