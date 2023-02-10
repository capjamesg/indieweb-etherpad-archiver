#!/usr/bin/env perl
use Mojolicious::Lite;
use File::Slurp;

my $index = read_file('index.html', binmode => ':utf8');

get '/' => sub {
  my $c = shift;
  return $c->render(text => $index);
};

app->start;