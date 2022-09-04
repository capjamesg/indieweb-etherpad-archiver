package CreateDocument;

use warnings;
use strict;

use Dotenv;
use Mojo::DOM;
use URI::Find;

Dotenv->load;

sub get_etherpad_contents {
    my $first_found_etherpad = $_[0];
    my $date_of_event = $_[1];
    my $event_page_link = $_[2];
    my $event_name = $_[3];
    my $is_etherpad = $_[4] || 0;

    my $etherpad_ua = LWP::UserAgent->new;

    my $etherpad_request = $etherpad_ua->get($first_found_etherpad);

    my $etherpad_content = $etherpad_request->decoded_content;

    for my $line (split /\n/, $etherpad_content) {
        if ($line =~ /^-/) {
            $line =~ s/^-/* /;
        }
    }

    my @all_uris;

    my $parsed_document = URI::Find->new(sub {
        my ($uri) = shift;
        push @all_uris, $uri;
        return $uri;
    });

    $parsed_document->find(\$etherpad_content);

    for my $uri (@all_uris) {
        if (index ($uri, "https://indieweb.org/") == 0) {
            my $slug = substr($uri, 21);
            # replace uri with slug
            $etherpad_content = ($etherpad_content =~ s/$uri/[[$slug]]/r);
        } elsif (index ($uri, "http://indieweb.org/") == 0) {
            my $slug = substr($uri, 20);
            # replace uri with slug
            $etherpad_content = ($etherpad_content =~ s/$uri/[[$slug]]/r);
        }
    }

    if ($is_etherpad) {
        return $etherpad_content;
    }

    $first_found_etherpad =~ s/\/export\/txt//;

    my $header = "
'''<dfn>$event_name</dfn>''' was an IndieWeb meetup on Zoom held on $date_of_event.

* $event_page_link
* When: $date_of_event
* Archived from: $first_found_etherpad


    ";

    my $wiki_entry_body = $header . $etherpad_content;

    my $footer = "

{{Homebrew Website Club}}

[[Category:Events]]
    ";

    $wiki_entry_body .= $footer;

    $wiki_entry_body;
}

sub create_page {
    my $event_page_link = $_[0];
    my $wiki_page_url = $_[1];
    my $is_etherpad = $_[2] || 0;

    my $event_page_ua = LWP::UserAgent->new;

    my $parsed_event_page = Mojo::DOM->new($event_page_ua->get($event_page_link)->decoded_content);

    my $first_found_etherpad;

    my $event_name;
    my $date_of_event;
    my $links;

    if ($is_etherpad == 1) {
        $first_found_etherpad = $event_page_link;
        $event_name = $wiki_page_url;
        $date_of_event = "";
    } else {
        $first_found_etherpad = "";

        # find all links
        $links = $parsed_event_page->find('a');

        $event_name = $parsed_event_page->at('.p-name')->text;
        my @event_date = split 'T', $parsed_event_page->at('.dt-start')->attr('value');

        $date_of_event = $event_date[0];

        for my $link ($links->each) {
            if (!$link || !$link->attr('href')) {
                next;
            }

            my $href = $link->attr('href');

            if ($href =~ /etherpad.indieweb.org/) {
                $first_found_etherpad = $href;

                last;
            }
        }
    }

    if (!$first_found_etherpad) {
        return "Could not find Etherpad link on provided page.";
    }

    $first_found_etherpad .= "/export/txt";

    my $url = $ENV{WIKI_URL};

    my $ua = LWP::UserAgent->new(
        cookie_jar => {},
    );

    my $login = WikiActions::login_to_mediawiki($ua);
    my $csrf_token = WikiActions::get_csrf_token($ua);
    my $wiki_entry_body = get_etherpad_contents($first_found_etherpad, $date_of_event, $event_page_link, $event_name);

    $event_name = lc($event_name);
    $event_name =~ s/-//g;
    $event_name =~ s/\//-/g;
    $event_name =~ s/  / /g;
    $event_name =~ s/ /-/g;

    if (!$wiki_page_url) {
        $wiki_page_url = "events/$date_of_event-$event_name";
    }

    my %request = (
        "action" => "edit",
        "format" => "json",
        "title" => $wiki_page_url,
        "text" => $wiki_entry_body,
        "token" => $csrf_token
    );

    my $l = $ua->post($url, \%request);

    if ($l->is_success) {
        return "Created https://indieweb.org/$wiki_page_url. Please review the page to ensure the document is correctly formatted and remove any unnecessary text.";
    } else {
        return "There was an error and your wiki entry was not created."
    }
}

1;