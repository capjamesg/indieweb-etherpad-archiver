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

    # http or https events.indieweb.org
    if ($body =~ /^\!archive http[s]?:\/\/events.indieweb.org/) {
        my $result = CreateDocument::create_page($url);

        $self->say(channel => $arguments->{channel}, body => $result);
    } elsif ($body =~ /^\!archive/) {
        $self->say(channel => $arguments->{channel}, body => "Usage: !archive https://events.indieweb.org/link/to/events/page/");
    }
}

package main;

use Dotenv;
Dotenv->load;

print $ENV{IRC_NICK};

my $bot = UppercaseBot->new(
    server      => $ENV{IRC_SERVER},
    port        => $ENV{IRC_PORT},
    channels    => ["#$ENV{IRC_CHANNEL}"],
    nick        => $ENV{IRC_NICK},
    name        => $ENV{IRC_NICK}
);

$bot->run();