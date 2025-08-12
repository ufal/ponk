#!/usr/bin/env perl

# skript se na serveru spustí pomocí
# morbo api.pl (testování, v jednu chvíli jen jeden klient)
# nebo hypnotoad api.pl (ostrý provoz, více klientů naráz)

# Pak v případě morbo naslouchá na defaultním portu 3000 a lokálně funguje např.:
# curl http://localhost:3000/api/info
# A v případě hypnotoad naslouchá na defaultním portu 8080 a lokálně funguje např.:
# curl http://localhost:8080/api/info

# Perlovský balíček Mojolicious obsahující i příkaz morbo se instaloval pomocí 
# sudo apt-get install libmojolicious-perl

# Pro přesměrování požadavků z Apache2 bylo mj. potřeba nastavit v /etc/apache2/sites-available/000-default.conf v sekci <VirtualHost *:80>:
#        ServerName localhost
#        # Proxy pro /api/process a /api/info
#        ProxyPass "/api/process" "http://localhost:8080/api/process"
#        ProxyPassReverse "/api/process" "http://localhost:8080/api/process"
#        ProxyPass "/api/info" "http://localhost:8080/api/info"
#        ProxyPassReverse "/api/info" "http://localhost:8080/api/info"
# (port 8080 pro hypnotoad, resp. 3000 pro morbo)

# A v /etc/apache2/apache2.conf bylo potřeba přidat:
#        LoadModule proxy_module modules/mod_proxy.so
#        LoadModule proxy_http_module modules/mod_proxy_http.so
# Pak funguje např.
# curl http://localhost/api/info

use strict;
use warnings;
use Mojolicious::Lite;
use Sys::Syslog qw(:standard :macros); # Načtení modulu Sys::Syslog s potřebnými konstantami
use IPC::Run qw(run);
use JSON;
use Encode;
use File::Basename;
use Net::DNS;

# use Data::Dumper;

# STDIN and STDOUT in UTF-8
binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my $script_path = $0;  # Získá název spuštěného skriptu s cestou
my $script_dir = dirname($script_path);  # Získá pouze adresář ze získané cesty

my $api_log = "$script_dir/log/api.log";

# Endpoint pro info
any '/api/info' => sub {
    my $c = shift;
    my $method = $c->req->method;

    my $uilang = $c->param('uilang') // ''; # UI language
    # Spuštění skriptu ponk.pl s parametrem pro získání info
    my @cmd = ('/usr/bin/perl', "$script_dir/ponk.pl",
               '--ui-language', $uilang,
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

    # Získání hlaviček pro původní informace
    my $referer = $c->req->headers->referer // 'unknown'; # Standardní referer
    my $forwarded_for = $c->req->headers->header('X-Forwarded-For') // 'unknown'; # Původní IP klienta
    my $forwarded_for_name = reverse_dns($forwarded_for);

    # Zápis do syslogu
    syslog(LOG_INFO, 'ponk: API request "process" from: "%s", X-Forwarded-For: "%s" ("%s"), method: "%s"',
           $referer, $forwarded_for, $forwarded_for_name, $method);
    syslog(LOG_INFO, 'ponk: API parameters: input format: "%s", output format: "%s", apps: "%s", UI language: "%s"',
           $input_format, $output_format, $apps, $uilang);

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
    my $stderr_output;

    # Calling the main app
    my $run_success = run \@cmd, \$stdin_data, \$result_json, \$stderr_output;

    my $exit_code = $? >> 8; # Get the exit code of the command
    my $text_size = length($text);

    # Log to $api_log
    open(my $log_fh, '>>', $api_log) or die "Cannot open log file $api_log: $!";
    my $log_message = scalar(localtime) . "\t"
                      . $method . "\t"
                      . $run_success . "\t"
                      . $exit_code . "\t"
                      . $referer . "\t"
                      . $forwarded_for . "\t"
                      . $forwarded_for_name . "\t"
                      . $text_size . "\t"
                      . $input_format . "\t"
                      . $output_format . "\t"
                      . $uilang . "\t"
		      . $apps
                      . "\n";

    print $log_fh encode_utf8($log_message);
    if (!$run_success) {
        print $log_fh encode_utf8("Error: $stderr_output\n") if $stderr_output;
    }
    close $log_fh;

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
    workers => 4,
    heartbeat_timeout => 50,
});

#app->log->level('debug');

app->start;


# Vrací název hostitele z reverzního DNS (PTR) nebo primární DNS server (SOA) pro zadanou IP adresu, preferuje veřejné IP z X-Forwarded-For.
sub reverse_dns {
    my $ip_input = shift;

    # Rozdělit X-Forwarded-For a vybrat první veřejnou IP adresu
    my @ips = split /\s*,\s*/, $ip_input;
    my $ip = 'unknown';
    foreach my $candidate (@ips) {
        if ($candidate =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ && $candidate !~ /^10\.|^192\.168\.|^172\.(1[6-9]|2[0-9]|3[0-1])\./) {
            $ip = $candidate;
            last;
        }
    }

    # Pokud není platná IP adresa, vrátit 'unknown'
    return 'unknown' unless $ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;

    my $resolver = Net::DNS::Resolver->new(nameservers => ['8.8.8.8', '8.8.4.4']);

    # PTR dotaz
    my $target = join(".", reverse split(/\./, $ip)) . ".in-addr.arpa";
    my $query = $resolver->query($target, "PTR");

    if ($query) {
        for my $rr ($query->answer) {
            next unless $rr->type eq "PTR";
            return $rr->ptrdname;
        }
    }

    # SOA dotaz
    my $zone = join(".", (reverse split(/\./, $ip))[1..3]) . ".in-addr.arpa";
    my $soa_query = $resolver->query($zone, "SOA");

    if ($soa_query) {
        for my $rr ($soa_query->answer) {
            next unless $rr->type eq "SOA";
            return $rr->mname;
        }
    }

    return 'unknown';
}

