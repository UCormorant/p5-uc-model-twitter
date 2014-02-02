package Uc::Model::Twitter::Crawler;

use 5.014;
use warnings;
use utf8;

use Encode::Locale qw(decode_argv);
use Smart::Options;
use Net::Twitter::Lite::WithAPIv1_1 0.12006;

use Uc::Model::Twitter;
$UC::Model::Twitter::Crawler::VERSION = Uc::Model::Twitter->VERSION;

sub configure_encoding {
    STDIN->binmode(":encoding(console_in)");
    STDOUT->binmode(":encoding(console_out)");
    STDERR->binmode(":encoding(console_out)");
    decode_argv();
}

sub get_option_parser {
    my $parser = Smart::Options->new;

    # manual
    chomp(my $manual = <<"_USAGE_");
    Usage: $0 <command> -c config.toml
_USAGE_
    $parser->usage($manual);

    # command: conf
    chomp(my $usage_conf = <<"_USAGE_CONF_");
    Usage: $0 conf [-c config.toml]

    this command configures Twitter consumer key and secret key.
    these settings will be saved in config.toml or the file which is geven with -c option
_USAGE_CONF_
    $parser->subcmd( configure => Smart::Options->new->usage($usage_conf)->options(
        config => { type => 'Str', default => 'config.toml', describe => 'setting file path' },
    ) );

    # command: 
    chomp(my $usage_other = <<"_USAGE_OTHER_");
_USAGE_OTHER_
    $parser->subcmd( other => Smart::Options->new->usage($usage_other)->options(
        host      => { type => 'Str',  default => '127.0.0.1', describe => 'bind host' },
        port      => { type => 'Int',  default => '16668',     describe => 'listen port' },
        time_zone => { type => 'Str',  default => 'local',     describe => 'server time zone (ex. Asia/Tokyo)' },
        tweet2db  => { type => 'Bool', default => 0,           describe => 'load Tweet2DB plugin' },
        debug     => { type => 'Bool', default => 0,           describe => 'debug mode' },
    ) );

    $parser;
}

use namespace::clean;
# they're instance methods

sub new {
    my $class = shift;
    my %init_arg = @_;
    configure_encoding() if $init_arg{configure_encoding} && -t;

    bless { init_arg => \%init_arg }, $class;
}

sub run {
    my $self = shift;
    my @args = @_;

    my $parser = get_option_parser();
    my $option = $parser->parse(@args);

    my $command = $option->{command} // '';
    if    ($command eq 'conf') { $self->configure($option->{cmd_option}); }
    else                       { $option->showHelp; }

    $option;
}

sub configure { ... }

1; # Magic true value required at end of module
__END__

=encoding utf-8

=head1 NAME

Uc::Model::Twitter::Crawler - ucrawl-tweet's class

=head1 SYNOPSIS

    $ ucrawl-tweet user c18t

=head1 DESCRIPTION

Uc::Model::Twitter::Crawler is the generater class of ucrawl-tweet command's instance.

=head1 DEPENDENCIES

=over 2

=item L<perl> >= 5.14

=back

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
L<https://github.com/UCormorant/p5-uc-model-twitter/issues>

=head1 AUTHOR

U=Cormorant E<lt>u@chimata.orgE<gt>

=head1 LICENSE

Copyright (C) U=Cormorant.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 SEE ALSO

L<https://github.com/UCormorant/p5-uc-model-twitter>


=cut
