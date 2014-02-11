use t::Util;
use Test::More;
use Test::More::Hooks;
use Test::Exception;
use Test::Mock::Guard qw(mock_guard);
use Capture::Tiny qw(capture capture_merged);
use DBI;
use File::Basename qw(basename dirname);
use File::Spec::Functions qw(catfile);
use Scope::Guard qw(scope_guard);
use TOML qw(from_toml to_toml);

use Uc::Model::Twitter::Crawler;

sub local_term (&@) { _local_term(capture => @_); }
sub local_term_merged (&@) { _local_term(capture_merged => @_); }
sub _local_term {
    my $sub_name = shift;
    my $block = shift;
    local *STDIN;
    local *STDOUT;
    local *STDERR;
    local(@ARGV) = @_;

    no strict 'refs';
    &{"$sub_name"}(sub {
        Uc::Model::Twitter::Crawler->new( configure_encoding => 1 );
        $block->(@ARGV);
    });
}

plan tests => 1;

subtest 'ucrawl-tweet' => sub {
    my $class;
    my $config;
    my $config_file;
    my $script_file = basename($0);
    my $home_guard = t::Util->fake_home;
    my $verify_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
        verify_credentials => 1,
    };

    $config = from_toml(t::Util->slurp(catfile(dirname(__FILE__), 'crawler_config.toml'), 'abs'));
    $config->{db_name} = catfile($ENV{HOME}, 'db.sqlite');
    $config_file = catfile($ENV{HOME}, 'config.toml');
    t::Util->store($config_file, to_toml($config), 'abs');

    before { $class = Uc::Model::Twitter::Crawler->new(); };
    after  { undef $class; };

    plan tests => 2;

    subtest('$class->can' => sub {
        plan tests => 8;
        isa_ok $class, 'Uc::Model::Twitter::Crawler', '$class';

        can_ok $class, $_ for qw(
            conf
            user
            fav
            mention
            status

            run
            crawl
        );
    }) or return; # stop test unless all method can be called

    subtest 'run' => sub {
        my $schema = Uc::Model::Twitter->new(
            dbh => t::Util->setup_sqlite_dbh(@{$config}{qw(db_name db_user db_pass)}),
        );
        before { $schema->create_table; };
        after  { $schema->drop_table;   };

        plan tests => 2;
        isa_ok $class, 'Uc::Model::Twitter::Crawler', '$class';

        subtest 'no commnad' => sub {
            plan tests => 9;

            my (@args, $output);

            @args = ();
            $output = local_term_merged { $class->run(@_); } @args;
            like $output, qr/^Usage: $script_file/, 'show help';
            like $output, qr/--version/, 'help text says about -v option';

            @args = qw(-h);
            $output = local_term_merged { eval { $class->run(@_); }; } @args;
            like $output, qr/\bconf\b/,    'command conf is defined';
            like $output, qr/\buser\b/,    'command user is defined';
            like $output, qr/\bfav\b/,     'command fav is defined';
            like $output, qr/\bmention\b/, 'command mention is defined';
            like $output, qr/\bstatus\b/,  'command status is defined';

            @args = qw(-v);
            $output = local_term_merged { $class->run(@_); } @args;
            like $output, qr/@{[$class->VERSION]}/, '-v shows version';

            @args = qw(--version);
            $output = local_term_merged { $class->run(@_); } @args;
            like $output, qr/@{[$class->VERSION]}/, '--version shows version';
        };
    };
};

done_testing;
