use strict;
use warnings;

use Dotenv;
Dotenv->load;


package WikiActions;

sub login_to_mediawiki {
    my $ua = $_[0];
    my $url = $_[1];

    my $data = "?action=query&meta=tokens&type=login&format=json";

    my $login_response = $ua->post($ENV{WIKI_URL}.$data);

    if ($login_response->is_success) {
        my $json_response = JSON::decode_json($login_response->decoded_content);

        my %login_data = (
            "lgname" => $ENV{LGNAME},
            "lgpassword" => $ENV{LGPASSWORD},
            "lgtoken" => $json_response->{'query'}->{'tokens'}->{'logintoken'},
            "format" => "json",
            "action" => "login"
        );

        $ua->post($ENV{WIKI_URL}, \%login_data);
    }
}

sub get_csrf_token {
    my $ua = $_[0];

    my %csrf = (
        "action" => "query",
        "meta" => "tokens",
        "format" => "json"
    );

    JSON::decode_json($ua->post($ENV{WIKI_URL}, \%csrf)->decoded_content)->{'query'}->{'tokens'}->{'csrftoken'};
}

1;