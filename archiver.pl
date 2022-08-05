#!/usr/bin/perl

use warnings;
use strict;

use LWP::UserAgent;
use JSON;
use Mojo::DOM;

use lib '.';
use WikiActions;
use CreateDocument;

package UppercaseBot;
use base qw(Bot::BasicBot);

sub said {
    my $self = shift;
    my $arguments = shift;

    my $body = $arguments->{body};
    my @split_contents = split " ", $body;
    my $url = $split_contents[1];

    if ($body =~ /^\!archive http/) {
        my $result = CreateDocument::create_page($url);

        $self->say(channel => $arguments->{channel}, body => $result);
    } elsif ($body =~ /^\!archive/) {
        $self->say(channel => $arguments->{channel}, body => "Usage: !archive https://events.indieweb.org/link/to/events/page/");
    }
}

package main;

my $bot = UppercaseBot->new(
    server      => $ENV{'irc_server'},
    port        => $ENV{'irc_port'},
    channels    => ["#$ENV{'irc_channel'}"],
    nick        => $ENV{'irc_nick'},
    name        => $ENV{'irc_nick'}
);

$bot->run();