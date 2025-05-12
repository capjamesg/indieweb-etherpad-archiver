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

    # remove <IWDiscordGateway> from message
    $body =~ s/<IWDiscordGateway>//g;

    # remove text in <> at beginning
    $body =~ s/<(.*?)>//g;

    my @split_contents = split " ", $body;
    my $url = $split_contents[1];
    my $wiki_page_url = $split_contents[2];

    # strip spaces from beginning
    $url =~ s/^\s+//;

    # if body starts with !archive and is invalid
    if ($body =~ /^\!archive help/) {
        $self->say(channel => $arguments->{channel}, body => "Usage: !archive <event page URL or Etherpad URL> (<events/wiki-url>)?");
        return;
    }
    

    # http or https events.indieweb.org
    if ($body =~ /^\!archive http[s]?:\/\/events.indieweb.org/) {
        my $result = CreateDocument::create_page($url, $wiki_page_url);

        $self->say(channel => $arguments->{channel}, body => $result);
    } elsif ($body =~ /^\!archive http[s]?:\/\/etherpad.indieweb.org/) {
        my $result = CreateDocument::create_page($url, $wiki_page_url, 1);

        $self->say(channel => $arguments->{channel}, body => $result);
    } elsif ($body =~ /^\!archive/) {
        $self->say(channel => $arguments->{channel}, body => "Usage: !archive <event page URL or Etherpad URL> <events/wiki-url>");
    } elsif ($body =~ /^\!february/) {
        $self->say(channel => $arguments->{channel}, body => "It's February 2nd");
    }
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
