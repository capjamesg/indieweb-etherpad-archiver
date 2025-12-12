package CreateDocument;

use warnings;
use strict;

use Dotenv;
use Mojo::DOM;
use URI::Find;
use JSON;

Dotenv->load;

sub get_etherpad_contents {
    my $first_found_etherpad = $_[0];
    my $date_of_event = $_[1];
    my $event_page_link = $_[2];
    my $event_name = $_[3];
    my $is_etherpad = $_[4] || 0;

    my $etherpad_ua = LWP::UserAgent->new;

    my $etherpad_request = $etherpad_ua->get($first_found_etherpad);

    my $is_front_end_study_hall = ($first_found_etherpad =~ m/front-end-study-hall/);
    my $is_photos_popup = ($first_found_etherpad =~ m/-photos-/);

    if (!$etherpad_request->is_success) {
        return ("Etherpad could not be retrieved.", 1);
    }
    my $date_inside_url = '';
    # look for date pattern in the first_found_etherpad url
    if ($first_found_etherpad =~ m/(\d{4})-(\d{2})-(\d{2})/) {
        $date_inside_url = "$1-$2-$3";
    }


    my $etherpad_content = $etherpad_request->decoded_content;

    my $line_count = 0;

    for my $line (split /\n/, $etherpad_content) {
        if ($line_count lt 5 && $line =~ m/Archived/) {
            return ("This etherpad has already been archived.", 1);
        }
        if ($line =~ /^-/) {
            $line =~ s/^-/* /;
        }
        $line_count++;
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
        return ($etherpad_content, 0);
    }

    $first_found_etherpad =~ s/\/export\/txt//;

    my $header = "
'''<dfn>[$event_page_link $event_name]</dfn>''' was an IndieWeb meetup on Zoom held on $date_of_event.

* Archived from: $first_found_etherpad

    ";

    my $wiki_entry_body = $header . $etherpad_content;

    my $footer = "\n\n";

    if ($is_front_end_study_hall) {
        if ($date_inside_url) {
            $footer .= "{{Front End Study Hall|date=$date_inside_url}}\n\n";
        } else {
            $footer .= "{{Front End Study Hall}}\n\n";
        }
        $footer .= "[[Category:Front_end]]\n";
    } elsif ($is_photos_popup)  {
        $footer .= "[[Category:Photos]]\n";
    } else {
        $footer .= "{{Homebrew Website Club}}\n\n";
    }
    $footer .= "[[Category:Events]]\n\t";

    $wiki_entry_body .= $footer;

    return ($wiki_entry_body, 0);
}

sub check_if_page_exists {
    my $wiki_page_url = $_[0];

    my $mediawiki_ua = LWP::UserAgent->new; 

    my $response = $mediawiki_ua->get("https://indieweb.org/wiki/api.php?action=parse&page=$wiki_page_url&prop=text&formatversion=2&format=json");

    my $decoded_json = decode_json($response->decoded_content);

    if ($decoded_json->{error}) {
        return 1;
    } else {
        return 0;
    }
}

sub create_page {
    my $event_page_link = $_[0];
    my $wiki_page_url = $_[1];
    my $is_etherpad = $_[2] || 0;

    # trim / from start of wiki_page_url
    # trim /export/txt if carried over from etherpad
    $wiki_page_url =~ s/^\///;
    $wiki_page_url =~ s/\/export\/txt//;

    my $mediawiki_page_exists = check_if_page_exists($wiki_page_url);

    if ($mediawiki_page_exists eq 0) {
        return "A wiki page already exists at the specified URL."
    }

    my $event_page_ua = LWP::UserAgent->new;

    my $event_page = $event_page_ua->get($event_page_link);

    if (!$event_page->is_success) {
        return "Event page could not be retrieved.";
    }

    my $parsed_event_page = Mojo::DOM->new($event_page->decoded_content);

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
    my ($wiki_entry_body, $success) = get_etherpad_contents($first_found_etherpad, $date_of_event, $event_page_link, $event_name);
    
    if ($success eq 1) {
        return $wiki_entry_body;
    }

    $event_name = lc($event_name);
    $event_name =~ s/-//g;
    $event_name =~ s/\//-/g;
    $event_name =~ s/  / /g;
    $event_name =~ s/ /-/g;
    
    my $first_found_etherpad_slug;
    
    if (!$wiki_page_url) {
        # make url events/first_found_etherpad slug, after https://etherpad.indieweb.org/
        $first_found_etherpad =~ s/\/export\/txt$//;
        $first_found_etherpad_slug = substr($first_found_etherpad, 30);
        $wiki_page_url = "events/$first_found_etherpad_slug";
    }
    
    my %request = (
        "action" => "edit",
        "format" => "json",
        "title" => $wiki_page_url,
        "text" => $wiki_entry_body,
        "token" => $csrf_token,
        "summary" => "Created event page using IndieWeb events / Etherpad archiver"
    );

    my $l = $ua->post($url, \%request);

    if ($l->is_success) {
        return "Created https://indieweb.org/$wiki_page_url. Please review the page to ensure the document is correctly formatted and remove any unnecessary text.";
    } else {
        return "There was an error and your wiki entry was not created."
    }
}

1;
