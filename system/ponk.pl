#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use LWP::UserAgent;
use URI::Escape;
use JSON;
use Tree::Simple;
use List::Util qw(min max);
use Getopt::Long; # reading arguments
use POSIX qw(strftime); # naming a file with date and time
use File::Basename;
use Time::HiRes qw(gettimeofday tv_interval); # to measure how long the program ran
use Sys::Hostname;
use IPC::Run qw(run);
use MIME::Base64;
use Encode;


# STDIN and STDOUT in UTF-8
binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my $start_time = [gettimeofday];

my $VER = '0.01 20240327'; # version of the program

my @features = ('nothing yet');

my $FEATS = join(' • ', @features); 

my $DESC = "<h4>Features in this PONK version:</h4>\n<ul>\n";

foreach my $feature (@features) {
  $DESC .= "<li>$feature\n";
}

$DESC .= <<END_DESC;
</ul>
<h4>Planned features:</h4>
<ul>
<li>TO-DO
</ul>
END_DESC

my $log_level = 0; # limited (0=full, 1=limited, 2=anonymous)

my $udpipe_service_url = 'http://lindat.mff.cuni.cz/services/udpipe/api';
my $nametag_service_url = 'http://lindat.mff.cuni.cz/services/nametag/api';
my $hostname = hostname;
if ($hostname eq 'ponk') { # if running at this server, use versions of udpipe and nametag that do not log texts
  $udpipe_service_url = 'http://udpipe:11001';
  $nametag_service_url = 'http://udpipe:11002';
  $VER .= ' (no text logging)';
  $log_level = 2; # anonymous
}

#############################
# Colours for html

my $color_highlight_general = 'darkred'; # general highlighting colour


#######################################


# default output format
my $OUTPUT_FORMAT_DEFAULT = 'txt';
# default input format
my $INPUT_FORMAT_DEFAULT = 'txt';
# default replacements file name

# variables for arguments
my $input_file;
my $stdin;
my $input_format;
my $output_format;
my $diff;
my $add_NE;
my $output_statistics;
my $store_format;
my $store_statistics;
my $version;
my $info;
my $help;

# getting the arguements
GetOptions(
    'i|input-file=s'         => \$input_file, # the name of the input file
    'si|stdin'               => \$stdin, # should the input be read from STDIN?
    'if|input-format=s'      => \$input_format, # input format, possible values: txt, md, docx
    'of|output-format=s'     => \$output_format, # output format, possible values: txt, html, conllu
    'd|diff'                 => \$diff, # display the original expressions next to the anonymized versions
    'ne|named-entities=s'    => \$add_NE, # add named entities as marked by NameTag (1: to the anonymized versions, 2: to all recognized tokens)
    'os|output-statistics'   => \$output_statistics, # adds statistics to the output; if present, output is JSON with two items: data (in output-format) and stats (in HTML)
    'sf|store-format=s'      => \$store_format, # log the result in the given format: txt, html, conllu
    'ss|store-statistics'    => \$store_statistics, # should statistics be logged as an HTML file?
    'v|version'              => \$version, # print the version of the program and exit
    'n|info'                 => \$info, # print the info (program version and supported features) as JSON and exit
    'h|help'                 => \$help, # print a short help and exit
);


my $script_path = $0;  # Získá název spuštěného skriptu s cestou
my $script_dir = dirname($script_path);  # Získá pouze adresář ze získané cesty


if ($version) {
  print "PONK version $VER.\n";
  exit 0;
}

if ($info) {
  my $json_data = {
       version  => $VER,
       features => $FEATS,
     };
  # Encode the Perl data structure into a JSON string
  my $json_string = encode_json($json_data);
  # Print the JSON string to STDOUT
  print $json_string;
  exit 0;
}

if ($help) {
  print "PONK version $VER.\n";
  my $text = <<'END_TEXT';
Usage: maskit.pl [options]
options:  -i|--input-file [input text file name]
         -si|--stdin (input text provided via stdin)
         -if|--input-format [input format: txt (default), md, docx]
         -of|--output-format [output format: txt (default), html, conllu]
          -d|--diff (display the original expressions next to the anonymized versions)
         -ne|--named-entities [scope: 1 - add NameTag marks to the anonymized versions, 2 - to all recognized tokens]
         -os|--output-statistics (add PONK statistics to output; if present, output is JSON with two items: data (in output-format) and stats (in HTML))
         -sf|--store-format [format: log the output in the given format: txt, html, conllu]
         -ss|--store-statistics (log statistics to an HTML file)
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

mylog(2, "\n####################################################################\n");
mylog(2, "PONK $VER\n");

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
elsif ($input_format !~ /^(txt|md|docx)$/) {
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
elsif ($output_format !~ /^(txt|html|conllu)$/) {
  mylog(0, " - output format: unknown ($output_format), set to default $OUTPUT_FORMAT_DEFAULT\n");
  $output_format = $OUTPUT_FORMAT_DEFAULT;
}
else {
  mylog(0, " - output format: $output_format\n");
}

if ($diff) {
  mylog(0, " - display the original expressions next to the anonymized versions\n");
}

if ($add_NE) {
  if ($add_NE == 1) {
    mylog(0, " - add named entities as marked by NameTag to the anonymized versions\n");
  }
  elsif ($add_NE == 2) {
    mylog(0, " - add named entities as marked by NameTag to all recognized tokens\n");  
  }
  else {
    mylog(0, " - unknown value of -ne/--named-entities parameter ($add_NE); no NameTag marks will be printed\n");    
  }
}

if ($output_statistics) {
  mylog(0, " - add PONK statistics to the output; output will be JSON with two items: data (in $output_format) and stats (in HTML)\n");
}

$store_format = lc($store_format) if $store_format;
if ($store_format) {
  if ($store_format =~ /^(txt|html|conllu)$/) {
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

mylog(0, "\n");


###################################################################################
# Now let us read the text file that should be processed
###################################################################################

my $input_content;

if ($stdin) { # the input text should be read from STDIN

  mylog(2, "reading from stdin, input_format=$input_format\n");
  if ($input_format eq 'docx') {
    $input_content = convertFromDocx();
    #mylog(2, "input converted from docx: '$input_content'\n");
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

} elsif ($input_file) { # the input text should be read from a file
  open my $file_handle, '<:encoding(utf8)', $input_file
    or die "Cannot open file '$input_file' for reading: $!";

  $input_content = do { local $/; <$file_handle> }; # reading the file into a variable
  close $file_handle;

} else {
  mylog(2, "No input to process! Exiting!\n");
  exit -1;
}

mylog(2, "input file: $input_file\n");

# mylog(0, $input_content);



############################################################################################
# Let us parse the MarkDown (if needed) and remove the marks from the text
############################################################################################

my @markdown = (); # to store recognized (and removed) markdown marks with offset links to $pure_input_content
# the format of these stored marks and links: e.g., "Bold:567:573", meaning the text between these
# two offset positions is bold

if ($input_format eq 'md') {
  mylog(0, "Preprocessing MarkDown text...\n");
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
  my $prev_char = '\n'; # for, e.g., recognizing a new line; at the beginning, let us pretend that the prev. char was a newline

  my $heading_start_offset = -1;
  my $heading_level = 0;
  my $heading_type = '';
  
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
        $heading_start_offset = -1
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



############################################################################################
# Let us tokenize and segmet the file using UDPipe REST API with PDT-C 1.0 model
# This model is better for segmentation of texts with many dots in the middle of sentences.
############################################################################################

my $conll_segmented = call_udpipe($input_content, 'segment');



####################################################################################
# Let us parse the tokenized and segmented text using UDPipe REST API with UD model
# With this model I get UD trees and attributes.
####################################################################################

my $conll_data = call_udpipe($conll_segmented, 'parse');

# Store the result to a file (just to have it, not needed for further processing)
#  open(OUT, '>:encoding(utf8)', "$input_file.conll") or die "Cannot open file '$input_file.conll' for writing: $!";
#  print OUT $conll_data;
#  close(OUT);



###################################################################################
# Now let us add info about named entities using NameTag REST API
###################################################################################

my $conll_data_ne = call_nametag($conll_data);

# Store the result to a file (just to have it, not needed for further processing)
#  open(OUT, '>:encoding(utf8)', "$input_file.conllne") or die "Cannot open file '$input_file.conllne' for writing: $!";
#  print OUT $conll_data_ne;
#  close(OUT);



###################################################################################
# Let us parse the CONLL format into Tree::Simple tree structures (one tree per sentence)
###################################################################################

my @lines = split("\n", $conll_data_ne);

my @trees = (); # array of trees in the document

my $root; # a single root

my $min_start = 10000; # from indexes of the tokens, we will get indexes of the sentence
my $max_end = 0;

my $multiword = ''; # store a multiword line to keep with the following token

# the following cycle for reading UD CONLL is modified from Jan Štěpánek's UD TrEd extension
foreach my $line (@lines) {
    chomp($line);
    #mylog(0, "Line: $line\n");
    if ($line =~ /^#/ && !$root) {
        $root = Tree::Simple->new({}, Tree::Simple->ROOT);
        #mylog(0, "Beginning of a new sentence!\n");
    }

    if ($line =~ /^#\s*newdoc/) { # newdoc
        set_attr($root, 'newdoc', $line); # store the whole line incl. e.g. id = ...
    } elsif ($line =~ /^#\s*newpar/) { # newpar
        set_attr($root, 'newpar', $line); # store the whole line incl. e.g. id = ...
    } elsif ($line =~ /^#\s*sent_id\s=\s*(\S+)/) {
        my $sent_id = $1; # substr $sent_id, 0, 0, 'PML-' if $sent_id =~ /^(?:[0-9]|PML-)/;
        set_attr($root, 'id', $sent_id);
    } elsif ($line =~ /^#\s*text\s*=\s*(.*)/) {
        set_attr($root, 'text', $1);
        #mylog(0, "Reading sentence '$1'\n");
    } elsif ($line =~ /^#\s*ponk\s*=\s*(.*)/) {
        set_attr($root, 'ponk', $1);
        #mylog(0, "Ponk properties of the sentence: '$1'\n");
    } elsif ($line =~ /^#/) { # other comment, store it as well (all other comments in one attribute other_comment with newlines included)
        my $other_comment_so_far = attr($root, 'other_comment') // '';
        set_attr($root, 'other_comment', $other_comment_so_far . $line . "\n");
        
    } elsif ($line =~ /^$/) { # empty line, i.e. end of a sentence
        _create_structure($root);
        set_attr($root, 'start', $min_start);
        set_attr($root, 'end', $max_end);
        $min_start = $min_start = 10000;
        $max_end = 0;
        push(@trees, $root);
        #mylog(0, "End of sentence id='" . attr($root, 'id') . "'.\n\n");
        $root = undef;

    } else { # a token
        my ($n, $form, $lemma, $upos, $xpos, $feats, $head, $deprel,
            $deps, $misc) = split (/\t/, $line);
        $_ eq '_' and undef $_
            for $xpos, $feats, $deps, $misc;

        # $misc = 'Treex::PML::Factory'->createList( [ split /\|/, ($misc // "") ]);
        #if ($n =~ /-/) {
        #    _create_multiword($n, $root, $misc, $form);
        #    next
        #}
        if ($n =~ /-/) { # a multiword line, store it to keep with the next token
          $multiword = $line;
          next;
        }
        
        #$feats = _create_feats($feats);
        #$deps = [ map {
        #    my ($parent, $func) = split /:/;
        #    'Treex::PML::Factory'->createContainer($parent,
        #                                            {func => $func});
        #} split /\|/, ($deps // "") ];

        my $node = Tree::Simple->new({});
        set_attr($node, 'ord', $n);
        set_attr($node, 'form', $form);
        set_attr($node, 'lemma', $lemma);
        set_attr($node, 'deprel', $deprel);
        set_attr($node, 'upostag', $upos);
        set_attr($node, 'xpostag', $xpos);
        set_attr($node, 'feats', $feats);
        set_attr($node, 'deps', $deps); # 'Treex::PML::Factory'->createList($deps),
        set_attr($node, 'misc', $misc);
        set_attr($node, 'head', $head);
        
        if ($multiword) { # the previous line was a multiword, store it at the current token
          set_attr($node, 'multiword', $multiword);
          $multiword = '';
        }
        
        if ($misc and $misc =~ /TokenRange=(\d+):(\d+)\b/) {
          my ($start, $end) = ($1, $2);
          set_attr($node, 'start', $start);
          set_attr($node, 'end', $end);
          $min_start = $start if $start < $min_start;
          $max_end = $end if $end > $max_end;          
        }
        
        $root->addChild($node);
        
    }
}
# If there wasn't an empty line at the end of the file, we need to process the last tree here:
if ($root) {
    _create_structure($root);
    set_attr($root, 'start', $min_start);
    set_attr($root, 'end', $max_end);
    push(@trees, $root);
    #mylog(0, "End of sentence id='" . attr($root, 'id') . "'.\n\n");
    $root = undef;
    #warn "Emtpy line missing at the end of input\n";
}
# end of Jan Štěpánek's modified cycle for reading UD CONLL


###############################################
# Now we have dependency trees of the sentences
###############################################

my $processing_time;
# print_log_header();

# variables for statistics
my $sentences_count = scalar(@trees);
my $tokens_count = 0;
foreach my $root (@trees) { # count number of tokens
  $tokens_count += scalar(descendants($root));
}

###############################################
# Let us process MarkDown info if present
###############################################

if ($input_format eq 'md') {

  my $inside_bold = 0;
  
  foreach my $root (@trees) {
    mylog(1, "\n====================================================================\n");
    mylog(1, "Sentence id=" . attr($root, 'id') . ": " . attr($root, 'text') . "\n");
    # print_children($root, "\t");

    my @all_nodes_ord_sorted = sort {attr($a, 'ord') <=> attr($b, 'ord')} descendants($root);
    my $sentence_length = scalar(@all_nodes_ord_sorted);

    ################################
    # MainHeading
    # ============
    ################################
    # Check if the sentence is a main heading (i.e., check if there are some equal marks at the end of the sentence
    my @end_equal_marks = ();
    my @nodes_copy = @all_nodes_ord_sorted;
    while (scalar(@nodes_copy) and attr($nodes_copy[-1], 'form') eq '=') {
      push (@end_equal_marks, pop(@nodes_copy));
    }
    if (scalar(@end_equal_marks) > 2) { # let us say that we need at least three equal marks
      mylog(0, "Found a main heading marked by a sequence of '='\n");
      set_property($root, 'ponk', 'MainHeading', 1);
    }
      
    ################################
    # Heading
    # -------
    ################################
    # Check if the sentence is a heading (i.e., check if there are some dashes at the end of the sentence
    my @end_dashes = ();
    my @nodes_copy = @all_nodes_ord_sorted;
    while (scalar(@nodes_copy) and attr($nodes_copy[-1], 'form') eq '-') {
      push (@end_dashes, pop(@nodes_copy));
    }
    if (scalar(@end_dashes) > 2) { # let us say that we need at least three dashes
      mylog(0, "Found a heading marked by a sequence of '-'\n");
      set_property($root, 'ponk', 'Heading', 1);
    }

    ################################
    # ## Heading (marked by '##')
    ################################
    # Check if the sentence is a heading (i.e., check if there is '## ' at the beginning)
    if ($sentence_length > 2) {
      if (attr($all_nodes_ord_sorted[0], 'form') eq '#') { # the first token is '#'
        my $SpaceAfter = get_property($all_nodes_ord_sorted[0], 'misc', 'SpaceAfter') // 'Yes';
        if ($SpaceAfter eq 'No') {
          if (attr($all_nodes_ord_sorted[1], 'form') eq '#') { # the second token is '#'
            $SpaceAfter = get_property($all_nodes_ord_sorted[1], 'misc', 'SpaceAfter') // 'Yes';
            if ($SpaceAfter eq 'Yes') {
              mylog(0, "Found a heading marked by a '##' prefix\n");
              set_property($root, 'ponk', 'Heading', 1);
            }
          }
        }
      }
    }

    ################################
    # ### SmallHeading (marked by '###')
    ################################
    # Check if the sentence is a small heading (i.e., check if there is '### ' at the beginning)
    if ($sentence_length > 3) {
      if (attr($all_nodes_ord_sorted[0], 'form') eq '#') { # the first token is '#'
        my $SpaceAfter = get_property($all_nodes_ord_sorted[0], 'misc', 'SpaceAfter') // 'Yes';
        if ($SpaceAfter eq 'No') {
          if (attr($all_nodes_ord_sorted[1], 'form') eq '#') { # the second token is '#'
            $SpaceAfter = get_property($all_nodes_ord_sorted[1], 'misc', 'SpaceAfter') // 'Yes';
            if ($SpaceAfter eq 'No') {
              if (attr($all_nodes_ord_sorted[2], 'form') eq '#') { # the third token is '#'
                $SpaceAfter = get_property($all_nodes_ord_sorted[2], 'misc', 'SpaceAfter') // 'Yes';
                if ($SpaceAfter eq 'Yes') {
                  mylog(0, "Found a small heading marked by a '###' prefix\n");
                  set_property($root, 'ponk', 'SmallHeading', 1);
                }
              }
            }
          }
        }
      }
    }

    # Now let us go through individual tokens
    
    for(my $i=0; $i<$sentence_length; $i++) {
      my $node = $all_nodes_ord_sorted[$i];

      my $form = attr($node, 'form') // '';
      my $lemma = attr($node, 'lemma') // '';
      #my $tag = attr($node, 'xpostag') // '';
      #my $feats = attr($node, 'feats') // '';
      #my $classes = get_NameTag_marks($node) // '';

      mylog(0, "\nProcessing form '$form' (lemma '$lemma')\n");
      #mylog(0, "\nProcessing form '$form' (lemma '$lemma') with NameTag classes '$classes' and feats '$feats'\n");

=item

      ################################
      # **bold text**
      ################################
      # Search for a start or end bold ('**')
      if ($form eq '*') {
        if ($i < $sentence_length - 1
          and attr($all_nodes_ord_sorted[$i+1], 'form') eq '*'  # the next token is also '*'
          and ($i == $sentence_length - 2 or attr($all_nodes_ord_sorted[$i+2], 'form') ne '*')  # the sentence either end with the next token or there are no more consequtive '*'
          and ($i == 0 or attr($all_nodes_ord_sorted[$i-1], 'form') ne '*')) { # and there is no '*' just before the actual token
          # We have found '**', i.e. a start or an end of bold
          $inside_bold = 1 - $inside_bold;
          mylog(0, "Found a bold mark ('**'); inside_bold changed to: '$inside_bold'\n");
          set_property($all_nodes_ord_sorted[$i], 'misc', 'PonkMD', 1); # mark both stars as a markdown mark
          set_property($all_nodes_ord_sorted[$i+1], 'misc', 'PonkMD', 1);
        }
      }

      ################################
      # __bold text__
      ################################
      # Search for a start or end bold ('__')
      if ($form eq '_') {
        if ($i < $sentence_length - 1
          and attr($all_nodes_ord_sorted[$i+1], 'form') eq '_'  # the next token is also '_'
          and ($i == $sentence_length - 2 or attr($all_nodes_ord_sorted[$i+2], 'form') ne '_')  # the sentence either end with the next token or there are no more consequtive '_'
          and ($i == 0 or attr($all_nodes_ord_sorted[$i-1], 'form') ne '_')) { # and there is no '_' just before the actual token
          # We have found '__', i.e. a start or an end of bold
          $inside_bold = 1 - $inside_bold;
          mylog(0, "Found a bold mark ('__'); inside_bold changed to: '$inside_bold'\n");
          set_property($all_nodes_ord_sorted[$i], 'misc', 'PonkMD', 1); # mark both underscores as a markdown mark
          set_property($all_nodes_ord_sorted[$i+1], 'misc', 'PonkMD', 1);
        }
      }
      
=cut

      my $is_md = get_property($all_nodes_ord_sorted[$i], 'misc', 'PonkMD'); 
      
      if ($inside_bold and !$is_md) {
        set_property($all_nodes_ord_sorted[$i], 'misc', 'PonkBold', 1);
      }
      
    }

  }
  
} # end of processing markdown if needed


#####################################################
# The whole text has been processed, let us finish up
#####################################################

# print_log_tail();

# Measure time spent so far
my $end_time = [gettimeofday];
$processing_time = tv_interval($start_time, $end_time);

# calculate and format statistics if needed
my $stats;
if ($store_statistics or $output_statistics) { # we need to calculate statistics
  $stats = get_stats();
}

# print the input text with marked sources in the selected output format to STDOUT
my $output = get_output($output_format);

if (!$output_statistics) { # statistics should not be a part of output
  print $output;
}
else { # statistics should be a part of output, i.e. output will be JSON with two items: data (in output-format) and stats (in html)
  my $json_data = {
       data  => $output,
       stats => $stats,
     };
  # Encode the Perl data structure into a JSON string
  my $json_string = encode_json($json_data);
  # Print the JSON string to STDOUT
  print $json_string;  
}

if ($store_format) { # log the anonymized text in the given format in a file
  $output = get_output($store_format) if $store_format ne $output_format;
  my $output_file = basename($input_file);
  open(OUT, '>:encoding(utf8)', "$script_dir/log/$output_file.$store_format") or die "Cannot open file '$script_dir/log/$output_file.$store_format' for writing: $!";
  print OUT $output;
  close(OUT);
}

################################################################
########################## FINISHED ############################
################################################################

=item log

A function to print log (debug) info based on $log_level (0=full, 1=limited, 2=anonymous).
The message only gets printed (to STDERR) if given $level is greater than or equal to global $log_level.

=cut

sub mylog {
  my ($level, $msg) = @_;
  if ($level >= $log_level) {
    print STDERR "ponk: $msg";
  }
}


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
  my $ne = get_misc_value($node, 'NE') // '';
  my @values = ();
  if ($ne) {
    @values = $ne =~ /([A-Za-z][a-z_]?)_[0-9]+/g; # get an array of the classes
  }
  return @values;
}


=item set_property

In the given attribute at the given node (e.g., 'misc'), it sets the value of the given property.

=cut

sub set_property {
  my ($node, $attr, $property, $value) = @_;
  # mylog(0, "set_property: '$attr', '$property', '$value'\n");
  my $orig_value = attr($node, $attr) // '';
  # mylog(0, "set_property: orig_value: '$orig_value'\n");
  my @values = grep {$_ !~ /^$property\b/} grep {$_ ne ''} grep {defined} split('\|', $orig_value);
  push(@values, "$property=$value");
  my @sorted = sort @values;
  my $new_value = join('|', @sorted);
  set_attr($node, $attr, $new_value);
}


=item get_property

From the given attribute at the given node (e.g., 'misc'), it gets the value of the given property (or undef if not set).

=cut

sub get_property {
  my ($node, $attr, $property) = @_;
  # mylog(0, "get_property: '$attr', '$property', '$value'\n");
  my $attr_value = attr($node, $attr);
  return undef if !$attr_value;
  # mylog(0, "get_property: attr_value: '$attr_value'\n");
  my @attr_properties = grep {$_ =~ /^$property\b/} grep {$_ ne ''} grep {defined} split('\|', $attr_value);
  return undef if !scalar(@attr_properties);
  my $attr_property = $attr_properties[0]; # expect each property to appear only once
  if ($attr_property =~ /$property=(.+)/) {
    my $value = $1;
    return $value;
  }
  return undef;
}


=item


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



=item get_misc_value

Returns a value of the given property from the misc attribute. Or undef.

=cut

sub get_misc_value {
  my ($node, $property) = @_;
  my $misc = attr($node, 'misc') // '';
  # mylog(0, "get_misc_value: token='" . attr($node, 'form') . "', misc=$misc\n");
  if ($misc =~ /$property=([^|]+)/) {
    my $value = $1;
    # mylog(0, "get_misc_value: $property=$value\n");
    return $value;
  }
  return undef;
}  


=item get_feat_value

Returns a value of the given property from the feats attribute. Or undef.

=cut

sub get_feat_value {
  my ($node, $property) = @_;
  my $feats = attr($node, 'feats') // '';
  # mylog(0, "get_feat_value: feats=$feats\n");
  if ($feats =~ /$property=([^|]+)/) {
    my $value = $1;
    # mylog(0, "get_feat_value: $property=$value\n");
    return $value;
  }
  return undef;
}  


=item get_output

Returns the input text with marked sources in the given format (one of: txt, html, conllu).

=cut

sub get_output {
  my $format = shift;
  my $output = '';

  # FILE HEADER
  
  if ($format eq 'html') {
    $output .= "<html>\n";
    $output .= <<END_OUTPUT_HEAD;
<head>
  <style>
        /* source classes colours */
        .highlighted-text {
            color: $color_highlight_general;
        }
  </style>
</head>
END_OUTPUT_HEAD
    $output .= "<body>\n";
  }
  
  my $first_par = 1; # for paragraph separation in txt and html formats (first par in the file should not be separated)

  my $first_sent = 1; # for sentence separation in txt and html formats (first sentence in the file should not be separated)
  

  foreach $root (@trees) {

#=item 

    # PARAGRAPH SEPARATION (txt, html)
    if (attr($root, 'newpar') and $format =~ /^(txt|html)$/) {
      $first_sent = 1;
      if ($first_par) {
        $first_par = 0;
      }
      else {
        $output .= "\n</p>\n" if $format eq 'html';
        # $output .= "\n\n" if $format eq 'txt'; # maybe not needed since using SpacesAfter and SpacesBefore
      }
      $output .= "<p>\n" if $format eq 'html';
    }

#=cut

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

    # PRINT THE SENTENCE TOKEN BY TOKEN
    my @nodes = sort {attr($a, 'ord') <=> attr($b, 'ord')} descendants($root);
    my $space_before = '';

    foreach my $node (@nodes) {

      next if attr($node, 'hidden'); # do not output hidden nodes (originally parts of multiword expressions such as multiword street names)
      
      # COLLECT INFO ABOUT THE TOKEN
      #my $replacement = attr($node, 'replacement');
      my $form = attr($node, 'form');
      my $classes = get_NameTag_marks($node) // '';

      my $span_start = '';
      my $span_end = '';
      my $info_span = '';

=item

      if ($replacement and $format eq 'html') {
        my $span_class = 'highlighted-text';
        if ($classes =~/\bgu\b/) {
          $span_class .= ' replacement-text-gu';
        }
        $span_start = "<span class=\"$span_class\">";
        $span_end = '</span>';
      }

=cut


      # PRINT THE TOKEN
      if ($format =~ /^(txt|html)$/) {
        my $SpaceAfter = get_misc_value($node, 'SpaceAfter') // '';
        my $SpacesAfter = get_misc_value($node, 'SpacesAfter') // ''; # newlines etc. in the original text
        my $SpacesBefore = get_misc_value($node, 'SpacesBefore') // ''; # newlines etc. in the original text; seems to be sometimes used with presegmented input

        # handle extra spaces and newlines in SpaceBefore (seems to be sometimes used with presegmented input)
        if ($SpacesBefore =~ /^(\\s|\\r|\\n)+$/) { # SpacesBefore informs that there were newlines or extra spaces in the original text here
          if ($format eq 'html') {
            $SpacesBefore =~ s/\\r//g;
            while ($SpacesBefore =~ /\\s\\s/) {
              $SpacesBefore =~ s/\\s\\s/&nbsp; /;
            }
            $SpacesBefore =~ s/\\s/ /g;
            while ($SpacesBefore =~ /\\n\\n/) {
              $SpacesBefore =~ s/\\n\\n/\n<p><\/p>\\n/;
            }
            $SpacesBefore =~ s/\\n/\n<br>/g;            
          }
          else { # txt
            $SpacesBefore =~ s/\\r/\r/g;
            $SpacesBefore =~ s/\\n/\n/g;
            $SpacesBefore =~ s/\\s/ /g;
          }
          $output .= $SpacesBefore;          
        }

        $output .= "$space_before$span_start$form$span_end$info_span";

        $space_before = ($SpaceAfter eq 'No') ? '' : ' '; # this way there will not be space after the last token of the sentence

        # $output .= "($SpacesAfter)"; # debug info
        # handle extra spaces and newlines in SpaceAfter
        if ($SpacesAfter =~ /^(\\s|\\r|\\n)+$/) { # SpacesAfter informs that there were newlines or extra spaces in the original text here
          if ($format eq 'html') {
            $SpacesAfter =~ s/\\r//g;
            while ($SpacesAfter =~ /\\s\\s/) {
              $SpacesAfter =~ s/\\s\\s/&nbsp; /;
            }
            $SpacesAfter =~ s/\\s/ /g;
            while ($SpacesAfter =~ /\\n\\n/) {
              $SpacesAfter =~ s/\\n\\n/\n<\/p><p>\\n/;
            }
            $SpacesAfter =~ s/\\n/\n<br>/g;            
          }
          else { # txt
            $SpacesAfter =~ s/\\r/\r/g;
            $SpacesAfter =~ s/\\n/\n/g;
            $SpacesAfter =~ s/\\s/ /g;
          }
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

    # sentence separation in the conllu format needs to be here (also the last sentence should be ended with \n)
    if ($format eq 'conllu') {
      $output .= "\n"; # an empty line ends a sentence in the conllu format    
    }
    
  }
  
  # All sentences processed

  if ($format eq 'html') {
    $output .= "\n</p>\n";
    $output .= "</body>\n";
    $output .= "</html>\n";
  }

  return $output;
  
} # get_output


=item surface_text

Given array of nodes, give surface text they represent

=cut

sub surface_text {
  my @nodes = @_;
  my @ord_sorted = sort {attr($a, 'ord') <=> attr($b, 'ord')} @nodes;
  my $text = '';
  my $space_before = '';
  foreach my $token (@ord_sorted) {
    # mylog(0, "surface_text: processing token " . attr($token, 'form') . "\n");
    $text .= $space_before . attr($token, 'form');
    my $SpaceAfter = get_misc_value($token, 'SpaceAfter') // '';
    my $SpaceAfterOrig = get_misc_value($token, 'SpaceAfterOrig') // '';
    $space_before = ($SpaceAfter eq 'No' and $SpaceAfterOrig ne 'Yes') ? '' : ' ';
  }
  return $text;
}


=item get_stats

Produces an html document with statistics about the anonymization, using info from these variables:
my $sentences_count;
my $tokens_count;
my $processing_time;

=cut

sub get_stats {
  my $stats = "<html>\n";
  $stats .= <<END_HEAD;
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

  $stats .= "<body>\n";

  $stats .= "<h3>PONK version $VER</h3>\n";
  
  $stats .= "<p>Number of sentences: $sentences_count\n";
  $stats .= "<br/>Number of tokens: $tokens_count\n";
  my $rounded_time = sprintf("%.1f", $processing_time);
  $stats .= "<br/>Processing time: $rounded_time sec.\n";
  $stats .= "</p>\n";

  $stats .= "$DESC\n";
  
  $stats .= "</body>\n";
  $stats .= "</html>\n";

  return $stats;
}


=item get_sentence

Given a range of text indexes (e.g. "124:129"), it returns the sentence to which the range belongs.

=cut

sub get_sentence {
  my $range = shift;
  if ($range =~ /^(\d+):(\d+)/) {
    my ($start, $end) = ($1, $2);
    foreach $root (@trees) { # go through all sentences
      if (attr($root, 'start') <= $start and attr($root, 'end') >= $end) { # we found the tree
        return attr($root, 'text');
      }
    }
  }
  else {
    return 'N/A';
  }
}


# the following function is modified from Jan Štěpánek's UD TrEd extension
sub _create_structure {
    my ($root) = @_;
    my %node_by_ord = map +(attr($_, 'ord') => $_), $root->getAllChildren;
    # mylog(0, "_create_structure: \%node_by_ord:\n");
    foreach my $ord (sort {$a <=> $b} keys(%node_by_ord)) {
      # mylog(0, "_create_structure:   - $ord: " . attr($node_by_ord{$ord}, 'form') . "\n");
    }
    foreach my $node ($root->getAllChildren) {
        my $head = attr($node, 'head');
        # mylog(0, "_create_structure: head $head\n");
        if ($head) { # i.e., head is not 0, meaning this node should not be a child of the technical root
            my $parent = $node->getParent();
            $parent->removeChild($node);
            my $new_parent = $node_by_ord{$head};
            $new_parent->addChild($node);
        }
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

######### Simple::Tree METHODS #########

sub set_attr {
  my ($node, $attr, $value) = @_;
  my $refha_props = $node->getNodeValue();
  $$refha_props{$attr} = $value;
}

sub attr {
  my ($node, $attr) = @_;
  my $refha_props = $node->getNodeValue();
  return $$refha_props{$attr};
}

sub descendants {
  my $node = shift;
  my @children = $node->getAllChildren;
  foreach my $child ($node->getAllChildren) {
    push (@children, descendants($child));
  }
  return @children;
}
  
sub root {
  my $node = shift;
  while ($node->getParent) {
    $node = $node->getParent;
  }
  return $node;
}


######### PARSING THE TEXT WITH UDPIPE #########

=item call_udpipe

Calling UDPipe REST API; the input to be processed is passed in the first argument
The second argument ('segment'/'parse') chooses between the two tasks.
Segmentation expects plain text as input, the parsing expects segmented conll-u data.
Returns the output in UD CONLL format

=cut

sub call_udpipe {
    my ($text, $task) = @_;

=item

    # Nefunkční pokus o volání metodou POST

    # Nastavení URL pro volání REST::API
    my $url = 'http://lindat.mff.cuni.cz/services/udpipe/api/process';

    # Připravení dat pro POST požadavek
    my %post_data = (
        tokenizer => 'ranges',
        tagger => 1,
        parser => 1,
        data => uri_escape_utf8($text)
    );

    if ($input_format eq 'presegmented') {
        $post_data{tokenizer} .= ';presegmented';
    }

    # Vytvoření instance LWP::UserAgent
    my $ua = LWP::UserAgent->new;

    # Vytvoření POST požadavku s daty jako JSON
    my $req = HTTP::Request->new('POST', $url);
    $req->header('Content-Type' => 'application/json');
    $req->content(encode_json(\%post_data));

=cut

    my $model;
    my $input;
    my $tagger;
    my $parser;

    if ($task eq 'segment') {
      $input = 'tokenizer=ranges';
      if ($input_format eq 'presegmented') {
        $input .= ';presegmented';
      }
      $model = '&model=czech-pdtc1.0';
      $tagger = '';
      $parser = '';
    }
    elsif ($task eq 'parse') {
      $input = 'input=conllu';
      $model = '&model=czech';
      $tagger = '&tagger';
      $parser = '&parser';
    
    }

    # Funkční volání metodou POST, i když podivně kombinuje URL-encoded s POST

    # Nastavení URL pro volání REST::API s parametry
    #my $url = "http://lindat.mff.cuni.cz/services/udpipe/api/process?$input$model$tagger$parser";
    my $url = "$udpipe_service_url/process?$input$model$tagger$parser";
    mylog(2, "Call UDPipe: URL=$url\n");
    
    my $ua = LWP::UserAgent->new;

    # Define the data to be sent in the POST request
    my $data = "data=" . uri_escape_utf8($text);

    my $req = HTTP::Request->new('POST', $url);
    $req->header('Content-Type' => 'application/x-www-form-urlencoded');
    $req->content($data);


    # Odeslání požadavku a získání odpovědi
    my $res = $ua->request($req);

    # Zkontrolování, zda byla odpověď úspěšná
    if ($res->is_success) {
        # Získání odpovědi v JSON formátu
        my $json_response = decode_json($res->content);
        # Zpracování odpovědi
        my $result = $json_response->{result};
        # print STDERR "UDPipe result:\n$result\n";
        return $result;
    } else {
        mylog(2, "call_udpipe: URL: $url\n");
        mylog(1, "call_udpipe: Text: $text\n");
        mylog(2, "call_udpipe: Chyba: " . $res->status_line . "\n");
        return '';
    }
}

######### NAMED ENTITIES WITH NAMETAG #########

=item call_nametag

Calling NameTag REST API; the text to be searched is passed in the argument in UD CONLL format
Returns the text in UD CONLL-NE format.
This function just splits the input conll format to individual sentences (or a few of sentences if $max_sentences is set to a larger number than 1) and calls function call_nametag_part on this part of the input, to avoid the NameTag error caused by a too large argument.

=cut

sub call_nametag {
    my $conll = shift;
    
    my $result = '';
    
    # Let us call NameTag api for each X sentences separately, as too large input produces an error.
    my $max_sentences = 100; # 5 was too large at first attempt, so let us hope 1 is safe enough.
    
    my $conll_part = '';
    my $sent_count = 0;
    foreach my $line (split /\n/, $conll) {
      #mylog(0, "Processing line $line\n");
      $conll_part .= $line . "\n";
      if ($line =~ /^\s*$/) { # empty line means end of sentence
        #mylog(0, "Found an empty line.\n");
        $sent_count++;
        if ($sent_count eq $max_sentences) {
          $result .= call_nametag_part($conll_part);
          $conll_part = '';
          $sent_count = 0;
        }
      }
    }
    if ($conll_part) { # We need to call NameTag one more time
      $result .= call_nametag_part($conll_part);    
    }
    return $result;
}

=item call_nametag_part

Now actuall calling NameTag REST API for a small part of the input (to avoid error caused by a long argument).
Returns the text in UD CONLL-NE format.
If an error occurs, the function just returns the input conll text unchanged.

=cut

sub call_nametag_part {
    my $conll = shift;

    # Funkční volání metodou POST, i když podivně kombinuje URL-encoded s POST

    # Nastavení URL pro volání REST::API s parametry
    my $url = "$nametag_service_url/recognize?input=conllu&output=conllu-ne";
    mylog(2, "Call NameTag: URL=$url\n");

    my $ua = LWP::UserAgent->new;

    # Define the data to be sent in the POST request
    my $data = "data=" . uri_escape_utf8($conll);

    my $req = HTTP::Request->new('POST', $url);
    $req->header('Content-Type' => 'application/x-www-form-urlencoded');
    $req->content($data);


    # Odeslání požadavku a získání odpovědi
    my $res = $ua->request($req);

    # Zkontrolování, zda byla odpověď úspěšná
    if ($res->is_success) {
        # Získání odpovědi v JSON formátu
        my $json_response = decode_json($res->content);
        # Zpracování odpovědi
        my $result = $json_response->{result};
        # mylog(0, "NameTag result:\n$result\n");
        return $result;
    } else {
        mylog(2, "call_nametag_part: URL: $url\n");
        mylog(2, "call_nametag_part: Chyba: " . $res->status_line . "\n");
        return $conll; 
    }
}

sub convertFromDocx {

    # Načtení docx kódovaného v Base64 ze stdin
    my $base64_data = do {
      local $/; # Nastavení náhrady konce řádku na undef, čímž načte celý obsah
      <STDIN>;
    };

    my $word_document = decode_base64($base64_data); # nyní mám původní binární podobu docx

=item

    my $soubor = '/home/mirovsky/pokus2.docx';
    open my $soubor_handle, '>:raw', $soubor or die "Nelze otevřít soubor '$soubor' pro zápis: $!";
    print $soubor_handle $word_document;
    close $soubor_handle;

=cut

    # Spuštění programu pandoc s předáním parametrů a standardního vstupu
    my @cmd = ('/usr/bin/pandoc',
               '-f', 'docx',
               '-t', 'markdown'); # Nastavit výstup na standardní výstup);
    my $result;
    run \@cmd, \$word_document, \$result;

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
