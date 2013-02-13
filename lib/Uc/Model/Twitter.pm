package Uc::Model::Twitter v1.0.1;

use 5.014;
use warnings;
use utf8;
use parent 'Teng';
__PACKAGE__->load_plugin('DBIC::ResultSet');

use Carp qw(croak);
use DBI qw(:sql_types);
use Uc::Model::Twitter::Util;
use autouse 'Uc::Model::Twitter::Util::MySQL'  => qw(create_table_mysql  drop_table_mysql );
use autouse 'Uc::Model::Twitter::Util::SQLite' => qw(create_table_sqlite drop_table_sqlite);

sub find_or_create_status_from_tweet {
    my ($self, $tweet, $attr) = @_;
    my $table = $self->schema->get_table('status');
    my $user  = $tweet->{user};

    $attr = {} unless $attr;
    $attr->{user_id}                 = '' if not exists $attr->{user_id};
    $attr->{ignore_remark_disabling} = '' if not exists $attr->{ignore_remark_disabling};

    croak "tweet must include user->{id} and user->{profile_id}" if not defined $user;

    my %columns;
    for my $col (@{$table->columns}) {
        $columns{$col} = $tweet->{$col} if     exists $tweet->{$col};
        $columns{$col} = $user->{$col}  if not exists $tweet->{$col} and exists $user->{$col};
        $columns{$col} = boolify($columns{$col}) if exists $columns{$col} && $table->get_sql_type($col) == SQL_BOOLEAN;
    }

    if (ref $tweet->{retweeted_status}) {
        $columns{retweeted_status_id} = $tweet->{retweeted_status}{id};

        $self->find_or_create_status_from_tweet($tweet->{retweeted_status}, $attr) if ref $tweet->{retweeted_status}{user};
    }

    if ($attr->{user_id} ne '') {
        my %update = (
            id => $tweet->{id},
            user_id => $attr->{user_id},
        );
        my $sql_types = $table->sql_types;
        my @boolean_cols;
        for my $col (keys $sql_types) {
            if (exists $tweet->{$col} && $sql_types->{$col} == SQL_BOOLEAN) {
                push @boolean_cols, $col;
                $update{$col} = boolify($tweet->{$col});
                delete $update{$col} if $attr->{ignore_remark_disabling} && !$update{$col};
            }
        }
        if (scalar grep { exists $update{$_} } @boolean_cols) {
            $self->update_or_create_remark_with_retweet(\%update);
        }
    }

    {
        my $profile = $self->find_or_create_profile_from_user($user);
        $columns{user_id}    = $profile->id;
        $columns{profile_id} = $profile->profile_id;
        $columns{protected}  = $profile->protected;
    }

    for my $col (keys %columns) {
        $columns{$col} = format_datetime($columns{$col}) if $table->get_sql_type($col) == SQL_DATETIME;
        $columns{$col} = deflate_utf8($columns{$col});
        $columns{$col} = numify($columns{$col}) if is_integer($table->get_sql_type($col));
    }

    $self->find_or_create('status', \%columns);
}

sub find_or_create_profile_from_user {
    my ($self, $user, $attr) = @_;
    my $table = $self->schema->get_table('user');

    $attr = {} unless $attr;

    my %columns;
    for my $col (@{$table->columns}) {
        $columns{$col} = $user->{$col} if exists $user->{$col};
        $columns{$col} = boolify($columns{$col}) if exists $columns{$col} && $table->get_sql_type($col) == SQL_BOOLEAN;
    }
    $columns{profile_id} = get_profile_id($user, $table) if !$columns{profile_id};

    %columns = %{user_default_value(\%columns, $table)};
    for my $col (@{$table->columns}) {
        $columns{$col} = deflate_utf8($columns{$col});
        $columns{$col} = numify($columns{$col}) if is_integer($table->get_sql_type($col));
    }

    $self->find_or_create('user', \%columns);
}

sub update_or_create_remark_with_retweet {
    my ($self, $update, $attr) = @_;
    my $table = $self->schema->get_table('remark');

    $attr = {} unless $attr;
    $attr->{retweeted_status} = '' if not exists $attr->{retweeted_status};

    croak "first argument must be included id and user_id" if !$update->{id} or !$update->{user_id};

    my %columns;
    for my $col (@{$table->columns}) {
        $columns{$col} = $update->{$col} if exists $update->{$col};
        $columns{$col} = boolify($columns{$col}) if exists $columns{$col} && $table->get_sql_type($col) == SQL_BOOLEAN;
    }

    for my $col (keys %columns) {
        $columns{$col} = deflate_utf8($columns{$col});
        $columns{$col} = numify($columns{$col}) if is_integer($table->get_sql_type($col));
    }

    my $retweeted_status_id = undef;
    if (ref $attr->{retweeted_status}) {
        $retweeted_status_id = $attr->{retweeted_status}{id};
    }
    else {
        my $tweet = $self->single('status', { id => $columns{id} });
        if ($tweet and defined $tweet->retweeted_status_id and $tweet->retweeted_status_id ne '') {
            $retweeted_status_id = $tweet->retweeted_status_id;
        }
    }
    if (defined $retweeted_status_id) {
        my %retweet_update = %columns;
        $retweet_update{id} = numify($retweeted_status_id);
        $self->update_or_create('remark', \%retweet_update);
    }

    $self->update_or_create('remark', \%columns);
}

sub create_table {
    given ($_[0]->dbh->{Driver}{Name}) {
        when ('SQLite') { create_table_sqlite(@_); }
        when ('mysql')  { create_table_mysql(@_); }
        default         { croak "'$_' is not supported."; }
    }
}

sub drop_table {
    given ($_[0]->dbh->{Driver}{Name}) {
        when ('SQLite') { drop_table_sqlite(@_); }
        when ('mysql')  { drop_table_mysql(@_); }
        default         { croak "'$_' is not supported."; }
    }
}

1; # Magic true value required at end of module
__END__

=head1 NAME

Uc::Model::Twitter - [One line description of module's purpose here]


=head1 VERSION

This document describes Uc::Model::Twitter version 1.0.0


=head1 SYNOPSIS

    use Uc::Model::Twitter;

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
  
Uc::Model::Twitter requires no configuration files or environment variables.


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
