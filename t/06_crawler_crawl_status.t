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
            status

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

        subtest 'command status' => sub {
            plan tests => 4;

            my $command = 'status';
            my $ua_method = 'show_status';
            my (@args, $output, $stdout, $stderr, $mock_guard);

            subtest 'show help' => sub {
                plan tests => 3;

                @args = ($command, qw(-h));
                $output = local_term_merged { eval { $class->run(@_); }; } @args;
                like $output, qr/^Usage: $script_file $args[0]/, 'show help';
                like $output, qr/--config/,   'help text says about -c option';
                like $output, qr/--no-store/, 'help text says about --no-store option';
            };

            subtest 'fail test' => sub {
                plan tests => 24;

                my $mock_guard;
                my $count;

                # 403
                $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    $ua_method => sub {
                        die Net::Twitter::Lite::Error->new(
                            http_response => HTTP::Response->new(403 => 'Forbidden'),
                            twitter_error => t::Util->open_json_file('twitter_error.179.json'),
                        );
                    },
                };
                @args = ($command, qw(1 -c), $config_file);
                ($stdout, $stderr) = local_term { $class->run(@_); } @args;
                like   $stdout, qr/\bstatus_id=1/, 'show status id';
                like   $stdout, qr/\b403\b/, 'show http status code';
                unlike $stdout, qr/\bcode=179\b/, 'does not show twitter error code';
                is $stderr, '', 'no warning is occered';

                # 404
                $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    $ua_method => sub {
                        die Net::Twitter::Lite::Error->new(
                            http_response => HTTP::Response->new(404 => 'Not Found'),
                            twitter_error => t::Util->open_json_file('twitter_error.34.json'),
                        );
                    },
                };
                @args = ($command, qw(1 -c), $config_file);
                ($stdout, $stderr) = local_term { $class->run(@_); } @args;
                like   $stdout, qr/\bstatus_id=1/, 'show status id';
                like   $stdout, qr/\b404\b/, 'show http status code';
                unlike $stdout, qr/\bcode=34\b/, 'does not show twitter error code';
                is $stderr, '', 'no warning is occered';

                undef $mock_guard;

                # 429
                $count = 0;
                $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    $ua_method => sub {
                        if (!$count++) {
                            die Net::Twitter::Lite::Error->new(
                                http_response => HTTP::Response->new(
                                    429 => 'Too Many Requests',
                                    ['x-rate-limit-reset' => time+3],
                                ),
                                twitter_error => t::Util->open_json_file('twitter_error.88.json'),
                            );
                        }
                        return t::Util->open_json_file("status.exclude_retweet.json");
                    },
                };
                @args = ($command, qw(2 -c), $config_file);
                ($stdout, $stderr) = local_term { $class->run(@_); } @args;
                like $stdout, qr/\bstatus_id=2/, 'show status id';
                like $stdout, qr/\b429\b/, 'show http status code';
                like $stdout, qr/\bcode=88\b/, 'show twitter error code';
                is $count, 2, 'sleeped once';
                is $stderr, '', 'no warning is occered';

                # 500
                $count = 0;
                $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    $ua_method => sub {
                        if (!$count++) {
                            die Net::Twitter::Lite::Error->new(
                                http_response => HTTP::Response->new(
                                    500 => 'Internal Server Error',
                                ),
                                twitter_error => t::Util->open_json_file('twitter_error.131.json'),
                            );
                        }
                        return t::Util->open_json_file("status.exclude_retweet.json");
                    },
                };
                @args = ($command, qw(3 -c), $config_file);
                ($stdout, $stderr) = local_term { $class->run(@_); } @args;
                like $stdout, qr/\bstatus_id=3/, 'show status id';
                like $stdout, qr/\b500\b/, 'show http status code';
                like $stdout, qr/\bcode=131\b/, 'show twitter error code';
                like $stdout, qr/\bsleep \d\b/, 'show sleep time';
                is $count, 2, 'sleeped once';
                is $stderr, '', 'no warning is occered';

                # without twitter_error
                $count = 0;
                $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    $ua_method => sub {
                        if (!$count++) {
                            die Net::Twitter::Lite::Error->new(
                                http_response => HTTP::Response->new(
                                    500 => 'Internal Server Error',
                                ),
                            );
                        }
                        return t::Util->open_json_file("status.exclude_retweet.json");
                    },
                };
                @args = ($command, qw(4 -c), $config_file);
                ($stdout, $stderr) = local_term { $class->run(@_); } @args;
                like $stdout, qr/\bstatus_id=4/, 'show status id';
                like $stdout, qr/\b500\b/, 'show http status code';
                like $stdout, qr/\bsleep \d\b/, 'show sleep time';
                is $count, 2, 'sleeped once';
                is $stderr, '', 'no warning is occered';
            };

            subtest 'status_id from ARGV' => sub {
                plan tests => 7;

                my $mock_guard;

                my $count = 0;
                $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    $ua_method => sub {
                        my $self = shift;
                        my $query = shift;
                        if (++$count == 2) {
                            die Net::Twitter::Lite::Error->new(
                                http_response => HTTP::Response->new(
                                    429 => 'Too Many Requests',
                                    ['x-rate-limit-reset' => time+3],
                                ),
                                twitter_error => t::Util->open_json_file('twitter_error.88.json'),
                            );
                        }
                        elsif ($count == 5 ) {
                            die Net::Twitter::Lite::Error->new(
                                http_response => HTTP::Response->new(
                                    403 => 'Forbidden',
                                ),
                                twitter_error => t::Util->open_json_file('twitter_error.179.json'),
                            );
                        }

                        my $tweet = t::Util->open_json_file("status.exclude_retweet.json");
                        $tweet->{id} = $query->{id};
                        return $tweet;
                    },
                };

                @args = ($command, qw(1 2 3 4 5 -c), $config_file);
                ($stdout, $stderr) = local_term { $class->run(@_); } @args;
                is $count, 6, 'call api 6 times';
                like   $stdout, qr/^1:/m, 'get id 1';
                like   $stdout, qr/^2:|\r2:/m, 'get id 2';
                like   $stdout, qr/^3:/m, 'get id 3';
                unlike $stdout, qr/^4:|\r4/m, 'do not get id 4';
                like   $stdout, qr/^5:/m, 'get id 5';
                is $stderr, '', 'no warning is occered';
            };

            subtest 'status_id from STDIN' => sub {
                plan tests => 7;

                my $command_orig = \&Uc::Model::Twitter::Crawler::status;
                my %answer = ();
                my $class_guard = mock_guard $class => +{
                    status => sub {
                        local $_;
                        my $stdin = catfile($ENV{HOME}, 'stdin');
                        close STDIN;
                        open STDIN, '>', $stdin;
                        print STDIN "$answer{$_}\n" for sort keys %answer;
                        close STDIN;
                        open STDIN, '<', $stdin;
                        $command_orig->(@_);
                    },
                };

                my $mock_guard;

                my $count = 0;
                $mock_guard = mock_guard 'Net::Twitter::Lite::WithAPIv1_1' => +{
                    $ua_method => sub {
                        my $self = shift;
                        my $query = shift;
                        if (++$count == 2) {
                            die Net::Twitter::Lite::Error->new(
                                http_response => HTTP::Response->new(
                                    429 => 'Too Many Requests',
                                    ['x-rate-limit-reset' => time+3],
                                ),
                                twitter_error => t::Util->open_json_file('twitter_error.88.json'),
                            );
                        }
                        elsif ($count == 5 ) {
                            die Net::Twitter::Lite::Error->new(
                                http_response => HTTP::Response->new(
                                    403 => 'Forbidden',
                                ),
                                twitter_error => t::Util->open_json_file('twitter_error.179.json'),
                            );
                        }

                        my $tweet = t::Util->open_json_file("status.exclude_retweet.json");
                        $tweet->{id} = $query->{id};
                        return $tweet;
                    },
                };

                %answer = (
                    '01' => '1',
                    '02' => '2',
                    '03' => '3',
                    '04' => '4',
                    '05' => '5',
                );
                @args = ($command, qw(- -c), $config_file);
                ($stdout, $stderr) = local_term { $class->run(@_); } @args;
                is $count, 6, 'call api 6 times';
                like   $stdout, qr/^1:/m, 'get id 1';
                like   $stdout, qr/^2:|\r2:/m, 'get id 2';
                like   $stdout, qr/^3:/m, 'get id 3';
                unlike $stdout, qr/^4:|\r4/m, 'do not get id 4';
                like   $stdout, qr/^5:/m, 'get id 5';
                is $stderr, '', 'no warning is occered';
            };
        };
    };
};

done_testing;
