use 5.010;
use Encode qw(encode);
use Digest::MD5 qw(md5_hex);

our @DEFAULT_VALUE_USER = qw(
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

sub get_profile_id {
    return md5_hex encode( 'utf8', join '', @{set_default_value(shift)}{@DEFAULT_VALUE_USER} );
}

sub set_default_value {
    my $user = shift;
    my $integer = [qw(
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
    )];
    for my $key (@DEFAULT_VALUE_USER) {
        my $default = "";
        given ($key) { when ($integer) { $default = 0; } }
        $user->{$key} = $default if not exists $user->{$key};
    }
    return $user;
}

1;
