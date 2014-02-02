package Uc::Model::Twitter::Util;

use 5.014;
use warnings;
use utf8;
use bigint;
use parent qw(Exporter);
use experimental qw(smartmatch);

use Carp qw(croak);
use DBI qw(:sql_types);
use Encode qw(find_encoding);
use Digest::MD5 qw(md5_hex);
use DateTime::Format::HTTP;
use DateTime::Format::MySQL;

our @EXPORT = qw(
    format_datetime
    deflate_utf8
    boolify
    numify
    is_integer
    get_profile_id
    user_default_value
);

our @USER_VALUE_FOR_DIGEST = qw(
    screen_name
    name
    location
    url
    description
    lang
    time_zone
    utc_offset

    profile_image_url
    profile_image_url_https
    profile_background_image_url
    profile_background_image_url_https
    profile_banner_url

    profile_text_color
    profile_link_color
    profile_background_color
    profile_sidebar_fill_color

    protected
    geo_enabled
    verified
    is_translator
    contributors_enabled

    default_profile
    default_profile_image
    profile_use_background_image
    profile_background_tile
);

my $CODEC = find_encoding('utf8');

sub format_datetime {
    my $value = shift;
    $value = DateTime::Format::HTTP->parse_datetime($value =~ s/\+0000/GMT/r) if not ref $value;
    croak "format_datetime requires a date text or a DateTime object"            if not ref $value eq 'DateTime';
    DateTime::Format::MySQL->format_datetime($value);
}

sub deflate_utf8 {
    utf8::is_utf8($_[0]) ? $CODEC->encode($_[0]) : $_[0];
}

sub boolify {
    my $value = shift;
    $value = 1 if $value =~ /^true$/i;
    $value = 0 if $value =~ /^false$/i;
    $value ? 1 : 0;
}

sub numify { ${\shift}-0; }

sub is_integer { shift ~~ [SQL_TINYINT, SQL_INTEGER, SQL_SMALLINT, SQL_BIGINT]; }

sub get_profile_id {
    md5_hex $CODEC->encode( join '', @{user_default_value($_[0], $_[1])}{@USER_VALUE_FOR_DIGEST} );
}

sub user_default_value {
    my $user  = shift;
    my $table = shift;
    $user = defined $user && ref $user ? {%$user} : {};
    for my $key (@USER_VALUE_FOR_DIGEST) {
        my $default = "";
        if (is_integer($table->get_sql_type($key))) { $default = 0; }
        $user->{$key} = $default if not defined $user->{$key};
    }
    $user;
}

1; # Magic true value required at end of module
