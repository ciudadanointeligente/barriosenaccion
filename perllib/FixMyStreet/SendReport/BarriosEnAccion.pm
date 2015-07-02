package FixMyStreet::SendReport::BarriosEnAccion;

use Moose;

BEGIN { extends 'FixMyStreet::SendReport::Email'; }


# Based on what Zurich does this sends emails using the platform itself
# Rather than using the users email.
sub send_from {
    my ( $self, $row ) = @_;

    return [ FixMyStreet->config('CONTACT_EMAIL'), FixMyStreet->config('CONTACT_NAME') ];
}

1;