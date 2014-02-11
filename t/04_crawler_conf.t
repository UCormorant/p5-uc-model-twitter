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
        plan tests => 3;
        isa_ok $class, 'Uc::Model::Twitter::Crawler', '$class';

        can_ok $class, $_ for qw(
            conf

            run
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

        subtest 'command conf' => sub {
            my $default_file = catfile($ENV{HOME}, '.'.($script_file =~ s/(?:\.\w+)*$//r));
            my $config_file_copy = $config_file.'.copy';
            before {
                t::Util->filecopy($config_file, $config_file_copy);
            };
            after {
                unlink $default_file if -f $default_file;
                unlink $config_file  if -f $config_file;
                t::Util->filecopy($config_file_copy, $config_file);
            };

            plan tests => 6;

            my $command = 'conf';
            my (@args, $output, $stdout, $stderr);

            my ($nt_mock_guard, $dbi_mock_guard, $dbh_moch_guard);
            $nt_mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                get_authorization_url => 'https://example.com/auth',
                request_access_token => sub { return @{$config}{qw/token token_secret user_id screen_name/}; },
            };
            $dbi_mock_guard = mock_guard 'DBI' => +{
                connect => $schema->dbh,
            };
            $dbh_moch_guard = mock_guard $schema->dbh => +{
                do => sub {
                    my $self = shift;
                    my $sql  = shift;
                    if ($sql !~ /^SET NAMES /) { $self->do($sql); }
                },
            };

            my $command_orig = \&Uc::Model::Twitter::Crawler::conf;
            my %answer = ();
            my $class_guard = mock_guard $class => +{
                conf => sub {
                    local $_;
                    my $stdin = catfile($ENV{HOME}, 'stdin');
                    close STDIN;
                    open STDIN, '>', $stdin;
                    print STDIN "$answer{$_}\n" for sort keys %answer;
                    print STDIN "\n" for 1..30;
                    close STDIN;
                    open STDIN, '<', $stdin;
                    $command_orig->(@_);
                },
            };

            subtest 'show help' => sub {
                plan tests => 2;

                @args = ($command, qw(-h));
                $output = local_term_merged { eval { $class->run(@_); 1; } or warn $@; } @args;
                like $output, qr/^Usage: $script_file $args[0]/, 'show help';
                like $output, qr/--config/,   'help text says about -c option';
            };

            subtest 'make config (no option)' => sub {
                plan tests => 2;

                %answer = (
                    '01_consumer_key'       => 'consumer',
                    '02_consumer_secret'    => 'consumer secret',
                    '03_pin'                => '12345',
                    '04_driver_name'        => 'm',
                    '05_db_name'            => 'test',
                    '06_db_user'            => 'test',
                    '07_db_pass'            => 'test',
                    '08_create_table'       => '',
                    '09_force_craete'       => '',
                );
                @args = ($command, qw());
                ($stdout, $stderr) = local_term { eval { $class->run(@_); 1; } or warn $@; } @args;
                ok -f $default_file, 'exists default config file';
                is $stderr, '', 'no warning is occered';
            };

            subtest 'pass routes' => sub {
                plan tests => 8;

                %answer = (
                    '01_consumer_setting' => '',
                    '02_token_setting'    => '',
                    '03_database_setting' => '',
                    '04_create_table'     => 'n',
                );
                @args = ($command, qw(-c), $config_file);
                ($stdout, $stderr) = local_term { eval { $class->run(@_); 1; } or warn $@; } @args;
                ok((not -f $default_file), 'does not exist default config file')
                    or unlink $default_file;
                is $stderr, '', 'no warning is occered';

                %answer = (
                    '01_consumer_setting' => '',
                    '02_token_setting'    => 'y',
                    '03_pin'              => '12345',
                    '04_database_setting' => '',
                    '05_create_table'     => 'n',
                );
                @args = ($command, qw(-c), $config_file);
                ($stdout, $stderr) = local_term { eval { $class->run(@_); 1; } or warn $@; } @args;
                ok((not -f $default_file), 'does not exist default config file')
                    or unlink $default_file;
                is $stderr, '', 'no warning is occered';

                %answer = (
                    '01_consumer_setting' => '',
                    '02_token_setting'    => '',
                    '03_database_setting' => 'y',
                    '04_driver_name'      => 's',
                    '05_db_name'          => 'db.sqlite',
                    '06_create_table'     => 'n',
                );
                @args = ($command, qw(-c), $config_file);
                ($stdout, $stderr) = local_term { eval { $class->run(@_); 1; } or warn $@; } @args;
                ok((not -f $default_file), 'does not exist default config file')
                    or unlink $default_file;
                is $stderr, '', 'no warning is occered';

                %answer = (
                    '01_consumer_setting' => '',
                    '02_token_setting'    => '',
                    '03_database_setting' => '',
                    '04_create_table'     => 'y',
                    '05_force_craete'     => 'y',
                );
                @args = ($command, qw(-c), $config_file);
                ($stdout, $stderr) = local_term { eval { $class->run(@_); 1; } or warn $@; } @args;
                ok((not -f $default_file), 'does not exist default config file')
                    or unlink $default_file;
                is $stderr, '', 'no warning is occered';
            };

            subtest 'fail test for consumer key' => sub {
                plan tests => 3;

                my $count = 0;
                my $local_nt_mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    get_authorization_url => sub {
                        $count++;
                        die sprintf "%s", Net::Twitter::Lite::Error->new(
                            http_response => HTTP::Response->new(401 => 'Unauthorized'),
                        );
                    },
                };

                %answer = (
                    '01_consumer_key'       => 'consumer',
                    '02_consumer_secret'    => 'consumer secret',
                );
                @args = ($command, qw());
                ($stdout, $stderr) = local_term { eval { $class->run(@_); 1; } or warn $@; } @args;
                ok((not -f $default_file), 'does not exist default config file')
                    or unlink $default_file;
                is $count, 1, 'try once';
                like $stderr, qr/invalid key set is given/, 'dying message';
            };

            subtest 'fail test for token' => sub {
                plan tests => 4;

                my $count = 0;
                my $local_nt_mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    request_access_token => sub {
                        $count++;
                        die sprintf "%s", Net::Twitter::Lite::Error->new(
                            http_response => HTTP::Response->new(401 => 'Unauthorized'),
                        );
                    },
                };

                %answer = (
                    '01_consumer_key'       => 'consumer',
                    '02_consumer_secret'    => 'consumer secret',
                    '03_pin'                => 'invalid',
                    '04_pin_retry'          => 'invalid',
                    '05_pin_last'           => 'invalid',
                );
                @args = ($command, qw());
                ($stdout, $stderr) = local_term { eval { $class->run(@_); 1; } or warn $@; } @args;
                ok((not -f $default_file), 'does not exist default config file')
                    or unlink $default_file;
                is $count, 3, 'try 3 times';
                like $stdout, qr/invalid pin code is given/, 'retry message';
                like $stderr, qr/invalid pin code is given/, 'dying message';
            };

            subtest 'fail test db settings' => sub {
                plan tests => 4;

                my $count = 0;
                my $local_dbi_mock_guard = mock_guard 'DBI' => +{
                    connect => sub { $count++; die; },
                };

                %answer = (
                    '01_consumer_key'       => 'consumer',
                    '02_consumer_secret'    => 'consumer secret',
                    '03_pin'                => 'invalid',
                    '04_driver_name'        => 's',
                    '05_db_name'            => 'invalid',
                    '06_driver_name_retry'  => 'm',
                    '07_db_name_retry'      => 'hoge',
                    '08_db_user'            => 'invalid',
                    '09_db_pass'            => 'invalid',
                    '10_retry'              => '',
                    '11_retry'              => '',
                );
                @args = ($command, qw());
                ($stdout, $stderr) = local_term { eval { $class->run(@_); 1; } or warn $@; } @args;
                ok((not -f $default_file), 'does not exist default config file')
                    or unlink $default_file;
                is $count, 2, 'call DBI->connect 2 times';
                like $stdout, qr/invalid db settings/, 'retry message';
                like $stderr, qr/invalid db settings/, 'dying message';
            };
        };
    };
};

done_testing;
