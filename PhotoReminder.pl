#!/usr/bin/perl

use warnings;
use strict;

use LWP::UserAgent;
use JSON;
use Mojo::DOM;
use Web::Microformats2;

package UppercaseBot;
use base qw(Bot::BasicBot);

my $root_event_domain = "https://events.indieweb.org";
my $event_page_url = "https://events.indieweb.org/archive";

my $ua = LWP::UserAgent->new;

my @events_requiring_photo = ();

# get data from page
my $response = $ua->get($event_page_url);

# get first five events in h-feed
my $mf2_parser = Web::Microformats2::Parser->new;
my $mf2_doc    = $mf2_parser->parse( $response->decoded_content );

my $events = $mf2_doc->{items}[0]{children};

# first five events
my @events = @{$events}[0..4];

for my $event (@events) {
    my $url = $event->{properties}{url}[0];
    $url =~ s/http:\/\/example.com\///g;
    $url = $root_event_domain . "/" . $url;

    # retrieve url and check for featured photo
    my $response = $ua->get($url);

    my $parsed_mf2 = $mf2_parser->parse($response->decoded_content);

    my $photo = $parsed_mf2->{items}[0]{properties}{photo}[0];

    if (!$photo) {
        push @events_requiring_photo, $url;
        print "$url\n";
    }
}

# on load, say hello
sub connected {
    my $self = shift;

    $self->say(
        channel => $self->{channels}[0],
        body    => "Let's try again, shall we?"
    );

    my $message = "Good day! The following event pages may be missing a photo: \n";

    for my $event (@events_requiring_photo) {
        $message .= "$event \n";
    }

    $self->say(
        channel => $self->{channels}[0],
        body    => $message
    );
}

package main;

use Dotenv;
Dotenv->load;

my $bot = UppercaseBot->new(
    server      => $ENV{IRC_SERVER},
    port        => $ENV{IRC_PORT},
    channels    => ["#$ENV{IRC_CHANNEL}"],
    nick        => $ENV{IRC_NICK},
    name        => $ENV{IRC_NICK}
);

$bot->run();