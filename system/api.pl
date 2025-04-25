#!/usr/bin/env perl

# skript se na serveru spustí pomocí
# morbo api.pl

# Pak naslouchá na defaultním portu 3000 a lokálně funguje např.:
# curl http://localhost:3000/api/test

# Perlovský balíček Mojolicious obsahující i příkaz morbo se instaloval pomocí 
# sudo apt-get install libmojolicious-perl

# Pro přesměrování požadavků z Apache2 bylo mj. potřeba nastavit v /etc/apache2/sites-available/000-default.conf v sekci <VirtualHost *:80>:
#        ServerName localhost
#        # Proxy pro /api/detect a /api/test
#        ProxyPass "/api/detect" "http://localhost:3000/api/detect"
#        ProxyPassReverse "/api/detect" "http://localhost:3000/api/detect"
#        ProxyPass "/api/test" "http://localhost:3000/api/test"
#        ProxyPassReverse "/api/test" "http://localhost:3000/api/test"
# A v /etc/apache2/apache2.conf bylo potřeba přidat:
#        LoadModule proxy_module modules/mod_proxy.so
#        LoadModule proxy_http_module modules/mod_proxy_http.so
# Pak funguje např.
# curl http://localhost/api/test

use strict;
use warnings;
use Mojolicious::Lite;
use IPC::Run qw(run);
use JSON;
use Encode;
use File::Basename;
# use Data::Dumper;

# STDIN and STDOUT in UTF-8
binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my $script_path = $0;  # Získá název spuštěného skriptu s cestou
my $script_dir = dirname($script_path);  # Získá pouze adresář ze získané cesty

# Endpoint pro info
any '/api/info' => sub {
    my $c = shift;
    my $method = $c->req->method;

    # Spuštění skriptu ponk.pl s parametrem pro získání info
    my @cmd = ('/usr/bin/perl', "$script_dir/ponk.pl",
               '--info');
    my $stdin_data = '';
    my $result_json;
    run \@cmd, \$stdin_data, \$result_json;
        
    # Decode the output as a JSON object
    my $json_data = decode_json($result_json);

    # Access the 'data', 'stats' and other items in the JSON object
    my $version  = $json_data->{'version'};
    my $features = $json_data->{'features'};
    my $version_utf8 = decode_utf8($version);
    my $features_utf8 = decode_utf8($features);

    # Vytvoření odpovědi
    $c->res->headers->content_type('application/json; charset=UTF-8');
    my $data = {message => "This is the info function of the PONK service called via $method.",
                version => "$version_utf8", features => "$features_utf8" };
    # print STDERR Dumper($data);
    return $c->render(json => $data);
};

# Endpoint pro process
any '/api/process' => sub {
    my $c = shift;
    my $method = $c->req->method;

    my $text = $c->param('text'); # input text
    my $input_format = $c->param('input') // ''; # input format
    my $input_format_orig = $input_format;
    $input_format = 'docxBase64' if $input_format eq 'docx'; # the input is actually encoded in Base64, so we need to use this internal input format parameter
    my $output_format = $c->param('output') // ''; # output format
    my $apps = $c->param('apps') // ''; # a comma-separated list of internal apps to call
    my $uilang = $c->param('uilang') // ''; # UI language
    # my $randomize = defined $c->param('randomize') ? 1 : 0; # randomization

    # Spuštění skriptu ponk.pl s předáním parametrů a standardního vstupu
    my @cmd = ('/usr/bin/perl', "$script_dir/ponk.pl",
               '--stdin',
               '--input-format', $input_format, 
               '--output-format', $output_format,
               '--ui-language', $uilang,
               '--apps', $apps,
               '--output-statistics');
    #if ($randomize) {
    #    push(@cmd, '--randomize');
    #}
    my $stdin_data = $text;
    my $result_json;
    run \@cmd, \$stdin_data, \$result_json;

    # Decode the output as a JSON object
    my $json_data = decode_json($result_json);

    # Access the 'data', 'stats' and other items in the JSON object
    my $result  = $json_data->{'data'};
    my $stats = $json_data->{'stats'} // '';
    my $app1_features = $json_data->{'app1_features'} // '';
    my $app1_rule_info = $json_data->{'app1_rule_info'} // '';
    my $app2_colours = $json_data->{'app2_colours'} // '';

    # Read them as UTF-8
    my $result_utf8 = decode_utf8($result);
    my $stats_utf8 = decode_utf8($stats);
    my $app1_features_utf8 = decode_utf8($app1_features);
    my $app1_rule_info_utf8 = decode_utf8($app1_rule_info);
    my $app2_colours_utf8 = decode_utf8($app2_colours);

    # Compile the answer
    $c->res->headers->content_type('application/json; charset=UTF-8');
    my $data = {message => "This is the process function of the PONK service called via $method; input format=$input_format_orig, output format=$output_format.",
                result => "$result_utf8",
                stats => "$stats_utf8",
                app1_features => "$app1_features_utf8",
                app1_rule_info => "$app1_rule_info_utf8",
                app2_colours => "$app2_colours_utf8"
               };
    # print STDERR Dumper($data);
    return $c->render(json => $data);

};

app->config(hypnotoad => {
    listen  => ['http://*:8080'],
    workers => 4,
    heartbeat_timeout => 50,
});
#app->log->level('debug');
app->start;

