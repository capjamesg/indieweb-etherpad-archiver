use strict;
use warnings;


package WikiActions;

sub login_to_mediawiki {
    my $ua = $_[0];
    my $url = $_[1];

    my $data = "?action=query&meta=tokens&type=login&format=json";

    # convert to json 

    # send body
    my $login_response = $ua->post($ENV{'wiki_url'}.$data);

    my $json_response = JSON::decode_json($login_response->decoded_content);

    my %login_data = (
        "lgname" => %ENV{'lgname'},
        "lgpassword" => %ENV{'lgpassword'},
        "lgtoken" => $json_response->{'query'}->{'tokens'}->{'logintoken'},
        "format" => "json",
        "action" => "login"
    );

    $ua->post($ENV{'wiki_url'}, \%login_data);
}

sub get_csrf_token {
    my $ua = $_[0];

    my %csrf = (
        "action" => "query",
        "meta" => "tokens",
        "format" => "json"
    );

    decode_json($ua->post($ENV{'wiki_url'}, \%csrf)->decoded_content)->{'query'}->{'tokens'}->{'csrftoken'};
}

1;