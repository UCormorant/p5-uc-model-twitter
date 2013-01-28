package Uc::Model::Twitter::Util;

use 5.014;
use warnings;
use utf8;
use bigint;
use parent qw(Exporter);

use Carp qw(croak);
use DBI qw(:sql_types);
use Encode qw(find_encoding);
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

our @EXPORT = qw(
    format_datetime
    deflate_utf8
    boolify
    numify
    is_integer
    get_profile_id
    user_default_value
);

our $CODEC = find_encoding('utf8');

sub format_datetime {
    my $value = shift;
    $value = DateTime::Format::HTTP->parse_datetime($value =~ s/\+0000/GMT/r) if not ref $value;
    croak "format_datetime needs a date text or a DateTime object"            if not ref $value eq 'DateTime';
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
__END__

=head1 NAME

Uc::Model::Twitter::Util - [One line description of module's purpose here]


=head1 VERSION

This document describes Uc::Model::Twitter::Util


=head1 SYNOPSIS

    use Uc::Model::Twitter::Util;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Uc::Model::Twitter::Util requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-uc-twetter-schema@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

U=Cormorant  C<< <u@chimata.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2012, U=Cormorant C<< <u@chimata.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
