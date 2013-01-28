package Uc::Twitter::Schema::ResultSetBaseModule;

use common::sense;
use warnings qw(utf8);
use parent qw(Exporter);

use Encode qw(encode_utf8);
use Digest::MD5 qw(md5_hex);
use DateTime::Format::HTTP;
use DateTime::Format::MySQL;

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

our @INTEGER_VALUE = qw(
    utc_offset

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

our @EXPORT = qw(
    format_datetime
    deflate_utf8
    get_profile_id
    set_default_value
);

sub format_datetime {
    my ($value, $col_info) = @_;
    return DateTime::Format::MySQL->format_datetime($value) if ref $value eq 'DateTime';
    if ($col_info->{data_type} eq 'datetime' or $col_info->{inflate_datetime}
            or $col_info->{data_type} eq 'date' or $col_info->{inflate_date}) {
        $value =~ s/\+0000/GMT/;
        $value = DateTime::Format::HTTP->parse_datetime($value);
        $value = DateTime::Format::MySQL->format_datetime($value);
    }
    $value;
}

sub deflate_utf8 {
    utf8::is_utf8($_[0]) ? encode_utf8($_[0]) : $_[0];
}

sub get_profile_id {
    md5_hex encode_utf8( join '', @{set_default_value(shift)}{@USER_VALUE_FOR_DIGEST} );
}

sub set_default_value {
    my $user = {%{+shift}};
    for my $key (@USER_VALUE_FOR_DIGEST) {
        my $default = "";
        given ($key) { when (\@INTEGER_VALUE) { $default = 0; } }
        $user->{$key} = $default if not defined $user->{$key};
    }
    $user;
}

1;
