#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use LWP::UserAgent;
use HTTP::Request::Common; # for calling ponk-app1
use URI::Escape;
use JSON;
use Tree::Simple;
use List::Util qw(min max);
use Getopt::Long; # reading arguments
use POSIX qw(strftime round); # naming a file with date and time; rounding a number
use File::Basename;
use Time::HiRes qw(gettimeofday tv_interval); # to measure how long the program ran
use Sys::Hostname;
use IPC::Run qw(run);
use MIME::Base64;
use Encode;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

use FindBin qw($Bin);  # $Bin je adresář, kde je skript
use lib "$Bin/lib";    # Absolutní cesta k lib

use UD v1.6.0;
use mylog v1.0.0;
$mylog::name = 'PONK';

# STDIN and STDOUT in UTF-8
binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my $start_time = [gettimeofday];

my $VER_en = '0.54 20251209'; # version of the program
my $VER_cs = $VER_en; # version of the program

my @features_cs = ('celkové míry', 'gramatická pravidla', 'lexikální překvapení');
my @features_en = ('overall text measures', 'grammatical rules', 'lexical surprise');

my $FEATS_cs = join(' • ', @features_cs); 
my $FEATS_en = join(' • ', @features_en); 

my $DESC_cs = "<h5>Vlastnosti této verze PONKu:</h5>\n<ul>\n";
my $DESC_en = "<h5>Features in this PONK version:</h5>\n<ul>\n";

foreach my $feature (@features_cs) {
  $DESC_cs .= "<li>$feature\n";
}

foreach my $feature (@features_en) {
  $DESC_en .= "<li>$feature\n";
}

$DESC_cs .= <<END_DESC_cs;
</ul>
<h5>Plánované vlastnosti:</h5>
<ul>
<li>Podpora ponk-app3 (zatím ve vývoji)
</ul>
END_DESC_cs

$DESC_en .= <<END_DESC_en;
</ul>
<h5>Planned features:</h5>
<ul>
<li>Support for ponk-app3 (not yet available)
</ul>
END_DESC_en

my $logging_level = 2; # default log level, can be changed using the -ll parameter (0=full, 1=limited, 2=anonymous)

my %logging_level_label = (0 => 'full', 1 => 'limited', 2 => 'anonymous');

my $udpipe_service_url = 'http://lindat.mff.cuni.cz/services/udpipe/api';
my $nametag_service_url = 'http://lindat.mff.cuni.cz/services/nametag/api'; 
my $ponk_app1_service_url = 'http://quest.ms.mff.cuni.cz/ponk-app1';
my $ponk_app2_service_url = 'http://quest.ms.mff.cuni.cz/ponk-app2';

my $hostname = hostname;
if ($hostname eq 'ponk') { # if running at this server, use versions of udpipe and nametag that do not log texts
  $udpipe_service_url = 'http://udpipe:11001';
  $nametag_service_url = 'http://udpipe:11002';
  $ponk_app1_service_url = 'http://ponk-app1:8000'; # for now, in practice no difference from the original URL
  # not working: $ponk_app2_service_url = 'http://ponk-app2:8000'; # for now, in practice no difference from the original URL
  $VER_cs .= ' (bez ukládání textů)';
  $VER_en .= ' (no text logging)';
  $logging_level = 2; # anonymous logging level is default but to be sure...
}

#############################
# Colours for html

my $color_highlight_general = 'darkred'; # general highlighting colour
my $color_highlight_app1 = 'darkgreen'; # highlighting colour for ponk-app1

#######################################


# default output format
my $INPUT_FORMAT_DEFAULT = 'txt';
# default UI language
my $OUTPUT_FORMAT_DEFAULT = 'html';
# default input format
my $UI_LANGUAGE_DEFAULT = 'en';
# default list of internal applications to call
my $APPS_DEFAULT = 'app1,app2';

# variables for arguments
my $input_file;
my $stdin;
my $input_format;
my $output_format;
my $output_statistics;
my $ui_language;
my $store_format;
my $store_statistics;
my $apps;
my $logging_level_override;
my $version;
my $info;
my $help;

# getting the arguements
GetOptions(
    'i|input-file=s'         => \$input_file, # the name of the input file
    'si|stdin'               => \$stdin, # should the input be read from STDIN?
    'if|input-format=s'      => \$input_format, # input format, possible values: txt (default), md, docx (and for internal purposes of the API server, also docxBase64)
    'of|output-format=s'     => \$output_format, # output format, possible values: html (default), conllu
    'os|output-statistics'   => \$output_statistics, # adds statistics to the output; if present, output is JSON with two items: data (in output-format) and stats (in HTML)
    'uil|ui-language=s'      => \$ui_language, # localize the response whenever possible to the given language: en (default), cs
    'sf|store-format=s'      => \$store_format, # log the result in the given format: txt, html, conllu
    'ss|store-statistics'    => \$store_statistics, # should statistics be logged as an HTML file?
    'ap|apps=s'              => \$apps, # a comma-separated list of internal apps to call, possible values: app1 (default), app2
    'll|logging-level=s'     => \$logging_level_override, # override the default (anonymous) logging level (0=full, 1=limited, 2=anonymous)
    'v|version'              => \$version, # print the version of the program and exit
    'n|info'                 => \$info, # print the info (program version and supported features) as JSON and exit
    'h|help'                 => \$help, # print a short help and exit
);

if (defined($logging_level_override)) {
  $logging_level = $logging_level_override;
}

my $script_path = $0;  # Získá název spuštěného skriptu s cestou
my $script_dir = dirname($script_path);  # Získá pouze adresář ze získané cesty


if ($version) {
  if ($ui_language eq 'cs') {
    print "PONK verze $VER_cs.\n";
  }
  else {
    print "PONK version $VER_en.\n";
  }
  exit 0;
}

if ($info) {
  my $json_data;
  if ($ui_language eq 'cs') {
    $json_data = { 
       version  => $VER_cs,
       features => $FEATS_cs,
    };
  }
  else {
    $json_data = {
       version  => $VER_en,
       features => $FEATS_en,
    };
  }
  # Encode the Perl data structure into a JSON string
  my $json_string = encode_json($json_data);
  # Print the JSON string to STDOUT
  print $json_string;
  exit 0;
}

if ($help) {
  print "PONK version $VER_en.\n";
  my $text = <<'END_TEXT';
Usage: ponk.pl [options]
options:  -i|--input-file [input text file name]
         -si|--stdin (input text provided via stdin)
         -if|--input-format [input format: txt (default), md, docx]
         -of|--output-format [output format: html (default), conllu]
         -os|--output-statistics (add PONK statistics to output; if present, output is JSON with two items: data (in output-format) and stats (in HTML))
        -uil|--ui-language [language: localize the response whenever possible to the given language: en (default), cs]
	 -sf|--store-format [format: log the output in the given format: html, conllu]
         -ss|--store-statistics (log statistics to an HTML file)
         -ap|--apps [a comma-separated list of internal apps to call, possible values: app1 (default), app2]
         -ll|--logging-level (override the default (anonymous) logging level (0=full, 1=limited, 2=anonymous))
          -v|--version (prints the version of the program and ends)
          -n|--info (prints the program version and supported features as JSON and ends)
          -h|--help (prints a short help and ends)
END_TEXT
  print $text;
  exit 0;
}

###################################################################################
# Summarize the program arguments to the log (except for --version and --help)
###################################################################################

mylog(2, "####################################################################\n");
mylog(2, "PONK $VER_en (logging level: $logging_level - $logging_level_label{$logging_level})\n");
mylog(2, "####################################################################\n");

mylog(0, "Arguments:\n");
 

if ($stdin) {
  mylog(0, " - input: STDIN\n");
}
elsif ($input_file) {
  mylog(0, " - input: file $input_file\n");
}

if (!defined $input_format) {
  mylog(0, " - input format: not specified, set to default $INPUT_FORMAT_DEFAULT\n");
  $input_format = $INPUT_FORMAT_DEFAULT;
}
elsif ($input_format !~ /^(txt|md|docx|docxBase64)$/) {
  mylog(0, " - input format: unknown ($input_format), set to default $INPUT_FORMAT_DEFAULT\n");
  $input_format = $INPUT_FORMAT_DEFAULT;
}
else {
  mylog(0, " - input format: $input_format\n");
}

$output_format = lc($output_format) if $output_format;
if (!defined $output_format) {
  mylog(0, " - output format: not specified, set to default $OUTPUT_FORMAT_DEFAULT\n");
  $output_format = $OUTPUT_FORMAT_DEFAULT;
}
elsif ($output_format !~ /^(txt|html|md|conllu)$/) {
  mylog(0, " - output format: unknown ($output_format), set to default $OUTPUT_FORMAT_DEFAULT\n");
  $output_format = $OUTPUT_FORMAT_DEFAULT;
}
else {
  mylog(0, " - output format: $output_format\n");
}

if ($output_statistics) {
  mylog(0, " - add PONK statistics to the output; output will be JSON with two items: data (in $output_format) and stats (in HTML)\n");
}

$ui_language = lc($ui_language) if $ui_language;
if (!defined $ui_language) {
  mylog(0, " - UI language: not specified, set to default '$UI_LANGUAGE_DEFAULT'\n");
  $ui_language = $UI_LANGUAGE_DEFAULT;
}
elsif ($ui_language !~ /^(en|cs)$/) {
  mylog(0, " - UI langauge: unknown ($ui_language), set to default '$UI_LANGUAGE_DEFAULT'\n");
  $ui_language = $UI_LANGUAGE_DEFAULT;
}
else {
  mylog(0, " - UI language: $ui_language\n");
}

$store_format = lc($store_format) if $store_format;
if ($store_format) {
  if ($store_format =~ /^(txt|html|md|conllu)$/) {
    mylog(0, " - log the output to a file in $store_format\n");
  }
  else {
    mylog(0, " - unknown format for logging the output ($store_format); the output will not be logged\n");
    $store_format = undef;
  }
}

if ($store_statistics) {
  mylog(0, " - log PONK statistics in an HTML file\n");
}

$apps = lc($apps) if $apps;
if (!defined $apps) {
  mylog(0, " - internal sub-applications to call: not specified, set to default '$APPS_DEFAULT'\n");
  $apps = $APPS_DEFAULT;
}
elsif ($apps !~ /^(app1|app2)(,(app1|app2))?$/) {
  mylog(0, " - internal sub-applications to call: unknown ($apps), set to default '$APPS_DEFAULT'\n");
  $apps = $APPS_DEFAULT;
}
else {
  mylog(0, " - internal sub-applications to call: $apps\n");
}

if (defined($logging_level_override)) {
  mylog(2, " - logging level override: $logging_level_override - $logging_level_label{$logging_level_override}\n");
}

mylog(0, "\n");


###################################################################################
# Now let us read the text file that should be processed
###################################################################################

my $input_content;

##### Reading from STDIN #####

if ($stdin) { # the input text should be read from STDIN
  mylog(2, "reading from stdin, input_format=$input_format\n");
  
  if ($input_format eq 'docx') {
    $input_content = convertSTDINFromDocx();
    mylog(2, " - stdin converted from binary docx to md\n");
    # mylog(0, "'$input_content'\n");
    $input_format = 'md';
  }
  elsif ($input_format eq 'docxBase64') { # for communication via API server
    $input_content = convertSTDINFromDocxBase64();
    mylog(2, " - stdin converted from docx encoded in Base64 to md\n");
    # mylog(0, "'$input_content'\n");
    $input_format = 'md';
  }
  else {
    $input_content = '';
    while (<>) {
      $input_content .= $_;
    }
  }
  my $current_datetime = strftime("%Y%m%d_%H%M%S", localtime);
  $input_file = "stdin_$current_datetime.txt"; # a fake file name for naming the output files
}

##### Reading from a file #####

elsif ($input_file) { # the input text should be read from a file
  mylog(2, "reading from input file: $input_file, input_format=$input_format\n");
  
  if ($input_format eq 'docx') { # binary docx format
    open my $fh, '<:raw', $input_file
      or die "Cannot open file '$input_file' for reading: $!";
    # Načtení celého souboru do proměnné bez specifikace počtu bajtů
    local $/ = undef;  # Nastavení, aby Perl četl celý soubor najednou
    my $input_data_binary = <$fh>;
    close $fh;
    $input_content = convertFromDocx($input_data_binary);
    mylog(2, " - input file converted from docx to md\n");
    # mylog(0, "'$input_content'\n");
    $input_format = 'md';
  }
  else { # text formats (txt, md)
    open my $file_handle, '<:encoding(utf8)', $input_file
      or die "Cannot open file '$input_file' for reading: $!";

    $input_content = do { local $/; <$file_handle> }; # reading the file into a variable
    close $file_handle;
  }
} else {
  mylog(2, "No input to process! Exiting!\n");
  exit -1;
}

# mylog(0, $input_content);



############################################################################################
# Let us parse the MarkDown (if needed) and remove the marks from the text
############################################################################################

my @markdown = (); # to store recognized (and removed) markdown marks with offset links to $pure_input_content
# the format of these stored marks and links: e.g., "Bold:567:573", meaning the text between these
# two offset positions is bold

if ($input_format eq 'md') {
  mylog(0, "Preprocessing MarkDown text...\n");
  $input_content =~ s/\r\n|\n/\n/g; # unification of line ends
  my @text = split (//, $input_content);
  my $pure_input_content = '';
  my $text_length = scalar(@text);
  push(@text, "\n"); 
  push(@text, "\n"); 
  push(@text, "\n"); 
  push(@text, "\n"); 
  push(@text, "\n"); 
  push(@text, "\n"); # add six newlines at the end so I do not have to check if I am out of the array boundaries if I reach six chars forward
  my $pure_text_offset = 0;
  my $bold_start_offset = -1;
  my $italics_start_offset = -1;
  my $prev_char = "\n"; # for, e.g., recognizing a new line; at the beginning, let us pretend that the prev. char was a newline

  # variables for prefixed headings:
  my $heading_start_offset = -1;
  my $heading_level = 0;
  my $heading_type = '';

  # variables for underlined headings:
  my $line_start_offset = 0;
  my $prev_line_start_offset = -1;
  my $prev_line_end_offset = -1;
  my $underlined_heading = ''; # '=' or '-' to indicate an ongoing reading of heading underlining
  my $underlined_heading_length = 0;
  
  for (my $i=0; $i<$text_length; $i++) { # read the text char after char
    my $char = $text[$i];
    my $next_char = $text[$i+1];
    my $next_next_char = $text[$i+2];

    if ($char eq "\n") { # a new line
      if ($heading_level) { # a heading was read and ends here
        my $heading_end_offset = $heading_type eq 'prefixed' ? $pure_text_offset : $pure_text_offset - 1; # "-1" means without a newline
        push(@markdown, "Heading$heading_level:$heading_start_offset:$heading_end_offset");
        mylog(0, "Storing a MarkDown Heading$heading_level mark: 'Heading$heading_level:$heading_start_offset:$heading_end_offset'\n");
        $heading_level = 0;
        $heading_type = '';
        $heading_start_offset = -1;
      }
      if ($underlined_heading) {
        # setting the previous line as the heading:
        my $underlined_heading_level = $underlined_heading eq '=' ? 1 : 2;
        push(@markdown, "Heading$underlined_heading_level:$prev_line_start_offset:$prev_line_end_offset");
        mylog(0, "Storing a MarkDown Heading$underlined_heading_level mark: 'Heading$underlined_heading_level:$prev_line_start_offset:$prev_line_end_offset'\n");
        $underlined_heading = '';
        $prev_line_start_offset = $line_start_offset;
        $prev_line_end_offset = $pure_text_offset;
        $line_start_offset = $pure_text_offset + 1; # after the newline
        $prev_char = $char;
        next; # this newline will not be put to the pure text (instead of one, there would be two now (with the newline after the heading))
      }
      $prev_line_start_offset = $line_start_offset;
      $prev_line_end_offset = $pure_text_offset;
      $line_start_offset = $pure_text_offset + 1; # after the newline
    }
    
    if ($underlined_heading) { # check if an underlined heading continues here
      if ($underlined_heading ne $char) {
        $underlined_heading = '';
        $underlined_heading_length = 0;
      }
      else {
        $underlined_heading_length++;
        $prev_char = $char;
        next;
      }
    }
    
    ################################
    # # Heading1 (marked by '# ')
    ################################
    # Check if Heading1 starts here (i.e., check if there is '# ' at the beginning of the line here)
    if ($prev_char eq "\n" and $char eq '#' and $next_char eq ' ') {
      mylog(0, "Found a Heading1 prefix mark '# '\n");
      $heading_start_offset = $pure_text_offset;
      $heading_level = 1;
      $heading_type = 'prefixed';
      $i+=1; # skip also the space
      $prev_char = ' ';
      next;
    }

    ################################
    # # Heading2 (marked by '## ')
    ################################
    # Check if Heading2 starts here (i.e., check if there is '## ' at the beginning of the line here)
    if ($prev_char eq "\n" and $char eq '#' and $next_char eq '#' and $next_next_char eq ' ') {
      mylog(0, "Found a Heading2 prefix mark '## '\n");
      $heading_start_offset = $pure_text_offset;
      $heading_level = 2;
      $heading_type = 'prefixed';
      $i+=2; # skip also the second '#' and the space
      $prev_char = ' ';
      next;
    }

    ################################
    # # Heading3 (marked by '### ')
    ################################
    # Check if Heading3 starts here (i.e., check if there is '### ' at the beginning of the line here)
    if ($prev_char eq "\n" and $char eq '#' and $next_char eq '#' and $next_next_char eq '#' and $text[$i+3] eq ' ') {
      mylog(0, "Found a Heading3 prefix mark '### '\n");
      $heading_start_offset = $pure_text_offset;
      $heading_level = 3;
      $heading_type = 'prefixed';
      $i+=3; # skip also the second and third '#' and the space
      $prev_char = ' ';
      next;
    }

    ################################
    # # Heading4 (marked by '#### ')
    ################################
    # Check if Heading4 starts here (i.e., check if there is '#### ' at the beginning of the line here)
    if ($prev_char eq "\n" and $char eq '#' and $next_char eq '#' and $next_next_char eq '#' and $text[$i+3] eq '#' and $text[$i+4] eq ' ') {
      mylog(0, "Found a Heading4 prefix mark '#### '\n");
      $heading_start_offset = $pure_text_offset;
      $heading_level = 4;
      $heading_type = 'prefixed';
      $i+=4; # skip also the second, third and fourth '#' and the space
      $prev_char = ' ';
      next;
    }

    ################################
    # # Heading5 (marked by '##### ')
    ################################
    # Check if Heading5 starts here (i.e., check if there is '##### ' at the beginning of the line here)
    if ($prev_char eq "\n" and $char eq '#' and $next_char eq '#' and $next_next_char eq '#' and $text[$i+3] eq '#' and $text[$i+4] eq '#' and $text[$i+5] eq ' ') {
      mylog(0, "Found a Heading5 prefix mark '##### '\n");
      $heading_start_offset = $pure_text_offset;
      $heading_level = 5;
      $heading_type = 'prefixed';
      $i+=5; # skip also the second, third, fourth and firfth '#' and the space
      $prev_char = ' ';
      next;
    }

    ################################
    # # Heading6 (marked by '###### ')
    ################################
    # Check if Heading6 starts here (i.e., check if there is '###### ' at the beginning of the line here)
    if ($prev_char eq "\n" and $char eq '#' and $next_char eq '#' and $next_next_char eq '#' and $text[$i+3] eq '#' and $text[$i+4] eq '#' and $text[$i+5] eq '#' and $text[$i+6] eq ' ') {
      mylog(0, "Found a Heading6 prefix mark '###### '\n");
      $heading_start_offset = $pure_text_offset;
      $heading_level = 6;
      $heading_type = 'prefixed';
      $i+=6; # skip also the second, third, fourth, fifth and sixth '#' and the space
      $prev_char = ' ';
      next;
    }
    
    ################################
    # Heading1
    # ========
    ################################
    # Check if Heading1 mark starts here (i.e., check if underlining by '=' starts here)
    if ($prev_char eq "\n" and $char eq '=') {
      $underlined_heading = '=';
      $underlined_heading_length = 1;
      $prev_char = $char;
      next;
    }
    
    ################################
    # Heading2
    # --------
    ################################
    # Check if Heading2 mark starts here (i.e., check if underlining by '-' starts here)
    if ($prev_char eq "\n" and $char eq '-') {
      $underlined_heading = '-';
      $underlined_heading_length = 1;
      $prev_char = $char;
      next;
    }

    ################################
    # **bold text** or __bold text__
    ################################
    # Search for a start or end bold ('**' or '__')
    if (($char eq '*' and $next_char eq '*' and $next_next_char ne '*')
     or ($char eq '_' and $next_char eq '_' and $next_next_char ne '_')) {
      # We have found '**' or '__', i.e. a start or an end of bold
      if ($bold_start_offset != -1) { # $bold_start_offset set, i.e. this mark is the end
        push(@markdown, "Bold:$bold_start_offset:$pure_text_offset");
        mylog(0, "Storing a MarkDown bold mark: 'Bold:$bold_start_offset:$pure_text_offset'\n");
        $bold_start_offset = -1;
      }
      else { # this is a start of bold
        $bold_start_offset = $pure_text_offset;  
      }
      $i+=1; # skip also the next character
      $prev_char = $next_char;
      next;
    }

    ################################
    # *italics text* or _italics text_
    ################################
    # Search for a start or end italics ('*' or '_')
    if (($char eq '*' and $next_char ne '*')
     or ($char eq '_' and $next_char ne '_')) {
      # We have found '*' or '_', i.e. a start or an end of italics
      if ($italics_start_offset != -1) { # $italics_start_offset set, i.e. this mark is the end
        push(@markdown, "Italics:$italics_start_offset:$pure_text_offset");
        mylog(0, "Storing a MarkDown italics mark: 'Italics:$italics_start_offset:$pure_text_offset'\n");
        $italics_start_offset = -1;
      }
      else { # this is a start of italics
        $italics_start_offset = $pure_text_offset;  
      }
      $prev_char = $char;
      next;
    }

    $pure_input_content .= $char;
    $pure_text_offset++;
    $prev_char = $char;
  }
  $input_content = $pure_input_content;
  mylog(0, "MarkDown preprocessing finished...\n");
  mylog(0, "MarkDown marks:\n" . join("\n", @markdown) . "\n");
  mylog(0, "$pure_input_content\n");
}

my $input_length = length($input_content);
mylog(2, "input length: $input_length characters\n");

if ($input_length > 40000) { # for the workshop presentation, avoid long texts
  # 'data' (in output-format)
  # 'stats' (in html)
  # 'app1_features' (in html)
  # 'app1_rule_info' (in json)
  # 'app2_colours' (in json)

  my $json_data = {
       data  => $input_content,
       stats => "<font color=\"red\">Příliš dlouhý text ($input_length znaků, povolené maximum je 40 tisíc)!</font>",
       app1_features => "<font color=\"red\">Příliš dlouhý text ($input_length znaků, povolené maximum je 40 tisíc)!</font>",
       app1_rule_info => "{}",
       app2_colours => "{}",
     };
  # Encode the Perl data structure into a JSON string
  my $json_string = encode_json($json_data);
  # Print the JSON string to STDOUT
  print $json_string;

  exit;
}

my $processing_time;
my $processing_time_udpipe;
my $processing_time_nametag;
my $processing_time_app1;
my $processing_time_app2;


############################################################################################
# Let us tokenize and segmet the file using UDPipe REST API with PDT-C 1.0 model
# This model is better for segmentation of texts with many dots in the middle of sentences.
############################################################################################

my $start_time_udpipe = [gettimeofday];

#my $conll_segmented = call_udpipe($input_content, 'segment');
my $conll_segmented = call_udpipe($input_content, 'cs', 'txt', 'all');

my $sentence_count = 0;
my $word_count = 0;

# Rozdělíme text na řádky
my @lines = split /\n/, $conll_segmented;

foreach my $line (@lines) {
    # Přeskočíme prázdné řádky a komentáře
    next if $line =~ /^\s*$/ || $line =~ /^#/;
    
    # Pokud řádek začíná číslem a tabulátorem, je to slovo
    if ($line =~ /^\d+\t/) {
        $word_count++;
    }
}

# Počet vět zjistíme podle prázdných řádků nebo komentářů # text
foreach my $line (@lines) {
    if ($line =~ /^# text =/) {
        $sentence_count++;
    }
}

mylog(2, "input length: $word_count tokens, $sentence_count sentences\n");

####################################################################################
# Let us parse the tokenized and segmented text using UDPipe REST API with UD model
# With this model I get UD trees and attributes.
####################################################################################

#my $conll_data = call_udpipe($conll_segmented, 'parse');
my $conll_data = $conll_segmented;

# Store the result to a file (just to have it, not needed for further processing)
#  open(OUT, '>:encoding(utf8)', "$input_file.conll") or die "Cannot open file '$input_file.conll' for writing: $!";
#  print OUT $conll_data;
#  close(OUT);

# Measure time spent by UDPipe 
my $end_time_udpipe = [gettimeofday];
$processing_time_udpipe = tv_interval($start_time_udpipe, $end_time_udpipe);


###################################################################################
# Now let us add info about named entities using NameTag REST API
###################################################################################

my $start_time_nametag = [gettimeofday];

my $conll_data_ne = call_nametag($conll_data);

# Store the result to a file (just to have it, not needed for further processing)
#  open(OUT, '>:encoding(utf8)', "$input_file.conllne") or die "Cannot open file '$input_file.conllne' for writing: $!";
#  print OUT $conll_data_ne;
#  close(OUT);

# Measure time spent by NameTag 
my $end_time_nametag = [gettimeofday];
$processing_time_nametag = tv_interval($start_time_nametag, $end_time_nametag);


###################################################################################
# Let us parse the CoNLL-U format into Tree::Simple tree structures (one tree per sentence)
###################################################################################

my @trees = parse_conllu($conll_data_ne);

# compile a hash pointing from an offset to a node that starts at that offset
my %start_offset2node = ();
foreach my $root (@trees) {
  foreach my $node (descendants($root)) {
    my $start = attr($node, 'start') // -1;
    $start_offset2node{$start} = $node;
  }
}

###############################################
# Now we have dependency trees of the sentences
###############################################

# print_log_header();

# variables for statistics
my $sentences_count = scalar(@trees);
my $tokens_count = 0;
foreach my $root (@trees) { # count number of tokens
  $tokens_count += scalar(descendants($root));
}


###############################################
# Let us put the parsed MarkDown info into the trees if needed
###############################################

# The markdown info is stored in array @markdown
# the format of these stored marks and links: e.g., "Bold:567:573", meaning the text between these
# two offset positions is bold
# Links from an offset to the node that starts at that offset are stored in %start_offset2node

if ($input_format eq 'md') {
  mylog(0, "Including MarkDown info into the trees...\n");

  foreach my $mark (@markdown) {
    my ($type, $start, $end) = split(':', $mark);
    mylog(0, "  - ($type, $start, $end)\n");
    
    if ($type =~ /^Heading(\d)$/) {
      my $heading_level = $1;
      my $heading_first_node = $start_offset2node{$start};
      if ($heading_first_node) {
        mylog(0, "    - found heading_first_node with form '" . attr($heading_first_node, 'form') . "'\n");
        my $heading_root = root($heading_first_node);
        set_property($heading_root, 'ponk', 'Heading', $heading_level);
      }
    }
    
    elsif ($type eq 'Bold') {
      for (my $i=$start; $i<$end; $i++) { # let us find all nodes between $start and $end and set the PonkBold misc property
        my $node = $start_offset2node{$i};
        if ($node) {
          set_property($node, 'misc', 'PonkBold', 1);
        }
      }
    }

    elsif ($type eq 'Italics') {
      for (my $i=$start; $i<$end; $i++) { # let us find all nodes between $start and $end and set the PonkItalics misc property
        my $node = $start_offset2node{$i};
        if ($node) {
          set_property($node, 'misc', 'PonkItalics', 1);
        }
      }
    }

  }

  mylog(0, "Finished including MarkDown info into the trees.\n");
}



##################################################################
##################################################################
# Let us process the parsed text (the actual PONK functionality)
##################################################################
##################################################################

# We call PONK-APP2 first because it messed up the output of PONK-APP1 (it randomly deleted comments with same "id" before sentences used to send info for automatic fixes).


#################################################
# Calling PONK-APP2
#################################################

my $start_time_app2 = [gettimeofday];

my ($app2_conllu, $app2_colours);

my $conll_for_ponk_app2 = get_output('conllu', $ui_language);

if ($apps =~ /\bapp2\b/) {
  ($app2_conllu, $app2_colours) = call_ponk_app2($conll_for_ponk_app2);
  # print STDERR "app2_colours: '$app2_colours'\n";
}
else {
  ($app2_conllu, $app2_colours) = ($conll_for_ponk_app2, {"APP2 Info" => "APP2 not called"});
}

# Measure time spent by ponk-app2 
my $end_time_app2 = [gettimeofday];
$processing_time_app2 = tv_interval($start_time_app2, $end_time_app2);

# Export the modified trees to a file (for debugging, not needed for further processing)
# open(OUT, '>:encoding(utf8)', "$input_file.export_app2.conllu") or die "Cannot open file '$input_file.export_app2.conllu' for writing: $!";
# print OUT $app2_conllu;
# close(OUT);


#################################################
# Calling PONK-APP1
#################################################

my $start_time_app1 = [gettimeofday];

my ($app1_conllu, $app1_metrics, $app1_metrics_info, $app1_rule_info_orig);

if ($apps =~ /\bapp1\b/) {
  ($app1_conllu, $app1_metrics, $app1_metrics_info, $app1_rule_info_orig) = call_ponk_app1($app2_conllu);
  # print STDERR "app1_rule_info_orig: '$app1_rule_info_orig'\n";
}
else {
  ($app1_conllu, $app1_metrics, $app1_metrics_info, $app1_rule_info_orig) = ($app2_conllu, [{"APP1 Info" => "APP1 not called"}], {"APP1 Info" => "APP1 not called"}, {"APP1 Info" => "APP1 not called"});
}

# Measure time spent by ponk-app1 
my $end_time_app1 = [gettimeofday];
$processing_time_app1 = tv_interval($start_time_app1, $end_time_app1);

# Export the modified trees to a file (for debugging, not needed for further processing)
# open(OUT, '>:encoding(utf8)', "$input_file.export_app1.conllu") or die "Cannot open file '$input_file.export_app1.conllu' for writing: $!";
# print OUT $app1_conllu;
# close(OUT);
# Export the metrics (for debugging, not needed for further processing)
# open(OUT, '>:encoding(utf8)', "$input_file.export_app1.metrics") or die "Cannot open file '$input_file.export_app1.metrics' for writing: $!";
# print OUT app1_metrics2string('txt', $app1_metrics, $app1_metrics_info);
# close(OUT);


################################################
# Parse the CoNLL-U from PONK-APP1 and PONK-APP2
################################################


@trees = parse_conllu($app1_conllu);


#####################################################
# The whole text has been processed, let us finish up
#####################################################

# print_log_tail();

# Measure time spent so far
my $end_time_total = [gettimeofday];
$processing_time = tv_interval($start_time, $end_time_total);

# calculate and format statistics and list of app1 features if needed
my $stats;
my $app1_features_html;
my $app1_rule_info_json;
my $app2_colours_json;

if ($store_statistics or $output_statistics) { # we need to calculate statistics
  $stats = get_stats_html();
  $app1_features_html = get_app1_features_html($ui_language);
  $app1_rule_info_json = get_app1_rule_info_json();
  $app2_colours_json = get_app2_colours_json();
}

# print the input text with marked sources in the selected output format to STDOUT
my $output = get_output($output_format, $ui_language);

if (!$output_statistics) { # statistics should not be a part of output
  print $output;
}
else { # statistics should be a part of output, i.e. output will be JSON with several items: 
 # 'data' (in output-format)
 # 'stats' (in html)
 # 'app1_features' (in html)
 # 'app1_rule_info' (in json)
 # 'app2_colours' (in json)
 
  my $json_data = {
       data  => $output,
       stats => $stats,
       app1_features => $app1_features_html,
       app1_rule_info => $app1_rule_info_json,
       app2_colours => $app2_colours_json,
     };
  # Encode the Perl data structure into a JSON string
  my $json_string = encode_json($json_data);
  # Print the JSON string to STDOUT
  print $json_string;
}

if ($store_format) { # log the anonymized text in the given format in a file
  $output = get_output($store_format, $ui_language) if $store_format ne $output_format;
  my $output_file = basename($input_file);
  open(OUT, '>:encoding(utf8)', "$script_dir/log/$output_file.$store_format") or die "Cannot open file '$script_dir/log/$output_file.$store_format' for writing: $!";
  print OUT $output;
  close(OUT);
}

################################################################
########################## FINISHED ############################
################################################################


=item get_NameTag_marks

Get a list of NameTag marks assigned to the given node; the return value is a string of the marks divided by '~'.
Fake marks are assigned for cases not recognized by NameTag:

ax - the first part (three digits) of a ZIP code
ay - the second part (two digits) of a ZIP code

nk - IČO
nl - DIČ

nm - land register number

nx - the first part (six digits) of a birth registration number
ny - the second part (four or three digits) of a birth registration number

ta - day of birth
tb - month of birth
tc - year of birth

ti - day of death
tj - month of death
tk - year of death

nr - agenda reference number (číslo jednací)

=cut

sub get_NameTag_marks {
  my $node = shift;
  my @values = get_NE_values($node);
  my $marks = join '~', @values;

  if (!$marks) {
    return undef;
  }
  return $marks;
}


=item 

NameTag offers these values:

NE containers

P - complex person names
T - complex time expressions
A - complex address expressions
C - complex bibliographic expressions

Types of NE

a - Numbers in addresses
ah - street numbers
at - phone/fax numbers
az - zip codes

g - Geographical names
gc - states
gh - hydronyms
gl - nature areas / objects
gq - urban parts
gr - territorial names
gs - streets, squares
gt - continents
gu - cities/towns
g_ - underspecified

i - Institutions
ia - conferences/contests
ic - cult./educ./scient. inst.
if - companies, concerns...
io - government/political inst.
i_ - underspecified

m - Media names
me - email address
mi - internet links
mn - periodical
ms - radio and TV stations

n - Number expressions
na - age
nb - vol./page/chap./sec./fig. numbers
nc - cardinal numbers
ni - itemizer
no - ordinal numbers
ns - sport score
n_ - underspecified

o - Artifact names
oa - cultural artifacts (books, movies)
oe - measure units
om - currency units
op - products
or - directives, norms
o_ - underspecified

p - Personal names
pc - inhabitant names
pd - (academic) titles
pf - first names
pm - second names
pp - relig./myth persons
ps - surnames
p_ - underspecified

t - Time expressions
td - days
tf - feasts
th - hours
tm - months
ty - years

=cut


=item get_NE_values

Returns an array of NameTag marks assigned to the given node in attribute misc

=cut

sub get_NE_values {
  my $node = shift;
  my $ne = misc_property($node, 'NE') // '';
  my @values = ();
  if ($ne) {
    @values = $ne =~ /([A-Za-z][a-z_]?)_[0-9]+/g; # get an array of the classes
  }
  return @values;
}



=item has_child_with_lemma

Checks if a lemma is among children

=cut

sub has_child_with_lemma {
  my ($node, $lemma) = @_;
  if (grep {attr($_, 'lemma') eq $lemma} $node->getAllChildren) {
    return 1;
  }
  return 0;
}



sub generate_app2_stylesheet {
    my ($haref_colours) = @_;

    # Kontrola, zda je vstup platná hash reference
    unless (ref($haref_colours) eq 'HASH') {
        mylog(2, "generate_app2_stylesheet: Expected a hash reference, received " . (ref($haref_colours) || 'scalar'));
        return '/* Error in stylesheet generation: Wrong input */';
    }

    # Vytvoření CSS pravidel
    my $css = '';
    while (my ($key, $background_color) = each %$haref_colours) {
        $css .= ".app2_class_$key { background-color: $background_color; }\n";
    }

    return $css;
}


=item get_output

Returns the processed input text in the given format (one of: txt, html, conllu).

=cut

sub get_output {
  my $format = shift;
  my $lang = shift;
  if (!$lang or $lang !~ /^(cs|en)$/) {
    $lang = 'cs';
  }

  my $output = '';

  # FILE HEADER
  
  if ($format eq 'html') {
    my $css = generate_app2_stylesheet($app2_colours);
    $output .= "<html>\n";
    $output .= <<END_OUTPUT_HEAD_START;
<head>
  <style>
END_OUTPUT_HEAD_START
    $output .= $css;
    $output .= <<END_OUTPUT_HEAD_END;
  </style>
</head>
END_OUTPUT_HEAD_END
    $output .= "<body>\n";
  }
  
  my $first_par = 1; # for paragraph separation in txt and html formats (first par in the file should not be separated)

  my $first_sent = 1; # for sentence separation in txt and html formats (first sentence in the file should not be separated)
  
  my $space_before = ''; # for storing info about SpaceAfter until the next token is printed
  
  my $html_sentence_element = ''; # it may be set, e.g., to h1 for level 1 headings

  my $result_token_id_number = 1; # marked tokens in the result text need to have ids (used in the client part)

  my $app1_lang = $lang;
  $app1_lang = 'cz' if $app1_lang eq 'cs'; # app1 uses 'cz'
  
  foreach my $root (@trees) {

    # PARAGRAPH SEPARATION (txt, html)
    if (attr($root, 'newpar') and $format =~ /^(txt|html)$/) {
      $first_sent = 1;
      if ($first_par) {
        $first_par = 0;
      }
      else {
        $output .= "</p>" if $format eq 'html';
        # $output .= "\n\n" if $format eq 'txt'; # maybe not needed since using SpacesAfter and SpacesBefore
      }
      
      $output .= "<p>" if $format eq 'html';
    }

    # check if this sentence is a heading
    my $sentence_ponk = attr($root, 'ponk') // '';
    if ($sentence_ponk =~ /Heading=(\d)/) { # a heading
      my $elem = $1;
      if ($format eq 'html') {
        $html_sentence_element = "h$elem";
      }
    }
    
    if ($format eq 'html' and $html_sentence_element) {
      $output .= "<$html_sentence_element>";
    }
    
    # SENTENCE HEADER (conllu)
    if ($format eq 'conllu') {
      $output .= attr($root, 'other_comment') // '';
      my $newdoc = attr($root, 'newdoc') // '';
      $output .= "$newdoc\n" if $newdoc;
      my $newpar = attr($root, 'newpar') // '';
      $output .= "$newpar\n" if $newpar;
      my $sent_id = attr($root, 'id') // '';
      $output .= "# sent_id = $sent_id\n" if $sent_id;
      my $ponk = attr($root, 'ponk') // '';
      $output .= "# ponk = $ponk\n" if $ponk;
      my $text = attr($root, 'text') // '';
      $output .= "# text = $text\n" if $text;
    }

    # assemble tokens to be added at each position if a fix button is clicked
    my %ord2add = (); 
    if ($format eq 'html') {
      my $other_comment = attr($root, 'other_comment') // '';
      # Rozdělení textové proměnné na řádky a zpracování řádku po řádce
      foreach my $line (split /\n/, $other_comment) {
        chomp $line;
        if ($line =~ /^# PonkApp1:([^:]+):([^:]+):add\s*=\s*(\{.*\})/) {
          my $ruleName = $1;      # Např. RuleTooLongExpressions
          my $applicationId = $2; # Např. fee552e8
          my $json_str = $3;      # JSON část

          eval {
              my $data = decode_json($json_str);
              my $addAfter = $data->{add_after}; # Např. "3"
              my $form = $data->{node}{form};    # Např. "Pokud"

              # Sestavení span tagu pomocí konkatenace
              my $span = '<span style="display: none" class="app1_class_' . $ruleName . '_' . $applicationId . '_add">' . " " . $form . '</span>';

              # Přidání do hashe ord2add pod klíčem $addAfter
              $ord2add{$addAfter} .= $span;
          };
          if ($@) {
              warn "Chyba při parsování JSON v řádku: $line\n$@";
          }
        }
      }
    }

    # PRINT THE SENTENCE TOKEN BY TOKEN
    my @nodes = sort {attr($a, 'ord') <=> attr($b, 'ord')} descendants($root);
    my $number_of_tokens = scalar(@nodes);

    my $stored_spaces_after_last_token = ''; # spaces after at the last token need to wait for, e.g., closing tag for a heading
    my $token_number = 0;

    my $bold_continuation = 0; # bold text continues from previous tokens (within a single sentence)
    my $italics_continuation = 0; # italics text continues from previous tokens (within a single sentence)


    foreach my $node (@nodes) {
    
      $token_number++;
    
      # COLLECT INFO ABOUT THE TOKEN
      my $form = attr($node, 'form');
      my $classes = get_NameTag_marks($node) // '';

      my $span_app1_start = ''; # for rules
      my $span_app1_end = '';

      my $span_app2_start = ''; # for lexical surprise
      my $span_app2_end = '';

      # take care of BOLD text
      my $bold_start = '';
      my $bold_end = '';

      my $is_bold = misc_property($node, 'PonkBold') // '';
      if ($bold_continuation and !$is_bold) { # end of bold before this token
        $bold_continuation = 0;
        if ($format eq 'html') {
          $bold_end = '</b>';
        }
      }
      elsif (!$bold_continuation and $is_bold) { # bold starts before this token
        $bold_continuation = 1;
        if ($format eq 'html') {
          $bold_start = '<b>';
        }
      }

      # take care of ITALICS text
      my $italics_start = '';
      my $italics_end = '';

      my $is_italics = misc_property($node, 'PonkItalics') // '';
      if ($italics_continuation and !$is_italics) { # end of italics before this token
        $italics_continuation = 0;
        if ($format eq 'html') {
          $italics_end = '</i>';
        }
      }
      elsif (!$italics_continuation and $is_italics) { # italics starts before this token
        $italics_continuation = 1;
        if ($format eq 'html') {
          $italics_start = '<i>';
        }
      }

      if ($format eq 'html') {

        # INFO FROM PONK-APP1
        #mylog(0, "Going to get app1 miscs for word '$form'\n");
        my @app1_miscs = grep {$_ !~ /:rebind=/} get_app1_miscs(attr($node, 'misc')); # array of misc values from ponk-app1
        if (@app1_miscs) {
          #my $span_class = 'highlighted-text-app1';
          my $span_class = '';
          my @rule_names = unify_array_keep_order( map {get_app1_rule_name($_)} @app1_miscs);
          foreach my $name (@rule_names) {
            $span_class .= " app1_class_$name";
          }
          # get tooltip:
          my $tooltip = "";
          my $fix_button = "";
          foreach my $app1_misc (@app1_miscs) {
            $tooltip .= "\n" if $tooltip;
            if ($app1_misc =~ /^PonkApp1:([^:]+):[^=]+=(.+)$/) {
              my $rule_name = $1;
              my $rule_name_lang = $app1_rule_info_orig->{$rule_name}->{$app1_lang . '_name'} // $rule_name;
              my $role_name = $2;
              my $role_name_lang = $app1_rule_info_orig->{$rule_name}->{$app1_lang . '_participants'}->{$role_name} // $role_name;
              # $rule_name_lang =~ s/object/predicate/; # a temporary fix for making a screenshot to a paper before info from app1 gets corrected
              if ($app1_misc !~ /:remove=/) {
                $tooltip .= "$rule_name_lang: $role_name_lang";
              }
              else { 
                if ($app1_misc =~ /:([^:]+):remove/) {
                  my $rule_application_id = $1;
                  $fix_button = ' data-tooltip-fix="app1_class_' . $rule_name . '_' . $rule_application_id . '"';
                  # e.g., app1_class_RuleTooLongExpressions_d59d3e8b
                }
              }
            }
          }
          my $id = 'app1_token_id_' . $result_token_id_number;
          $result_token_id_number++;

          if (scalar(grep {$_ !~ /:remove/} @app1_miscs) > 1) { # for now, let us fix only places with one rule
            $fix_button = "";
          }

          $span_class =~ s/^\s+//;
	  my $data_tooltip = $tooltip ? " data-tooltip=\"$tooltip\"" : ""; # do not print empty tooltip (happens at items to be removed and replaced, e.g., without a spaceafter (e.g., at 'až' in "až v případě, že" -> "až, pokud"))
	  $fix_button = '' if !$data_tooltip;
          $span_app1_start = "<span id=\"$id\" class=\"$span_class\" onmouseover=\"app1SpanHoverStart(this)\" onmouseout=\"app1SpanHoverEnd(this)\"$data_tooltip$fix_button>";
          $span_app1_end = '</span>';
        }
        
        # INFO FROM PONK-APP2
        my $lexical_surprise = misc_property($node, 'PonkApp2:Surprisal') // '';
        if ($lexical_surprise) {
          $span_app2_start = "<span class=\"app2_class_$lexical_surprise\">";
          $span_app2_end = '</span>';
        }
  
      }

      # PRINT THE TOKEN
      if ($format =~ /^(txt|html)$/) {
        my $SpaceAfter = misc_property($node, 'SpaceAfter') // '';
        my $SpacesAfter = misc_property($node, 'SpacesAfter') // ''; # newlines etc. in the original text
        my $SpacesBefore = misc_property($node, 'SpacesBefore') // ''; # newlines etc. in the original text; seems to be sometimes used with presegmented input

        # handle extra spaces and newlines in SpaceBefore (seems to be sometimes used with presegmented input)
        if ($SpacesBefore =~ /(\\s|\\r|\\n|\\t)/) { # SpacesBefore informs that there were newlines or extra spaces in the original text here
          if ($format eq 'html') {
            $SpacesBefore =~ s/\\r//g;
            while ($SpacesBefore =~ /\\s\\s/) {
              $SpacesBefore =~ s/\\s\\s/&nbsp; /;
            }
            $SpacesBefore =~ s/\\s/ /g;
            while ($SpacesBefore =~ /\\n\\n/) {
              $SpacesBefore =~ s/\\n\\n/<p><\/p>/;
            }
            $SpacesBefore =~ s/\\n/<br>/g;            
            $SpacesBefore =~ s/\\t/&nbsp; /g;
          }
          else { # txt
            $SpacesBefore =~ s/\\r/\r/g;
            $SpacesBefore =~ s/\\n/\n/g;
            $SpacesBefore =~ s/\\s/ /g;
            $SpacesBefore =~ s/\\t/  /g;
          }
          $output .= $SpacesBefore;          
        }

        $output .= "$italics_end$bold_end";

        # add automatic correction tokens that go before the current token; it must go here after $space_before is printed
        if ($format eq 'html') { 
          my $add_spans_sent_start = $ord2add{$token_number - 1} // '';
          if ($add_spans_sent_start) {
            $output .= $add_spans_sent_start;
          }
        }

        # Check if this is the first (or another) part of a multiword - use the original form and ignore the other parts
        my $multiword = attr($node, 'multiword');
        my $multiword_part = attr($node, 'multiword_part');
        if ($multiword) {
          my ($n_multi, $form_multi, $lemma_multi, $upos_multi, $xpos_multi, $feats_multi, $head_multi, $deprel_multi,
              $deps_multi, $misc_multi) = split (/\t/, $multiword);
          $form = $form_multi; # use the original multiword form
          if ($misc_multi =~ /SpaceAfter=No/) {
            $SpaceAfter = 'No'; # use SpaceAfter from the multiword line
          }
        }
        elsif ($multiword_part) { # if this is the second or a further part of a multiword - ignore
          next;
        }

        $output .= "$span_app1_start$span_app2_start$space_before$bold_start$italics_start$form$span_app2_end$span_app1_end";

        $space_before = ($SpaceAfter eq 'No' or $SpacesAfter) ? '' : ' '; # store info about a space until the next token is about to be printed
        
        # $output .= "\ndebug info: SpaceAfter='$SpacesAfter', space_before = '$space_before'\n";
        # handle extra spaces and newlines in SpaceAfter
        if ($SpacesAfter =~ /(\\s|\\r|\\n|\\t)/) { # SpacesAfter informs that there were newlines or extra spaces in the original text here
          if ($format eq 'html') {
            $SpacesAfter =~ s/\\r//g;
            while ($SpacesAfter =~ /\\s\\s/) {
              $SpacesAfter =~ s/\\s\\s/&nbsp; /;
            }
            $SpacesAfter =~ s/\\s/ /g;
            while ($SpacesAfter =~ /\\n\\n/) {
              $SpacesAfter =~ s/\\n\\n/<\/p><p>/;
            }
            $SpacesAfter =~ s/\\n/<br>/g;            
            $SpacesAfter =~ s/\\t/&nbsp; /g;
          }
          else { # txt
            $SpacesAfter =~ s/\\r/\r/g;
            $SpacesAfter =~ s/\\n/\n/g;
            $SpacesAfter =~ s/\\s/ /g;
            $SpacesAfter =~ s/\\t/  /g;
          }
        }
        if ($token_number eq $number_of_tokens) {
          $stored_spaces_after_last_token = $SpacesAfter;
        }
        else {
          $output .= $SpacesAfter;
        }
        
      }
      
      elsif ($format eq 'conllu') {
        my $ord = attr($node, 'ord') // '_';
        my $lemma = attr($node, 'lemma') // '_';
        my $deprel = attr($node, 'deprel') // '_';
        my $upostag = attr($node, 'upostag') // '_';
        my $xpostag = attr($node, 'xpostag') // '_';
        my $feats = attr($node, 'feats') // '_';
        my $deps = attr($node, 'deps') // '_';
        my $misc = attr($node, 'misc') // '_';

        my $head = attr($node, 'head') // '_';
        
        my $multiword = attr($node, 'multiword') // '';
        if ($multiword) {
          $output .= "$multiword\n";
        }
        
        $output .= "$ord\t$form\t$lemma\t$upostag\t$xpostag\t$feats\t$head\t$deprel\t$deps\t$misc\n";
      }

    }

    if ($format eq 'html' and $html_sentence_element) {
      $output .= "</$html_sentence_element>";
      $html_sentence_element = '';
    }
    
    if ($format =~ /^(html|txt)$/) {
      if ($stored_spaces_after_last_token) {
        $output .= $stored_spaces_after_last_token;
      }
    }

    # sentence separation in the conllu format needs to be here (also the last sentence should be ended with \n)
    if ($format eq 'conllu') {
      $output .= "\n"; # an empty line ends a sentence in the conllu format    
    }
    
  }
  
  # All sentences processed

  if ($format eq 'html') {
    $output .= "</p>";
    $output .= "</body>\n";
    $output .= "</html>\n";
  }

  return $output;
  
} # get_output


=item get_app1_miscs

Given the value of the misc attribute, return an array of values from ponk-app1

=cut

sub get_app1_miscs {
  my $misc = shift;
  # mylog(0, "get_app1_miscs: misc='$misc'\n");
  return undef if !$misc;
  my @miscs = split(/\|/, $misc);
  # mylog(0, "get_app1_miscs: found " . scalar(@miscs) . " misc values.\n");
  my @app1_miscs = grep {/^PonkApp1/} @miscs;
  # mylog(0, "get_app1_miscs: found " . scalar(@app1_miscs) . " ponk-app1 misc values.\n");
  return @app1_miscs;
}

=item get_app1_rule_name

Given one ponk-app1 value from misc, get the rule name and also the rule name together with a unique id of the occurrence; if the rule name also contains ":remove", it also returns the rule name together with the unique id and the "_remove" suffix (i.e., it returns two or three values).

=cut

sub get_app1_rule_name {
  my ($one_app1_misc_value) = @_;
  # mylog(0, "get_app1_rule_name: one app1 mist value: '$one_app1_misc_value'\n");
  if ($one_app1_misc_value =~ /^PonkApp1:([^:]+):([^:]+):remove=/) { # rule name and unique id of the occurrence, remove flag
    my $rule_name = $1;
    my $id = $2;
    # mylog(0, "get_app1_rule_name:   rule name: '$rule_name'\n");
    return ($rule_name, $rule_name . "_" . $id, $rule_name . "_" . $id . "_remove");
  }
  elsif ($one_app1_misc_value =~ /^PonkApp1:([^:]+):([^:]+)=/) { # rule name and unique id of the occurrence
    my $rule_name = $1;
    my $id = $2;
    # mylog(0, "get_app1_rule_name:   rule name: '$rule_name'\n");
    return ($rule_name, $rule_name . "_" . $id);
  }
  return undef;
}


sub unify_array_keep_order {
    my %seen;
    my @vysledek;
    
    for my $item (grep {defined} @_) {
        unless ($seen{$item}) {
            push @vysledek, $item;
            $seen{$item} = 1;
        }
    }
    
    return @vysledek;
}


=item get_app1_list_of_features

Given an array of trees, collect a list (an array of strings) of PonkApp1 features occurring there in attribute misc (i.e., a list of features from PonkApp1 that triggered in the given text).

=cut

sub get_app1_list_of_features {
  my (@trees) = @_;
  my %features = ();
  
  foreach my $root (@trees) {
    foreach my $node (descendants($root)) {
      my $misc = attr($node, 'misc') // '';
      my @app1_entries = get_app1_miscs($misc);
      foreach my $entry (@app1_entries) {
        if ($entry =~ /^PonkApp1:([^:]+):/) { # a feature found
          my $feature = $1;
          $features{$feature} = 1;
        }
      }
    }
  }
  mylog(0, "get_app1_list_of_features: " . join(', ', keys(%features)) . "\n");
  return keys(%features);
}


=item get_stats_html

Produces an html document with statistics about the process, using info from these variables:
$sentences_count;
$tokens_count;
$processing_time;
$processing_time_udpipe;
$processing_time_nametag;
$processing_time_app1;
$processing_time_app2;

=cut

sub get_stats_html {
  my $stats = "<html>\n";
  $stats .= <<END_HEAD;
<head>
  <style>
    h4 {
      margin-top: 2px;
      font-size: 1.3rem;
    }
    h5 {
      font-size: 1.2rem;
    }
    table {
      border-collapse: collapse;
    }
    table, th, td {
      border: 1px solid black;
    }
    th, td {
      text-align: left;
      padding-left: 2mm;
      padding-right: 2mm;
    }
    td:last-child {
      text-align: right;
      padding-right: 20px;
    }
  </style>
</head>
END_HEAD

  $stats .= "<body>\n";

  # Text-wide measures from APP1
  

  my $app1_string = app1_metrics2string('html', $app1_metrics, $app1_metrics_info);
  $stats .= "<p style=\"font-size: 0.9rem;\">$app1_string</p>";
  
 
  if ($ui_language eq 'cs') { 
    $stats .= "<h4 style=\"margin-top: 20px;\">PONK <span style=\"font-size: 1.1rem\">$VER_cs</span></h4>\n";
    $stats .= "<p style=\"font-size: 0.9rem; margin-bottom: 0px\"> &nbsp; - počet vět: $sentences_count, slov (vč. interp.): $tokens_count\n";
  }
  else {
    $stats .= "<h4 style=\"margin-top: 20px;\">PONK <span style=\"font-size: 1.1rem\">$VER_en</span></h4>\n";
    $stats .= "<p style=\"font-size: 0.9rem; margin-bottom: 0px\"> &nbsp; - number of sentences: $sentences_count, tokens: $tokens_count\n";
  }

  my $rounded_time = sprintf("%.1f", $processing_time);
  my $rounded_time_udpipe = sprintf("%.1f", $processing_time_udpipe);
  my $rounded_time_nametag = sprintf("%.1f", $processing_time_nametag);
  my $rounded_time_app1 = sprintf("%.1f", $processing_time_app1);
  my $rounded_time_app2 = sprintf("%.1f", $processing_time_app2);
  if ($ui_language eq 'cs') { 
    $stats .= "<p style=\"font-size: 0.9rem; margin-top: 5px; margin-bottom: 0px\">Doba zpracování: $rounded_time s</p>\n";
  }
  else {
    $stats .= "<p style=\"font-size: 0.9rem; margin-bottom: 0px\">Processing time: $rounded_time s</p>\n";
  }
  $stats .= "<p style=\"margin-top: 2px; line-height: 1; font-size: 0.9rem\"> &nbsp; - UDPipe: $rounded_time_udpipe s\n";
  $stats .= "<br/> &nbsp; - NameTag: $rounded_time_nametag s\n";
  if ($apps =~ /\bapp1\b/) {
    if ($ui_language eq 'cs') { 
      $stats .= "<br/> &nbsp; - Míry + Pravidla: $rounded_time_app1 s\n";
    }
    else {
      $stats .= "<br/> &nbsp; - Measures + Rules: $rounded_time_app1 s\n";
    }
  }
  if ($apps =~ /\bapp2\b/) {
    if ($ui_language eq 'cs') { 
      $stats .= "<br/> &nbsp; - Lexikální překvapení: $rounded_time_app2 s\n";
    }
    else {
      $stats .= "<br/> &nbsp; - Lexical surprise: $rounded_time_app2 s\n";
    }
  }
  $stats .= "<br/>&nbsp;</p>\n";

=item

  if ($ui_language eq 'cs') {
    $stats .= "$DESC_cs\n";
  }
  else {
    $stats .= "$DESC_en\n";
  }

=cut
  
  $stats .= "</body>\n";
  $stats .= "</html>\n";

  return $stats;
}


=item get_app1_features_html

In a given language ('cs' or 'en'), it produces an html document with a list of features from PonkApp1 used in the document.
It searches for the features that are actually found in the text in the global list @trees.
Information about the features is taken from global variable $app1_rule_info_orig, which contains a decoded JSON.

=cut

sub get_app1_features_html {
  my $lang = shift;
  if (!$lang or $lang !~ /^(cs|en)$/) {
    $lang = 'cs';
  }

  # get only rules actually found in the given text:
  my @app1_list_of_features = sort {$app1_rule_info_orig->{$a}->{order} <=> $app1_rule_info_orig->{$b}->{order}} get_app1_list_of_features(@trees);

  # compile the html response
  my $features = "<html>\n";
  $features .= <<END_HEAD;
<head>
  <style>
    h3 {
      margin-top: 5px;
    }
    table {
      border-collapse: collapse;
    }
    table, th, td {
      border: 1px solid black;
    }
    th, td {
      text-align: left;
      padding-left: 2mm;
      padding-right: 2mm;
    }
    td:last-child {
      text-align: right;
      padding-right: 20px;
    }
  </style>
</head>
END_HEAD

  $features .= "<body>\n";
  my $lang_code = $lang;
  $lang_code = 'cz' if $lang_code eq 'cs'; # app1 uses 'cz'  
  foreach my $feature (@app1_list_of_features) {
    my $name = $app1_rule_info_orig->{$feature}->{$lang_code . '_name'} // $feature;
    my $doc = $app1_rule_info_orig->{$feature}->{$lang_code . '_doc'} // '';
    $features .= "<div><label class=\"toggle-container\" data-tooltip=\"$doc\" onmouseover=\"app1RuleHoverStart(\'$feature\')\" onmouseout=\"app1RuleHoverEnd(\'$feature\')\">\n";
    $features .= "  <input checked type=\"checkbox\" id=\"check_app1_feature_" . $feature . "\" onchange=\"app1RuleCheckboxToggled(this.id)\">\n";
    $features .= "  <span class=\"checkmark app1_class_" . $feature . "\">$name</span>\n";
    $features .= "</label></div>\n";
  }

  $features .= "</body>\n";
  $features .= "</html>\n";

  return $features;
}



=item get_app2_colours_html

OBSOLETE, not used (instead, JSON is sent and html is created in javascript)
In a given language ('cs' or 'en'), it produces an html document with a list of colours from PonkApp2.
Information about the colours is taken from global variable $app2_colours, which contains a decoded JSON.


sub get_app2_colours_html {
  my $lang = shift;
  if (!$lang or $lang !~ /^(cs|en)$/) {
    $lang = 'cs';
  }

  # compile the html response
  my $colours = "<html>\n";
  $colours .= <<END_HEAD;
<head>
  <style>
    h3 {
      margin-top: 5px;
    }
    table {
      border-collapse: collapse;
    }
    table, th, td {
      border: 1px solid black;
    }
    th, td {
      text-align: left;
      padding-left: 2mm;
      padding-right: 2mm;
    }
    td:last-child {
      text-align: right;
      padding-right: 20px;
    }
  </style>
</head>
END_HEAD

  $colours .= "<body>\n";
  
  foreach my $surprise (sort {$a <=> $b} keys %$app2_colours) {
    my $colour = $app2_colours->{$surprise};
    $colours .= "<div style=\"width: 100%; background-color: $colour; text-align: center;\">\n";
    $colours .= "$surprise\n";
    $colours .= "</div>\n";
  }

  $colours .= "</body>\n";
  $colours .= "</html>\n";

  return $colours;
}

=cut


=item get_app1_rule_info_json

Returns a JSON string of a Perl hash with app1 rule info.

=cut

sub get_app1_rule_info_json {
  # Vytvoření JSON objektu
  my $json = JSON->new;

  # Konverze Perlového hashe na JSON string
  my $app1_rule_info_json = $json->encode($app1_rule_info_orig);

  return $app1_rule_info_json;
}


=item get_app2_colours_json

Returns a JSON string of a Perl hash with app2 colours.

=cut

sub get_app2_colours_json {
  # Vytvoření JSON objektu
  my $json = JSON->new;

  # Konverze Perlového hashe na JSON string
  my $app2_colours_json = $json->encode($app2_colours);

  return $app2_colours_json;
}


=item get_sentence

Given a range of text indexes (e.g. "124:129"), it returns the sentence to which the range belongs.

=cut

sub get_sentence {
  my $range = shift;
  if ($range =~ /^(\d+):(\d+)/) {
    my ($start, $end) = ($1, $2);
    foreach my $root (@trees) { # go through all sentences
      if (attr($root, 'start') <= $start and attr($root, 'end') >= $end) { # we found the tree
        return attr($root, 'text');
      }
    }
  }
  else {
    return 'N/A';
  }
}


# print children recursively
sub print_children {
    my ($node, $pre) = @_;
    my @children = $node->getAllChildren();
    foreach my $child (@children) {
        my $ord = attr($child, 'ord') // 'no_ord';
        my $form = attr($child, 'form') // 'no_form';
        mylog(0, "$ord$pre$form\n");
        print_children($child, $pre . "\t");
    }
}



######### CALLING PONK-APP1 #########

=item call_ponk_app1

Calling PONK-APP1 REST API; the text to be processed is passed in the argument in UD CONLL format
Returns an array of three members:
 - the text in UD CONLL format with additional info in misc
 - hashref of decoded JSON of measured metrics
 - hashref of decoded JSON of info on the metrics
 - hashref of decoded JSON with info how to display APP1 rules
If an error occurs, the function just returns the input conll text unchanged and twice a simple JSON with an error message.

=cut

sub call_ponk_app1 {
    my $conllu = shift;

    # Nastavení URL pro volání REST::API s parametry
    my $url = "$ponk_app1_service_url/raw?profile=noninstitutional_corrective";
    mylog(2, "Call PONK-APP1: URL=$url\n");

    my $ua = LWP::UserAgent->new;

    # Převedení řetězce na bajty
    my $conllu_bytes = encode("UTF-8", $conllu);

    # Vytvoření POST požadavku s obsahem z proměnné $conllu_bytes
    my $request = POST $url,
        Content_Type => 'form-data',
        Content => [
          file => [
            undef,                  # undef znamená, že LWP::UserAgent vygeneruje název souboru
            'data.conllu',     # Jméno souboru na straně serveru - bez toho to nefunguje
            Content => $conllu_bytes     # Obsah souboru
          ],
	  # profile => 'noninstitutional'  # Not working
        ];

    # Odeslání požadavku
    my $res = $ua->request($request);

    # Zkontrolování, zda byla odpověď úspěšná
    if ($res->is_success) {
        # Získání odpovědi v JSON formátu
        my $json_response = decode_json($res->content);
        # Zpracování odpovědi
        my $modified_conllu = $json_response->{'modified_conllu'};
        my $metrics_json = $json_response->{'metrics'};
	my $metrics_info_json = $json_response->{'metric_info'};
        my $rules_info_json = $json_response->{'rule_info'};
	# my $conflict_background_color = $json_response->{'conflict_background_color'}; # asi ji napíšu natvrdo do klienta
	# mylog(0, "PONK-APP1 JSON response:\n" . Dumper($json_response) . "\n");
        mylog(2, "Call PONK-APP1: Success.\n");
        return ($modified_conllu, $metrics_json, $metrics_info_json, $rules_info_json);
    } else {
        mylog(2, "call_ponk_app1: URL: $url\n");
        mylog(2, "call_ponk_app1: Error: " . $res->status_line . "\n");
        return ($conllu, [{"APP1 Error" => $res->status_line}], {"APP1 Error" => $res->status_line}, {"APP1 Error" => $res->status_line}); 
    }

}




=item get_interval

Based on the given info and value, it returns the interval the value belongs to. The info may look like:
      "intrevals": {
        "bad": [
          null,
          0.3940104681019158
        ],
        "medium": [
          0.3940104681019158,
          0.4496595967530767
        ],
        "good": [
          0.4496595967530767,
          null
        ]
      }
Hope the authors will fix the intrevals typo...

=cut

sub get_interval {
    my ($info, $value) = @_;

    # Reference to intervals
    my $intervals = $info->{intervals} // $info->{intrevals};
    return undef if !$intervals;

    # Determine if higher values are worse
    my $bad_upper = $intervals->{bad}->[1];
    my $good_upper = $intervals->{good}->[1];
    my $is_higher_worse = 0;  # Default: higher values are better

    if (defined $bad_upper && defined $good_upper) {
        $is_higher_worse = $bad_upper > $good_upper ? 1 : 0;
    }
    elsif (!defined $bad_upper && defined $good_upper) {
        $is_higher_worse = 1;
    }
    elsif (defined $bad_upper && !defined $good_upper) {
        $is_higher_worse = 0;
    }
    elsif (!defined $bad_upper && !defined $good_upper) {
        my $bad_lower = $intervals->{bad}->[0];
        my $good_lower = $intervals->{good}->[0];
        if (defined $bad_lower && defined $good_lower) {
            $is_higher_worse = $bad_lower > $good_lower ? 1 : 0;
        }
    }

    # print STDERR "bad_upper: ", (defined $bad_upper ? $bad_upper : "undef"), ", good_upper: ", (defined $good_upper ? $good_upper : "undef"), ", is_higher_worse: $is_higher_worse\n";

    # Check intervals
    for my $category (qw/bad medium good/) {
        my ($lower, $upper) = @{$intervals->{$category}};

        # Convert null to unbounded limits based on orientation
        $lower = defined $lower ? $lower : ($is_higher_worse ? -1e308 : -1e308);
        $upper = defined $upper ? $upper : ($is_higher_worse ? 1e308 : 1e308);

        # Check if $value falls within the interval
        if ($value >= $lower && $value <= $upper) {
            return $category;
        }
    }

    return undef; # Value doesn't fall into any interval
}



=item app1_metrics2string

Given a format (html or txt)
and a decoded JSON with metrics from app1 (ref to array of hashes)
and a decoded JSON with info about the metrics,
produce a string to display (in language given by global $ui_language)

=cut

sub app1_metrics2string {
  my ($format, $refar_metrics, $refha_metrics_info) = @_;
  my $text = '';
  foreach my $metric (@$refar_metrics) {
    my %h_metric = %$metric;
    foreach my $name (sort {$refha_metrics_info->{$a}->{order} <=> $refha_metrics_info->{$b}->{order}} keys %h_metric) {
      my $value = $h_metric{$name} // '';
      if (looks_like_number($value)) {
        $value = round($value * 100) / 100;
      }
      my $info = $refha_metrics_info->{$name};
      my $doc = '';
      my $hint = '';
      if ($info) {
        $name = $ui_language eq 'cs' ? ($info->{cz_name} // $name) : ($info->{en_name} // $name);
	$doc = $ui_language eq 'cs' ? ($info->{cz_doc} // $name) : ($info->{en_doc} // $name);
	$doc =~ s/\"/&quot;/g;
	$hint = $ui_language eq 'cs' ? ($info->{cz_hint} // '') : ($info->{en_hint} // '');
	$hint =~ s/\"/&quot;/g;
      }
      my $tooltip = $doc;
      my $interval = get_interval($info, $value);
      if ($interval and ($interval eq 'bad' or $interval eq 'medium')) {
        $tooltip .= "<br>$hint" if $hint;
      }

      my $bg_colour = "#dff0d8";
      $bg_colour = "#ffe097" if ($interval and $interval eq 'medium');
      $bg_colour = "#ffa097" if ($interval and $interval eq 'bad');

      if ($format eq 'html') {
        $text .= " &nbsp;<span style=\"background-color: $bg_colour\" data-tooltip=\"$tooltip\"> - $name: $value</span><br/>\n";
      }
      else { # txt
        $text .= "$name: $value\n";
      }
    }
  }
  return $text;
}


################################################

sub convertSTDINFromDocx { # for reading binary docx file from STDIN (used if ponk is run from command line)
    binmode STDIN;
    # Načtení binárního docx ze stdin
    local $/ = undef;

    # Načtení celého STDIN do proměnné
    my $word_document = <STDIN>;

    my $converted_to_md = convertFromDocx($word_document);
    
    return $converted_to_md;
}

sub convertSTDINFromDocxBase64 { # for reading docx file encoded in Base64 from STDIN (used internally in communication via API server)

    # Načtení docx kódovaného v Base64 ze stdin
    my $base64_data = do {
      local $/; # Nastavení náhrady konce řádku na undef, čímž načte celý obsah
      <STDIN>;
    };

    my $word_document = decode_base64($base64_data); # nyní mám původní binární podobu docx

    my $converted_to_md = convertFromDocx($word_document);
    
    return $converted_to_md;
}
    
sub convertFromDocx { # converting binary docx file do MarkDown
    my $docx_binary = shift;

    # Spuštění programu pandoc s předáním parametrů a standardního vstupu
    my @cmd = ('/usr/bin/pandoc',
               '-f', 'docx',
               '-t', 'markdown'); # Nastavit výstup na standardní výstup);
    my $result;
    run \@cmd, \$docx_binary, \$result;

    # Převedení výsledku do UTF-8
    $result = decode('UTF-8', $result);

=item

    $soubor = '/home/mirovsky/pokus2.md';
    open my $soubor_handle, '>:utf8', $soubor or die "Nelze otevřít soubor '$soubor' pro zápis: $!";
    print $soubor_handle $result;
    close $soubor_handle;

=cut

    return $result;
}


######### CALLING PONK-APP2 #########

=item call_ponk_app2

Calling PONK-APP2 REST API; the text to be processed is passed in the argument in UD CONLL format
Returns an array of two members:
 - the text in UD CONLL format with additional info in misc
 - hashref of decoded JSON with info how to display APP2 results
If an error occurs, the function just returns the input conll text unchanged and a simple JSON with an error message.

=cut

sub call_ponk_app2 {
    my $conllu = shift;

    # Nastavení URL pro volání REST::API s parametry
    my $url = "$ponk_app2_service_url/process-conllu";
    mylog(2, "Call PONK-APP2: URL=$url\n");

    my $ua = LWP::UserAgent->new;

    # Převedení řetězce na bajty
    my $conllu_bytes = encode("UTF-8", $conllu);

    # Vytvoření POST požadavku s obsahem jako surový text
    my $request = HTTP::Request->new(POST => $url);
    $request->header('Content-Type' => 'text/plain; charset=UTF-8');
    $request->content($conllu_bytes);

=item

    # Vytvoření POST požadavku s obsahem z proměnné $conllu_bytes
    my $request = POST $url,
        Content_Type => 'form-data',
        Content => [
          file => [
            undef,                  # undef znamená, že LWP::UserAgent vygeneruje název souboru
            'data.conllu',     # Jméno souboru na straně serveru - bez toho to nefunguje
            Content => $conllu_bytes     # Obsah souboru
          ]
        ];

=cut

    # Odeslání požadavku
    my $res = $ua->request($request);

    # Zkontrolování, zda byla odpověď úspěšná
    if ($res->is_success) {
        # Získání odpovědi v JSON formátu
        my $json_response = decode_json($res->content);
        # Zpracování odpovědi
        my $modified_conllu = $json_response->{'result'};
        my $colors_json = $json_response->{'colors'};
        # mylog(0, "PONK-APP2 JSON response:\n" . Dumper($json_response) . "\n");
        mylog(2, "Call PONK-APP2: Success.\n");
        return ($modified_conllu, $colors_json);
    } else {
        mylog(2, "call_ponk_app2: URL: $url\n");
        mylog(2, "call_ponk_app2: Error: " . $res->status_line . "\n");
        return ($conllu, {"APP2 Error" => $res->status_line}); 
    }

}
