package Uc::Model::Twitter::Schema;

use 5.014;
use warnings;
use utf8;
use Teng::Schema::Declare;

use DBI qw(:sql_types);
use DateTime::Format::MySQL;

table {
    name "status";
    pk qw( id created_at );
    columns (
        { name => "id",                      type => SQL_BIGINT   },
        { name => "created_at",              type => SQL_DATETIME },
        { name => "user_id",                 type => SQL_BIGINT   },
        { name => "profile_id",              type => SQL_VARCHAR  },
        { name => "text",                    type => SQL_VARCHAR  },
        { name => "source",                  type => SQL_VARCHAR  },
        { name => "in_reply_to_status_id",   type => SQL_BIGINT   },
        { name => "in_reply_to_user_id",     type => SQL_BIGINT   },
        { name => "in_reply_to_screen_name", type => SQL_VARCHAR  },
        { name => "retweeted_status_id",     type => SQL_BIGINT   },
        { name => "protected",               type => SQL_BOOLEAN  },
        { name => "truncated",               type => SQL_BOOLEAN  },
        { name => "statuses_count",          type => SQL_INTEGER  },
        { name => "favourites_count",        type => SQL_INTEGER  },
        { name => "friends_count",           type => SQL_INTEGER  },
        { name => "followers_count",         type => SQL_INTEGER  },
        { name => "listed_count",            type => SQL_INTEGER  },
    );
    inflate 'created_at' => sub { DateTime::Format::MySQL->parse_datetime($_[0]) };
    deflate 'created_at' => sub { ref $_[0] ? DateTime::Format::MySQL->format_datetime($_[0]) : $_[0] };
};

table {
    name "user";
    pk qw( id profile_id );
    columns (
        { name => "id",                                 type => SQL_BIGINT  },
        { name => "profile_id",                         type => SQL_VARCHAR },
        { name => "screen_name",                        type => SQL_VARCHAR },
        { name => "name",                               type => SQL_VARCHAR },
        { name => "location",                           type => SQL_VARCHAR },
        { name => "url",                                type => SQL_VARCHAR },
        { name => "description",                        type => SQL_VARCHAR },
        { name => "lang",                               type => SQL_VARCHAR },
        { name => "time_zone",                          type => SQL_VARCHAR },
        { name => "utc_offset",                         type => SQL_INTEGER },
        { name => "profile_image_url",                  type => SQL_VARCHAR },
        { name => "profile_image_url_https",            type => SQL_VARCHAR },
        { name => "profile_background_image_url",       type => SQL_VARCHAR },
        { name => "profile_background_image_url_https", type => SQL_VARCHAR },
        { name => "profile_banner_url",                 type => SQL_VARCHAR },
        { name => "profile_text_color",                 type => SQL_VARCHAR },
        { name => "profile_link_color",                 type => SQL_VARCHAR },
        { name => "profile_background_color",           type => SQL_VARCHAR },
        { name => "profile_sidebar_fill_color",         type => SQL_VARCHAR },
        { name => "protected",                          type => SQL_BOOLEAN },
        { name => "geo_enabled",                        type => SQL_BOOLEAN },
        { name => "verified",                           type => SQL_BOOLEAN },
        { name => "is_translator",                      type => SQL_BOOLEAN },
        { name => "contributors_enabled",               type => SQL_BOOLEAN },
        { name => "default_profile",                    type => SQL_BOOLEAN },
        { name => "default_profile_image",              type => SQL_BOOLEAN },
        { name => "profile_use_background_image",       type => SQL_BOOLEAN },
        { name => "profile_background_tile",            type => SQL_BOOLEAN },
    );
};

table {
    name "remark";
    pk qw( id user_id );
    columns (
        { name => "id",        type => SQL_BIGINT  },
        { name => "user_id",   type => SQL_BIGINT  },
        { name => "favorited", type => SQL_BOOLEAN },
        { name => "retweeted", type => SQL_BOOLEAN },
    );
};

table {
    name "profile_image";
    pk qw( url );
    columns (
        { name => "url",   type => SQL_VARCHAR },
        { name => "image", type => SQL_BLOB    },
    );
};


package Uc::Model::Twitter::Row::Status;
use parent 'Teng::Row';

sub user { # belongs_to
    my $self = shift;
    $self->{_prv_umt_profile} //= $self->{teng}->single('user', { id => $self->user_id, profile_id => $self->profile_id });
}

sub remarks { # has_many
    my $self = shift;
    $self->{teng}->search('remark', { id => $self->id });
}


package Uc::Model::Twitter::Row::User;
use parent 'Teng::Row';

sub tweets { # has_many
    my $self = shift;
    $self->{teng}->search('status', { user_id => $self->id });
}

sub remarks { # has_many
    my $self = shift;
    $self->{teng}->search('remark', { user_id => $self->id });
}


package Uc::Model::Twitter::Row::Remark;
use parent 'Teng::Row';

sub tweet { # belongs_to
    my $self = shift;
    $self->{_prv_umt_tweet} //= $self->{teng}->single('status', { id => $self->id });
}

sub user { # belongs_to
    my $self = shift;
    $self->{_prv_umt_profile} //= $self->{teng}->single('user', { id => $self->user_id });
}


package Uc::Model::Twitter::Row::ProfileImage;
use parent 'Teng::Row';

1; # Magic true value required at end of module
__END__

=head1 NAME

Uc::Model::Twitter::Schema - [One line description of module's purpose here]


=head1 VERSION

This document describes Uc::Model::Twitter::Schema


=head1 SYNOPSIS

    use Uc::Model::Twitter::Schema;

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
  
Uc::Model::Twitter::Schema requires no configuration files or environment variables.


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
