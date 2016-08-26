#!/usr/bin/env perl

#use warnings;

use File::Copy;                                 # Module for copying files. Used to replace output file with temp cleaned-up file.    #
use utf8;                                       # Required to process Unicode text (the phonetic symbols).                            #
use Encode;                                     # Module for dealing with different text encodings, such as UTF-8.                    #
use File::Slurp::Unicode;                       # Allows Unicode files to be slurped in. Required for final clean-up process          #
use Getopt::Long qw(:config no_auto_abbrev);    # Module for processing command line options.                                         #
use Lingua::ES::Numeros;                        # Module to convert numerals to Spanish text.                                         #

# NOTE: Do NOT use 'strict' -- it produces incorrect output!

my $version = "1.0.6";
# 11 July 2016

#######################################################################################
#                                       Perkins                                       #
#                         Copyright (c) 2016 Scott Sadowsky                           #
#                                                                                     #
#                 http://sadowsky.cl - ssadowsky at gmail period com                  #
#    Licensed under the GNU Affero General Public License, version 3 (GNU AGPLv3)     #
#                                                                                     #
#                   For help, run the program with the -h switch.                     #
#                                                                                     #
#######################################################################################
#                                                                                     #
# Script to phonetically transcribe, silabify and determine accents in Spanish text.  #
#                                                                                     #
# USE:    ./perkins.pl [OPTIONS] -i=input_file.txt [-o=output_file.txt]               #
#                                                                                     #
# NOTE:   Input and config files MUST be ISO-8859-1 (Latin-1) text. Output (and       #
#         optional debugging) files will be in UTF-8.                                 #
#                                                                                     #
# Known bug (as of 102): convert_backchannel_vocalizations produces t͡ʃ.̩ː (with       #
#    spurious syllable dot). (Fixed as of 104?)                                       #
#                                                                                     #
#######################################################################################

#################################################################################
# Perkins, the Phonetician's Assistant.                                         #
# Copyright (C) 2016 Scott Sadowsky                                             #
# http://sadowsky.cl · s s a d o w s k y A T g m a i l D O T com                #
#                                                                               #
# This program is free software: you can redistribute it and/or modify          #
# it under the terms of the GNU Affero General Public License as published      #
# by the Free Software Foundation, either version 3 of the License, or          #
# (at your option) any later version.                                           #
#                                                                               #
# This program is distributed in the hope that it will be useful,               #
# but WITHOUT ANY WARRANTY; without even the implied warranty of                #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                 #
# GNU Affero General Public License for more details.                           #
#                                                                               #
# You should have received a copy of the GNU Affero General Public License      #
# along with this program.  If not, see <http://www.gnu.org/licenses/>.         #
#################################################################################

#################################################################################
#                 SET DEFAULT VALUES FOR PROGRAM OPTIONS AND VARIABLES          #
#################################################################################

###################################################
#         OPTIONS THAT USERS MAY CONFIGURE        #
###################################################

# USER OPTIONS - PROGRAM BEHAVIOR                 #
our $debug            = 0;
our $debug_syllab_sub = 0;
our $debug_to_logfile = 0;
our $silent_mode      = 0;
our $batch_mode       = 0;       # Set to 1 for batch mode. This suppresses output to stdout, etc.
my $use_config_file   = 0;       # Choose whether or not to process the perkins.ini config file.
my $lang              = "en";    # Default program message language

# META OPTIONS - FOR SPECIFIC COMBINATIONS OF VARIABLES
our $corpus_running_text = 0;    # Select settings for the Coscach / Codicach: Running text syllabified at sentence
                                 # level, one character per phoneme, etc. This overrides most other settings, to make
                                 # sure that the corpus is processed uniformly, so turn it off to specify other options.

our $syllable_list = 0;          # Select settings for producing output that is easy to process at the syllable level (each
                                 # syllable is separated from others by a space). This overrides most other settings, to make
                                 # sure that the corpus is processed uniformly, so turn it off to specify other options.

our $vrt_format      = 0;        # Select settings for generating one-word-per-line IMS Corpus Workbench-compatible
                                 # vertical text (.vrt). Currently (381), Perkins only produces the transcribed form.
                                 # This overrides most other settings to make sure that the corpus is processed
                                 #uniformly, so turn it off to specify other options.
our $all_year_ranges = 1;        # Process all date ranges (1-3 digit, 4 digit, BC dates).

# USER OPTIONS - FORMAT OR MODE OF TRANSCRIPTION OUTPUT #
our $output_PHON   = 1;          # Set output to phonemic transcription
our $output_CV     = 0;          # Instead of outputting phonemes, output C (consonant) or V (vowel)
our $output_CVG    = 0;          # Instead of outputting phonemes, output C (consonant), V (vowel) or G (glide)
our $output_CVNLRG = 0;          # Instead of outputting phonemes, output Vowel, Nasal, Liquid, Rhotic,
                                 #    Glide or (misc) Consonant
our $output_manner = 0;          # Instead of outputting phonemes, output the manner of articulation
our $output_place  = 0;          # Instead of outputting phonemes, output the mode of articulation
our $voicing       = 0;          # Instead of outputting phonemes, output the voicing

# USER OPTIONS - FOR SPECIFIC PHONEMES#
our $multichars              = 1;    # Represent certain phonemes using more than one character (e.g. use "t̠͡ʃ" instead of "ʧ")
our $tr_is_group             = 0;    # Treat /tr/ as a group. If on, it produces "t͡ɾ" with multichars and "ʂ" without it.
our $ch_dzh_retracted        = 0;    # Add retracted diacritic to the /t̠͡ʃ/ and /d̠͡ʒ/ digraphs (if /ʝ/ is not used)
our $ye_phoneme_is_fricative = 1;    # Represent the phoneme "ye" (<ll> in "ella", <y> in "yo") with the palatal frictive symbol ʝ
                                     #    instead of the affricate ʤ
our $ye_phoneme_is_affricate = 0;    # MUST have opposite value of $ye_phoneme_is_fricative !
our $use_ligatures           = 1;    # Use ligatures in /ʧ/ and /ʤ/ (/ʝ/)
our $use_one_char_ch_symbol  = 0;    # Use the /ʧ/ symbol to represent /ʧ/ regardless of the multichar setting. It was a stupid decision of mine to link the two!
our $use_one_char_ye_symbol  = 1;    # Use the /ʝ/ symbol to represent /ʝ/ regardless of the multichar setting. It was a stupid decision of mine to link the two!
our $use_dental_diacr        = 1;    # Use dental diacritic with /d/ and /t/
our $add_epenthetic_g        = 0;    # Add an epenthetic [g] before /w/. Traditionally believed ubiquitous in Chilean Spanish, but turns out to be rather uncommon.

# USER OPTIONS - FOR GLIDES          #
our $glides_with_diacritics = 0;     # Controls the following two variables.
our $non_syl_u_with_u_diacr = 0;     # Represent the non-syllabic /u/ as /u̯/, not /w/
our $non_syl_i_with_i_diacr = 0;     # Represent the non-syllabic /i/ as /i̯/, not /j/

# USER OPTIONS - STRESS              #
our $stress_using_tildes = 0;        # If 1, mark stress with tildes on stressed vowels; if 0, mark it with IPA apostrophes.
our $no_stress_marks     = 0;        # Don't include any type of stress indication. Only for special cases.
our $non_ipa_apostrophes = 0;        # Use the standard orthographic apostrophe (') instead of the IPA one (which doesn't show in Praat)
                                     # Added in 376

# USER OPTIONS - SYLLABLES            #
our $insert_syllable_dots     = 1;    # Insert dots between each syllable
our $split_at_syllables       = 0;    # Put a newline at each syllable break.
our $syllabify_by_sentence    = 1;    # Syllabifies by sentence instead of by word. Means that "los hombres" > /lo.som.bres/
                                      # instead of /los om.bres/
our $syllable_dots_are_spaces = 0;    # Separate syllables with spaces instead of dots. Designed to facilitate processing
                                      # and research on syllables in the Codicach, etc. (lets syls be treated as words)

# USER OPTIONS - PAUSES               #
our $ipa_pause_symbols    = 1;        # Use the IPA's | and ‖ method of representing pauses            #
our $ipa_long_pause_two_singles = 0;  # For long IPA pauses, use two single pause bars (||) instead of one#
                                      # double bar (‖). This is useful b/c Praat can't show the double bar.#
our $add_comma_pauses     = 1;        # Commas are converted into short pauses:                 (.)     #
our $add_colon_pauses     = 1;        # Colons are converted into medium pauses:                (..)    #
our $add_semicolon_pauses = 1;        # Semicolons are converted into long pauses:              (...)   #
our $add_sentence_breaks  = 1;        # Periods are converted into absolute breaks:             ##      #
our $add_paragraph_breaks = 1;        # Paragraph breaks are converted into longest pause:      ###     #
                                      #    This can be in addition to newlines.                         #
our $add_ellipsis_pauses  = 1;        # Ellipses are converted into a long pause:               (...)   #
our $add_bracket_pauses   = 1;        # Convert [ and ] into short pauses                       (.)     #
our $add_paren_pauses     = 1;        # Convert ( and ) into short pauses                       (.)     #

# USER OPTIONS - NUMBERS              #
our $numerals_to_words    = 1;        # Convert numerals (123) to words (uno dos tres)                                #
our $num_symbol           = "·";      # Symbol used to replace numerals if that option is chosen                      #
our $narrow_year_ranges   = 1;        # Treat two consecutive 4-digit numbers separated by "-" as a range of years    #
                                      #  (e.g. "1900-1950" > "1900 a 1950") instead of an equation (1900 minus 1950)  #
                                      #  IF AND ONLY IF the second number is larger than the first.                   #
our $broad_year_ranges    = 1;        # Treat two consecutive 1-4 digit numbers separated by "-" as a range of years  #
                                      #  (e.g. "211-300" > "211 a 300") instead of an equation (211 minus 300)        #
                                      #  IF AND ONLY IF the second number is larger than the first.                   #
our $bc_dates_included    = 1;        # Remove restriction on second number having to be larger than the first from   #
                                      #  $narrow_year_ranges and $broad_year_ranges.                                  #

# USER OPTIONS - ODD CHARACTERS       #
our $fix_umlauts          = 1;        # Change vowels with umlauts to bare vowels (except ü for diéresis)   #
our $fix_grave_accents    = 1;        # Change vowels with umlauts to bare vowels (tù, està > tú, está)     #
our $fix_circumflexes     = 1;        # Change vowels with circumflexes to bare vowels (hôstel > hostel)    #
our $fix_nasal_tildes     = 1;        # Change vowels with nasal tildes to bare vowels (S~ao > Sao)         #

# USER OPTIONS - SUBSTITUTIONS       #
our $moneda        = "pésos";        # String used to replace "$" character                                #
our $slash         = "eslách";       # String used to replace "/" character                                #
our $process_urls  = 1;              # Process URLs, treating them as linguistic strings.                  #
our $process_email = 1;              # Process e-mail addresses, treating them as linguistic strings.      #

# NEW IN 0406 ->
our $name_for_v    = "becórta";      # Name for letter "v" to be used when spelling individual letters out.#
                                     # Suggested values: "becórta", "bechíca", "úve" (with tilde on        #
                                     # accented syl. and written as one word).                             #

# USER OPTIONS - MISC                #
our $keep_paragraphs          = 1;   # Keep paragraphs in the source text. Otherwise, output will be one big block. #
our $vertical_output          = 0;   # Output contains one word per line.                                           #
# NEW IN 104. TESTING!
our $double_vowels_to_singles = 1;   # Reduce two identical vowels ("aa", "ee", "ii", etc.) to a single one.

###################################################
#      OPTIONS THAT USERS MAY *NOT* CONFIGURE     #
###################################################

our $semi_narrow = 0;                 # NOT YET IMPLEMENTED. Select whether to process the broad transcription once it's produced, in order    #
                                      #   to create a semi-narrow transcription                                              #

our $cleanup_output_file = 1;         # WARNING Must ALWAYS be 1! After processing the input file and producing the output    #
                                      #         file, this option makes Perkins open the output file again to perform cleanup.#

our $no_separate_cleanup_file = 1;    # WARNING Must ALWAYS be 1! Determines if the cleaned up version goes to a separate text#
                                      #         file or replaces the output file ONLY IN BETA MODE.                           #

# OUTPUT: CLEANUP OPTIONS             #
our $preclean_orthographic = 1;       # WARNING Must ALWAYS be 1! Apply the clean-up routine for words in their orthographic form
our $preclean_semiphonemic = 1;       # WARNING Must ALWAYS be 1! Apply the clean-up routine for words in their semi-phonemic form
our $preclean_phonemic     = 0;       # WARNING NOT IMPLEMENTED YET! # Apply the clean-up routine for words in their phonemic form

# MISC                                #
my $upper_case = 0;                   # Sets whether output is uppercased (CV, CVG, etc.; bad for phonemic transcription)
our $kill_common_words = 0;           # FOR TESTING. Eliminate common words to make it easier to find novel mistakes.

# INTERNAL VARIABLES THAT NEED INITIALIZED - DON'T CHANGE!
my $helpme              = 0;          # Should help message be printed to terminal?
my $useme               = 0;          # Should usage message be printed to terminal?
my $config_file_present = 0;
my $output_filename     = "";
my $progname            = "";

# Set program name according to OS. Assumes Windows users will use    #
# the .exe version of Perkins.                                        #

if   ( $^O eq "MSWin32" ) { $progname = "perkins.exe " }
else                      { $progname = "./perkins.pl" }

############################################################################
#            DECLARE VARIABLES THAT REQUIRE A (DEFAULT) VALUE              #
#  DON'T CHANGE ANYTHING HERE UNLESS YOU ARE REWRITING THE ENTIRE PROGRAM  #
############################################################################
my $accent                    = "";
my $acute_consonants          = "(b|ʧ|d|ʤ|ʝ|f|g|j|k|l|m|ɲ|p|ɾ|r|ʂ|t|w|x|y|z)";
my $acute_consonants_except_j = "(b|ʧ|d|ʤ|ʝ|f|g|k|l|m|ɲ|p|ɾ|r|ʂ|t|w|x|y|z)";
my $all_consonants            = "(b|ʧ|d|ʤ|ʝ|f|g|j|k|l|m|ɲ|n|p|ɾ|r|s|ʂ|t|w|x|y|z)";
my $all_consonants_but_glides = "(b|ʧ|d|ʤ|ʝ|f|g|k|l|m|ɲ|n|p|ɾ|r|s|ʂ|t|x|y|z)";
my $non_liquids               = "(b|ʧ|d|ʤ|ʝ|f|g|j|k|m|ɲ|n|p|s|ʂ|t|w|x|y|z)";
my $orthog_epenth_e_cons      = "(b|c|d|f|g|j|k|l|m|n|p|q|r|s|t|v|x|y|z)";
my $stressed_vowels           = "(á|é|í|ó|ú)";
my $unstressed_vowels         = "(a|e|i|o|u)";
my $all_vowels                = "(a|e|i|o|u|á|é|í|ó|ú)";
my $strong_vowels             = "(a|e|o)";
my $weak_vowels               = "(i|u)";

# For sentence-level syllabification
my $all_consonants_diacr = "(b|ʧ|t͡ʃ|t̠͡ʃ|d|d̪|ʤ|d͡ʒ|d̠͡ʒ|ʝ|f|g|j|k|l|m|ɲ|n|p|ɾ|r|s|ʂ|t|t̪|tɾ|t̪ɾ|t͡ɾ|t̪͡ɾ|w|x|y|z)";
my $all_vowels_diacr     = "(a|e|i|o|u|á|é|í|ó|ú|i̯|u̯)";

# The following are for the routine that replaces phonemes with C, V, N, L, G, etc.
my $misc_cons     = "(b|ʧ|d|ʤ|ʝ|f|g|k|p|s|ʂ|t|x)";
my $nasals        = "(m|n|ɲ)";
my $liquids       = "(l)";
my $glides        = "(j|w)";
my $rhotics       = "(r|ɾ)";
my $vowels_glides = "(a|e|i|o|u|á|é|í|ó|ú|j|w)";

# The /tr/ group... always fun! NOTE: Not used much by Perkins -- ʂ is normally hard-coded
my $tr = "(ʂ)";

# The following are for the routine that replaces phonemes with MANNERS of articulation
my $plosives = "(b|d|g|k|p|t)";

# $nasals is declared above.
my $trills      = "(r)";
my $taps        = "(ɾ)";
my $fricatives  = "(f|s|x|ʝ)";
my $laterals    = "(l)";
my $affricates  = "(ʧ|ʤ)";
my $aproximants = "(j|w)";

# The following are for the routine that replaces phonemes with PLACES of articulation
my $bilabials     = "(b|m|p)";
my $labiodentals  = "(f)";
my $dentals       = "(d|t)";
my $alveolars     = "(n|ɾ|r|s|l)";
my $postalveolars = "(ʧ|ʤ)";
my $palatals      = "(j|ʝ|ɲ)";
my $velars        = "(k|g|x)";
my $labiovelars   = "(w)";

# The following are for the routine that replaces phonemes with VOICING
my $voiced   = "(a|e|i|o|u|á|é|í|ó|ú|b|d|g|ʤ|ʝ|j|l|m|ɲ|n|ɾ|r|w)";
my $unvoiced = "(ʧ|f|k|p|s|ʂ|t|x)";

############################################################################
#                       DECLARE EMPTY LOCAL VARIABLES                      #
############################################################################
my (
     @character,             $character,           $input_line,          $last_vowel_pos,      @rev_vowels,            $sec_last_vowel_pos,
     @syllable,              $curr_syl,            $vowel_count,         $vowels,              $word,                  @word_array,
     $i,                     $sentence_break,      $comma_pause,         $semicolon_pause,     $colon_pause,           $ellipsis_pause,
     $initial_bracket_pause, $final_bracket_pause, $initial_paren_pause, $final_paren_pause,   $syl_count,             $prev_input_line,
     @whole_file_array,      $whole_file,          $input_filename,      $in_basename,         $beta_file,             @utterance_array,
     $utterance,             $item,                @uniquearray,         $next_char_syl_break, $sr_input_line,         @sr_array,
     $output_format,         $cfg_file_was_read,   $print_usage,         $current_numeral,     $numeral_converter_obj, $word_list,
     $temp,                  $debug_message,       $user_message,        $eng,                 $esp,                   $coscach_mode, $long_pause_symbol
);

#################################################################################
#       CREATE HASH OF ALLOPHONE > SYMBOL MAPPINGS BY READING EXTERNAL FILE     #
#                 IF SEMI-NARROW TRANSCRIPTION OPTION IS CHOSEN                 #
#  NOTE              NOTE    NOT YET IMPLEMENTED!    NOTE                 NOTE  #
#################################################################################
#if ( $semi_narrow == 1 ) {
#     our %allophone_table = ();
#     do "tabla_alofonos.pl";
#}

############################################################################
#        PROCESS THE CONFIGURATION FILE (perkins.ini) IF IT EXISTS         #
#  If $use_config_file is true, then these options supercede the defaults  #
############################################################################

# Open config file, if the option set at beginning of this file allows it  #
if ( $use_config_file == 1 ) {
     open( CONFIGFILE, '<:encoding(iso-8859-1)', "perkins.ini" )    # Input must be ISO-8859-1
       || &config_file_failed;
}

# Process the config file and assign to variables the values found therein.     #
if ( ( $use_config_file == 1 ) && ( $config_file_present == 1 ) ) {
     while (<CONFIGFILE>) {
          chomp;                                                   # Kill newlines
          s/#.*//;                                                  # Kill comments
          s/^\s+//;                                                 # Kill leading whitespace
          s/\s+$//;                                                 # Kill trailing whitespace
          next unless length;                                     # Is anything left?
          my ( $var, $value ) = split( /\s*=\s*/, $_, 2 );          # Split input strings
          $$var = $value;                                           # Assign values to variables
     }
}

#################################################################################
#                            Read and clean up CLI options                      #
#################################################################################
GetOptions(
     "debug|d!"                               => \$debug,                      # Debug Perkins.
     "lang|l=s"                               => \$lang,                       # Language for program messages
     "es"                                     => \$esp,                        # Spanish language program messages selected (alt method)
     "en"                                     => \$eng,                        # English language program messages selected (alt method)
     "debug-log|log|dl!"                      => \$debug_to_logfile,           # Write debug info to log file
     "input|i=s"                              => \$input_filename,
     "output|o=s"                             => \$output_filename,
     "help|ayuda|h|?"                         => \$helpme,                     # See if user needs help
     "usage|use|uso|u"                        => \$useme,                      # Print usage information to terminal
     "format|formato|f:s"                     => \$output_format,              # Output format:    --f=manner
     "trg|tg!"                                => \$tr_is_group,                # Treat TR as group:     --trg
     "yef|yf!"                                => \$ye_phoneme_is_fricative,    # Render YE as fricative: --
     "yea|ya!"                                => \$ye_phoneme_is_affricate,    # Render YE as affricate: --
     "afr|ar!"                                => \$ch_dzh_retracted,           # Affricates retracted:  --afr
     "st|at!"                                 => \$stress_using_tildes,        # Represent stress with tilde, NOT IPA apostrophe.                #
     "multi|mc|ms!"                           => \$multichars,                 # Use more than one IPA symbol for certain phonemes (e.g. t̠͡ʃ).  #
     "glides-dia|gd!"                         => \$glides_with_diacritics,     # Representar glides como vocal + diacrítico "no silábico"        #
     "wvd|wv!"                                => \$non_syl_u_with_u_diacr,     # Represent wau with a u + non-syllabic diacritic.                #
     "yvd|yv!"                                => \$non_syl_i_with_i_diacr,     # Represent yod with an i + non-syllabic diacritic.               #
     "batch|bm|b|quiet|callate!"              => \$batch_mode,                 # Run Perkins in batch mode: no STDOUT output.                    #
     "pausas-afi|ipa-pauses|ip|pi!"           => \$ipa_pause_symbols,          # Represent pauses using IPA's | and || symbols.                  #
     "lp2|pl2!"                               => \$ipa_long_pause_two_singles,  # Represent IPA long pause as 2 single pause bars                 #
     "pco|cmp!"                               => \$add_comma_pauses,           # Convert commas into pauses.                                     #
     "pdp|clp!"                               => \$add_colon_pauses,           # Convert colons into pauses.                                     #
     "ppc|scp!"                               => \$add_semicolon_pauses,       # Convert semicolons into pauses.                                 #
     "por|snp!"                               => \$add_sentence_breaks,        # Add breaks between sentences.                                   #
     "ppa|ppp!"                               => \$add_paragraph_breaks,       # Add breaks between paragraphs.                                  #
     "pel|elp!"                               => \$add_ellipsis_pauses,        # Convert ellipses into pauses.                                   #
     "pcr|brp!"                               => \$add_bracket_pauses,         # Convert brackets into pauses.                                   #
     "ppn|pnp!"                               => \$add_paren_pauses,           # Convert parentheses into pauses.                                #
     "n2w|nap!"                               => \$numerals_to_words,          # Convert numerals into words.                                    #
     "sn:s"                                   => \$num_symbol,                 # Replace numbers with this symbol.                               #
     "mon|cur:s"                              => \$moneda,                     # Replace $ symbol with this text.                                #
     "lo|sl:s"                                => \$slash,                      # Replace / symbol with this text.                                #
     "no-stress-marks|nsm|nma!"               => \$no_stress_marks,            # Don't include any type of stress indication.                    #
     "split-syls|div-sil|sas|des|split-syls!" => \$split_at_syllables,         # Put each syllable on a line of its own.                         #
     "upl|owl|saw|dep|vo|split-words!"        => \$vertical_output,            # Output has one word per line.                                   #

     # the "cwr" CL optins was killed in 407 -- it's an internal variable!
     # "cwr!"                                        => \$cfg_file_was_read,     # Set to 1 if config file was successfully read.                  #
     "mp|kp!"                                      => \$keep_paragraphs,       # Keep paragraph breaks. Otherwise, output is a wall of transcription.#
                                                                               # Permit output format options to be chosen as simple switches:
     "cv!"                                         => \$output_CV,
     "cvg!"                                        => \$output_CVG,
     "cvn|cvnlrg!"                                 => \$output_CVNLRG,
     "manner|man|modo|m!"                          => \$output_manner,
     "place|pl|punto|p!"                           => \$output_place,
     "voicing|voice|v|sonoridad|son|s!"            => \$voicing,
     "kill-common|eliminar-comunes|kcw|kc|epc|ep!" => \$kill_common_words,
     "phon|fon|ph|IPA|AFI"                         => \$output_PHON,
     "cfg|ini!"                                    => \$use_config_file,
     "nia|oa|ao!"                                  => \$non_ipa_apostrophes,
     "syl-dots|sil-puntos|sd|sp!"                  => \$insert_syllable_dots,
     "syl-spaces|sil-esp|ss|se!"  => \$syllable_dots_are_spaces,
     "sbs|sbu|spe|spo!"           => \$syllabify_by_sentence,
     "silent-mode|silent|sil|sm!" => \$silent_mode,
     "rt|tc|corpus!"              => \$corpus_running_text,
     "coscach|csc"                => \$coscach_mode,
     "syl-list|lista-sil|sl|ls!"  => \$syllable_list,
     "word-list|lista-pal|wl|lp!" => \$word_list,
     "vrt!"                       => \$vrt_format,
     "urls|pu!"                   => \$process_urls,
     "email|pe!"                  => \$process_email,
     "nyr|rae!"                   => \$narrow_year_ranges,
     "byr|raa!"                   => \$broad_year_ranges,
     "bcy|aac!"                   => \$bc_dates_included,
     "ayr|tra"                    => \$all_year_ranges,
     "lig!"                       => \$use_ligatures,
     "och!"                       => \$use_one_char_ch_symbol,
     "oye!"                       => \$use_one_char_ye_symbol,
     "dent|dd!"                   => \$use_dental_diacr,
     "aeg|age!"                   => \$add_epenthetic_g,
     "dvs!"                       => \$double_vowels_to_singles
);

############################################################################
#          SET PROGRAM INTERFACE LANGUAGE IF BINARY SWITCHES USED          #
############################################################################
if ( $eng == 1 ) { $lang = "en" }
if ( $esp == 1 ) { $lang = "es" }

############################################################################
#                   DEFINE LANGUAGE STRINGS FOR LOCALIZATION               #
############################################################################
&assign_lang_str;

############################################################################
#              IF  USER NEEDS HELP, RUN HELP SUBROUTINE AND DIE            #
############################################################################
if ( $helpme == 1 ) {
     &print_help;
     exit;
}

############################################################################
#         IF  USER REQUESTS USAGE INFO, RUN THAT SUBROUTINE AND DIE        #
############################################################################
if ( $useme == 1 ) {
     &print_usage;
     exit;
}

# Lowercase any text provided with the -f (output format) switch           #
$output_format = lc($output_format);

############################################################################
# SET OPTIONS FOR DEBUGGING TO LOG FILE                                    #
############################################################################
if ( $debug_to_logfile == 1 ) {
     $debug = 1;
}

############################################################################
#                             VERIFY CLI OPTIONS                           #
#                         Only checks some of them.                        #
############################################################################

&verify_cli_options;

############################################################################
#      AUTOMATICALLY SELECT VRT FORMAT IF INPUT FILE ENDS IN ".VRT"        #
############################################################################
if ( $input_filename =~ m/\.vrt$/ ) {
     $vrt_format = 1;
}

############################################################################
# OPEN INPUT FILE, CREATE LOG FILE                                         #
############################################################################
&open_input_and_log_files;

############################################################################
# Print bug log header, status messages, CLI info and cfg file status      #
# message                                                                  #
############################################################################
my $current_time = localtime();    # Get local time for log file
&print_header_CLI_status_msgs;

############################################################################
# ASSIGN DEFAULT OUTPUT FILENAME IF NECESSARY (.phnm extension)            #
############################################################################
if ( $output_filename eq "" ) {
     &assign_default_output_filename;
}

############################################################################
#              OPEN OUTPUT FILE - Output will be UTF-8                     #
############################################################################
&open_output_file;

############################################################################
#                   PROCESS COMMAND LINE OPTIONS                           #
# If there are any, they supercede both the defaults and the .ini file     #
############################################################################
&process_command_line_options;

############################################################################
#         FORCIBLY SET VARIABLES THAT DEPEND ON OTHER VARIABLES            #
# This has to be done here, and not earlier, so as to receive any changed  #
# variable values from the config file or command line options.            #
############################################################################
&forcibly_set_variables;

############################################################################
#                             CONSOLE GREETING                             #
# This is printed in normal (non-batch/non-silent) mode, but only if the   #
# debug to log file option is OFF.                                         #
############################################################################
if ( ( $batch_mode == "0" ) && ( $debug_to_logfile == 0 ) ) {
     &print_console_greeting;
}

############################################################################
# Print message to log file if config file couldn't be read.               #
# Only done if debug is ON and debug to log file is ON.                    #
############################################################################
if ( ( $debug == 1 ) && ( $debug_to_logfile == 1 ) ) {
     print LOGFILE "\nDEBUG IO:  *WARINING* External config file couldn't be opened.";
     print LOGFILE "\nDEBUG IO:             Using defaults instead.";
}

sub start_of_program {

     # This is a dummy subroutine. Its only purpose is to generate an automatic
     # link in my IDE.
}

############################################################################
#                                                                          #
#                    BEGIN PROCESSING THE INPUT TEXT FILE                  #
#                                                                          #
############################################################################
while (<INPUTFILE>) {
     chomp;
     $input_line = lc;

     ############################################################################
     # .VRT COLUMN STRIPPING                                                    #
     # If reading .vrt text files produced by Connexor, eliminate all text but  #
     # the second column (word forms)                                           #
     ############################################################################
     # TODO: Allow user to specify the column to keep.
     if ( $vrt_format == 1 ) {

          #print STDOUT "VRT-STRIPPING-BEF:$current_item:\n";    # AD-HOC DEBUG
          $input_line =~ s/^.+?\t(.+?)\t.+$/$1/g;

          #print STDOUT "VRT-STRIPPING-AFT:$current_item:\n";    # AD-HOC DEBUG
     }

     ############################################################################
     # .VRT DISASTEROUS CHARACTER ELIMINATION                                   #
     # Kill odd characters that are used internally by Perkins, before anything #
     # else is replaced.                                                        #
     ############################################################################
     if ( $vrt_format == 1 ) {
          $input_line = kill_disasterous_vrt_chars($input_line);
     }

     ############################################################################
     #                          PROCESS INTERNET STUFF                          #
     #        This must be run before "-" is converted into a space, etc.       #
     ############################################################################
     $input_line = &process_internet_stuff($input_line);

     ### VRT-PP was here (400)

     ############################################################################
     #  FIX MISCELLANEOUS PUNCTUATION                                           #
     ############################################################################
     $input_line = &fix_misc_punctuation($input_line);

     ############################################################################
     # EXPAND ABBREVIATIONS IN ORTHOGRAPHIC FORM                                #
     ############################################################################
     $input_line = &expand_abbreviations_ortho($input_line);

     ############################################################################
     # CONVERT NUMERALS TO WORDS                                                #
     ############################################################################
     if ( $numerals_to_words == 1 ) {
          $input_line = &convert_numerals_to_words($input_line);
     }

     # If numeral to word option not selected, turn numbers into a special symbol
     else {
          $input_line =~ s/[0-9]/$num_symbol/g;
     }

     ############################################################################
     #                   CHANGE CERTAIN SYMBOLS TO WORD FORM                    #
     ############################################################################
     $input_line = &change_some_symbols_to_words($input_line);

     ############################################################################
     #  SEARCH AND REPLACE MULTI-WORD PHRASES                                   #
     #  (e.g. "data show", "blue jeans")                                        #
     ############################################################################
     $input_line = &replace_multiword_phrases($input_line);

     ############################################################################
     #                   PRE-PROCESSING: Fix specific rarities                  #
     ############################################################################
     # NOTE Moved from word section (below) to input_line section in 380
     $input_line = &fix_specific_rarities($input_line);

     ############################################################################
     #                   PRE-PROCESSING: Fix odd characters                     #
     ############################################################################
     # NOTE Moved from word section (below) to input_line section in 380
     $input_line = &fix_odd_characters($input_line);

     ############################################################################
     # VRT PRE-PROCESSING                                                       #
     # If reading .vrt text files produced by Connexor, replace <tags>, commas, #
     # periods, etc. with special characters (which will be converted into the  #
     # original Connexor symbols later)                                         #
     ############################################################################
     # WARNING: In 400 moved this from *before* the convert nums to words sub to here
     if ( $vrt_format == 1 ) {
          $input_line = &do_vrt_preprocessing($input_line);

          #print "\nAFT-VRT-PRE-PROCESSING:$input_line\n";    # AD-HOC DEBUG
     }

     ############################################################################
     #                             SPLIT LINES INTO WORDS                       #
     ############################################################################
     @word_array = split / /, $input_line;

     foreach my $word (@word_array) {

          #print "\nBEF-CHANGE-¬-TO-SPACE :$word\n";           # AD-HOC DEBUG

          # Change ¬ to space (for VRT format). If the ¬ is not inserted previously, #
          # then the above split will break up VRT lines into one word per line,     #
          # utterly mangling the output file's line-by-line correspondence to the    #
          # input .vrt file.                                                         #
          $word =~ s/¬/ /g;

          #print "AFT-CHANGE-¬-TO-SPACE :$word\n";           # AD-HOC DEBUG

          #######################################################################
          #                    KILL COMMON WORDS (FOR TESTING)                  #
          #######################################################################
          if ( $kill_common_words == 1 ) {
               $word = &kill_common_words($word);
          }

          #################################################################################
          # HACK:   CLEAN UP WORDS IN THEIR ORTHOGRAPHIC FORM                             #
          #         You can use regular expressions here. At this stage, the words        #
          #         are in orthographic form, and your replacement expressions should     #
          #         be, too. This doesn't allow certain changes -- they're reverted later #
          #         on by the script. To fix those, go to the hacks section at the end.   #
          #################################################################################
          if ( $preclean_orthographic == 1 ) {

               #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
               #    NOTE: The following routine does work, but it's incredibly slow.                     #
               #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
               #               #################################################################################
               #               # REPLACE SINGLE WORDS IN ORTHOGRAPHIC FORM, USING AN EXTERNAL FILE AS SOURCE   #
               #               # FOR S&R ARGUMENTS. Input file must be ISO-8859-1.                             #
               #               #################################################################################
               #               open( WORDSRFILE, '<:encoding(iso-8859-1)', "perkins-reemplazar-palabras.ini" );
               #
               #               #print STDOUT "\n*** Orthographic S&R file (perkins-reemplazar-palabras.ini) successfully read. ***\n\n";
               #
               #               while (<WORDSRFILE>) {
               #                    chomp;
               #                    $sr_input_line = lc;
               #
               #                    # Reduce all whitespace to a single tab
               #                    $sr_input_line =~ s/(\W+)/\t/g;
               #
               #                    # Extract from each line the expected two arguments, separated by whitespace: search arg + replace arg.
               #                    my ( $search_arg, $repl_arg ) = split /\t/, $sr_input_line;
               #
               #                    # Do the actual searching and replacing.
               #                    $word =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)$search_arg($|\.|,|:|;|"|-|‖|\]|\)|\})/$1$repl_arg$2/g;
               #               }
               #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#

               ##################################################################
               #              MODIFY SINGLE WORDS IN ORTHOGRAPHIC FORM          #
               ##################################################################
               $word = modify_single_ortho_words($word);

			######################################################################
			# DANGER NEW in 104!                                                 #
			#         PRE-PROCESSING: Convert double (or more) vowels to singles #
			######################################################################
			$word = &double_vowels_to_single_vowels($word);

               ##################################################################
               #                      SPELL OUT SINGLE LETTERS                  #
               ##################################################################
               $word = spell_out_single_letters($word);

               ##################################################################
               #                       FIX LETTER PATTERNS                      #
               ##################################################################
               $word = fix_letter_patters($word);

               #print "PRECLEAN-ORTHO-AFT   :$word:\n";    # AD-HOC DEBUG

          }

          #######################################################################
          #                                                                     #
          #                     BROAD (PHONEMIC) TRANSCRIPTION                  #
          #                                                                     #
          #######################################################################

          #######################################################################
          # CONVERT PUNCTUATION TO PAUSES                                       #
          #######################################################################
          $word = convert_punctuation_to_pauses($word);

          #print "CNVRT-PUNCT-TO.PAUSES:$word:\n";    # AD-HOC DEBUG

          #print "AFT-CNVT-PUNCT-PAUSES :$word\n";    # AD-HOC DEBUG

          ############################################################################
          # CONVERT (MOST) GRAPHEMES TO INTERMEDIATE REPRESENTATIONS OF PHONEMES     #
          ############################################################################
          $word = convert_graphemes_to_interm_phonemes($word);

          ############################################################################
          #     CHANGE INTERMEDIATE REPRESENTATIONS OF PHONEMES TO THEIR DEFINITIVE  #
          #                        **ONE-CHARACTER** FORMS                           #
          ############################################################################
          $word = change_interm_phonemes_to_one_char($word);

          #print "CHNG-INTERM-PHNM-1CHR:$word:\n";    # AD-HOC DEBUG

          ############################################################################
          #                           PROCESS DIPHTHONGS                             #
          #           /j/ and /w/ are used as intermetiate representations of        #
          #                           non-syllabic vowels                            #
          ############################################################################
          $word = process_diphthongs($word);

          ###############################################################################
          #                                                                             #
          #                   STRESS ACCENT ROUTINE - PREPARATION                       #
          #                                                                             #
          ###############################################################################
          # NOTE: This section need to be *here*, before tildes are removed from vowels.#
          ###############################################################################
          if ( $vrt_format == 0 ) {
               $word = stress_accent_routine($word);
          }
          else {    # Process VRT Files. WARNING: New in 400

               ############################################################################
               # Split each line (utterance) into individual words if VRT format is used. #
               # Multi-word lines are (mainly, if not exclusively) generated by the       #
               # numbers > words routine; the Connexor files fed into VRT are strictly    #
               # one word per line.                                                       #
               ############################################################################
               my @current_segments = split /\s/, $word;

               foreach my $current_segment (@current_segments) {
                    $current_segment = stress_accent_routine($current_segment);
               }

               $word = join( " ", @current_segments );

               #$temp = Encode::encode_utf8( $word );          # AD-HOC DEBUG
               #print STDOUT "AFT-SPLIT-VRT-LINES2WD:$temp\n";    # AD-HOC DEBUG

          }

          ############################################################################
          #                FINAL TOUCHES TO THE BROAD TRANSCRIPTION                  #
          ############################################################################
          $word = final_touches_broad_transcr($word);

          #$temp = Encode::encode_utf8( $word );
          #print STDOUT "AFT-FINAL-TCH-BRD-TR  :$temp\n";           # AD-HOC DEBUG

          ############################################################################
          #                           PERFORM SYLLABIFICATION                        #
          #    If there are any, they supercede both the defaults and the .ini file  #
          ############################################################################
          $word = perform_syllabification($word);

          #$temp = Encode::encode_utf8( $word );                 # AD-HOC DEBUG
          #print STDOUT "AFT-PERFORM-SYLLABIFIC:$temp\n";           # AD-HOC DEBUG

          # Remove spurious syllabification dots inserted at beginning of words #
          # when a "word" is actually a phrase (FOR .VRT FORMAT)            #
          if ( $vrt_format == 1 ) {
               $word =~ s/ \./ /g;

               #$temp = Encode::encode_utf8( $word );                 # AD-HOC DEBUG
               #print STDOUT "AFT-PERFORM-SYLLABIFIC:$temp\n";           # AD-HOC DEBUG
          }

          #print STDOUT "AFT-PERFORM-SYLLABIFIC :$word\n";           # AD-HOC DEBUG

          if ( $debug_syllab_sub == 1 ) {
               print STDOUT "\t\$word = $word";    # NOTE DEBUG
          }


          ############################################################################
          # CONVERT BACKCHANNEL VOCALIZATIONS (MM, HM, EH...) TO UNICODE IPA         #
          #                         DANGER! WARNING! NEW IN 102. +++++               #
          ############################################################################
          $word = convert_backchannel_vocalizations($word);


          #################################################################################
          #                                ==OPTIONAL==                                   #
          #              CONVERT VOWELS WITH TILDES INTO NORMAL VOWELS WITH IPA           #
          #           STRESS ACCENT APOSTROPHES AT THE BEGINNING OF THEIR SYLLABLE        #
          #                             ( es.tá > es.'ta )                                #
          #################################################################################
          if ( $stress_using_tildes == 0 ) {
               $word = opt_tildes_to_ipa_apostrophes($word);
          }

          #######################################################################
          #           REPRESENT PHONEME "YE" AS FRICATIVE (ʝ) (OPTIONAL)        #
          #######################################################################
          if ( $ye_phoneme_is_fricative == 1 ) {
               $word =~ s/ʤ/ʝ/g;
          }

          #######################################################################
          #                             ==OPTIONAL==                            #
          #                  USE MULTI-CHARACTER PHONEME SYMBOLS                #
          #                   ( ʧ > t̠͡ʃ,   ʤ > d̠͡ʒ,  etc. )                   #
          #######################################################################
          if ( $multichars == 1 ) {
               $word = opt_use_multichars($word);
          }

          #######################################################################
          #                   OPTIONAL PHONEME TRANSFORMATIONS                  #
          #######################################################################
          $word = opt_phoneme_transforms($word);

          #######################################################################
          #                                                                     #
          #                    OUTPUT FORMAT TRANSFORMATIONS                    #
          #                                                                     #
          #######################################################################

          #######################################################################
          # IF SELECTED, CONVERT PHONEMES TO C OR V                             #
          #######################################################################
          if ( $output_CV == 1 ) {
               $word = opt_convert_phonemes_cv($word);
          }

          #######################################################################
          # IF SELECTED, CONVERT PHONEMES TO C, V OR G                          #
          #######################################################################
          if ( $output_CVG == 1 ) {
               $word = opt_convert_phonemes_cvg($word);
          }

          #######################################################################
          # IF SELECTED, CONVERT PHONEMES TO C, V, N, L, R OR G                 #
          #######################################################################
          if ( $output_CVNLRG == 1 ) {
               $word = opt_convert_phonemes_cvnlrg($word);
          }

          #######################################################################
          # IF SELECTED, CONVERT PHONEMES TO MANNERS OF ARTICULATION            #
          #######################################################################
          if ( $output_manner == 1 ) {
               $word = opt_convert_phonemes_manners($word);
          }

          #######################################################################
          # IF SELECTED, CONVERT PHONEMES TO PLACES OF ARTICULATION             #
          #######################################################################
          if ( $output_place == 1 ) {
               $word = opt_convert_phonemes_places($word);
          }

          #######################################################################
          # IF SELECTED, CONVERT PHONEMES TO VOICING                             #
          #######################################################################
          if ( $voicing == 1 ) {
               $word = opt_convert_phonemes_voicing($word);
          }

          #######################################################################
          # IMPLEMENT PUNCTUATION > PAUSES                                      #
          #######################################################################
          if ( $ipa_pause_symbols == 1 ) {
               $word = punct_to_pauses_ipa($word);
          }

          # Insert non-IPA pauses: (.) (..) (...) ## ###                        #
          else {
               $word = punct_to_pauses_non_ipa($word);
          }

          ##########################################################################
          # SPLIT AT SYLLABLES: PUT A NEWLINE AT EACH SYLLABLE BOUNDARY IF DESIRED #
          ##########################################################################
          if ( $split_at_syllables == 1 ) {
               $word = opt_split_at_syllables($word);
          }

          #######################################################################
          # ELIMINATE STRESS MARKS IF DESIRED                                   #
          #######################################################################
          if ( $no_stress_marks == 1 ) {
               $word =~ s/ˈ//g;
          }

          #######################################################################
          # CONVERT IPA STRESS MARKS TO ORTHOGRAPHIC APOSTROPHES IF DESIRED     #
          # WARNING NEW IN 376                                                  #
          #######################################################################
          if ( $non_ipa_apostrophes == 1 ) {
               $word =~ s/ˈ/\'/g;    # MAKE SURE THE APOSTROPHE NEEDS TO BE ESCAPED!
          }

          #######################################################################
          # TRY TO ELIMINATE EXTRA SPACES, WHICH SEEM TO CROP UP AFTER THE LAST #
          # IN A SERIES OF NUMBERS THAT ARE AUTO-CONVERTED.                     #
          #######################################################################
          #print STDOUT "word=$word\n"; # AD-HOC DEBUGGING
          $word =~ s/ $//g;
          $word =~ s/^ //g;

          #######################################################################
          # REPLACE .VRT PLACEHOLDERS                                           #
          #######################################################################
          if ( $vrt_format == 1 ) {
               $word = replace_vrt_placeholders($word);
          }

          ############################################################################
          # OUTPUT EACH PROCESSED WORD TO FILE                                       #
          ############################################################################
          if ( $vertical_output == 1 ) {
               print OUTPUTFILE "$word\r\n";    # NOTE New in 333: Changed "$word\n" to "$word\r\n". Otherwise, it doesn't work.
          }
          else { print OUTPUTFILE "$word "; }

     }

     ############################################################################
     # PROCESS PARAGRAPH BREAKS                                                 #
     ############################################################################

     # Add longest pause symbol ("###") if this option is chosen.               #
     if ( $add_paragraph_breaks == 1 ) { print OUTPUTFILE "###"; }

     # Add newlines at paragraph breaks if desired.                             #
     if ( $keep_paragraphs == 1 ) { print OUTPUTFILE "\n"; }

}

#################################################################################
#                                                                               #
#                         CLOSE UP SHOP ON STAGE 1                              #
#                                                                               #
#################################################################################
close(INPUTFILE);
close(OUTPUTFILE);
if ( $use_config_file == 1 ) { close(CONFIGFILE); }

#################################################################################
#                                                                               #
#                                  STAGE 2                                      #
#                  PERFORM OUTPUT FILE CLEANING IF DESIRED                      #
#                     (This should ALWAYS be activated)                         #
#################################################################################
# NEW IN 425: Removed clean_output_file option -- made it mandatory

#################################################################################
#                         Open output and temp files                            #
#################################################################################

# Open the output file. Input must be UTF-8.                                    #
if ( $lang eq "es" ) {
     $user_message = "ADVERTENCIA: No fue posible abrir el archivo de salida \'$output_filename\' para lectura (input) y limpieza adicional.";
}
else {
     $user_message = "WARNING: The output file \'$output_filename\' could not be opened for reading and additional cleaning.";
}

open( OUTPUTFILE, '<:encoding(UTF-8)', "$output_filename" )
  || die "\n\n$user_message\n\n";

#print STDOUT "\n >>> OFC: Opened the file $output_filename to read and then clean it.\n";             # NOTE DEBUGGING

# Open temp file. Output will be UTF-8.                                         #
if ( $lang eq "es" ) {
     $user_message = "ADVERTENCIA: No fue posible crear el archivo temporal \($output_filename\).";
}
else {
     $user_message = "WARNING: The temporary file \'$output_filename\' could not be opened.";
}

open( TEMPFILE, '>:encoding(UTF-8)', "$output_filename\.cleaned" )
  || die "\n\n$user_message\n\n";

#print STDOUT " >>> OFC: Opened the file cleaned-$output_filename to write cleaned text into.\n";      # NOTE DEBUGGING

# Begin processing output file                                                  #
while (<OUTPUTFILE>) {
     chomp;

     # Adjust case as required
     if ( $upper_case == 1 ) {
          $input_line = uc;
     }
     else {
          $input_line = lc;
     }

     # Eliminate extra whitespace                                               #
     $input_line =~ s/\s(\s+)/$1/g;

     ############################################################################
     #                             Clean up pauses                              #
     ############################################################################
     $input_line = &clean_up_pauses($input_line);

     # Print input line to debug log file, if desired.                     #
     if ( $debug == 1 && $debug_to_logfile == 1 ) {
          print LOGFILE "\n==>$input_line";    #AD HOC DEBUG
     }

     # Eliminate underscores (in words ending in "-mente")                 #
     # WARNING Changed this is 363 to include _ adyacent to periods, not   #
     # just to spaces                                                      #
     $input_line =~ s/ _//g;
     $input_line =~ s/ _//g;

     #######################################################################
     #      PERFORM WORD-LEVEL SYLLABIFICATION ADJUSMENTS, IF DESIRED      #
     # This fixes things like "los hombres" = /los om.bres/, instead of    #
     # /lo.som.bres/                                                       #
     #######################################################################
     if ( $syllabify_by_sentence == 1 ) {

          #print STDOUT "\n\n$input_line"; # AD HOC DEBUG
          $input_line = word_level_syllab_adjust($input_line);
     }

     ############################################################################
     #                   PROCESS SYLLABLE DOTS, IF DESIRED                      #
     ############################################################################

     # Convert syllable dots into spaces, if that option is selected       #
     if ( $syllable_dots_are_spaces == 1 ) {
          $input_line =~ s/\./ /g;
     }

     # ELIMINATE SYLLABLE DOTS IF THAT OPTION IS SELECTED                  #
     if ( $insert_syllable_dots == 0 ) {
          $input_line =~ s/\.//g;
     }

     #######################################################################
     # Print each cleaned-up line to the temporary file                    #
     #######################################################################
     print TEMPFILE "$input_line";

}

#################################################################################
#                        Close unneeded files                                   #
#################################################################################
close(OUTPUTFILE);
close(TEMPFILE);

###################################################################################
# Copy temp (cleaned) file on top of partially-finished file and delete temp file #
###################################################################################
copy( "$output_filename\.cleaned", "$output_filename" )
  or die " ***** Copying of cleaned file to output file failed! *****\n";

unlink("$output_filename\.cleaned");    # Deletes de file from disk

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#
# NOTE BEGIN  BLOCK COMMENTING-OUT
# # #
# # #      #################################################################################
# # #      #                                                                               #
# # #      #           CONVERT BROAD TRANSCRIPTION INTO SEMI-NARROW TRANSCRIPTION          #
# # #      #          (WARNING: NOT IMPLEMENTED YET! THIS IS JUST A SKELETON               #
# # #      #################################################################################
# # #      if ( $semi_narrow == 1 ) {
# # #
# # #           # NOTE: DEBUG
# # #           #print STDOUT "====>$allophone_table{bi_na_so}<====\n";     # NOTE Testing to see if hash is read correctly
# # #
# # #           # Open the output file for processing                                      #
# # #           open( INPUTFILE, '<:encoding(UTF-8)', "$output_filename" )
# # #             || die "\n\nCould not open the file $output_filename for reading and semi-narrow transcription!\n\n";
# # #
# # #           # Open the temp file for outputting the processed input                    #
# # #           open( TEMPFILE, '>:encoding(UTF-8)', "$in_basename--semi-narrow.txt" )
# # #             || die "\n\nCould not create the temp file $in_basename--semi-narrow.txt for outputting the semi-narrow transcription!\n\n"
# # #             ;    # Output will be UTF-8
# # #
# # #           # Read input file for processing                                           #
# # #           while (<INPUTFILE>) {
# # #                chomp;
# # #                $input_line = lc;
# # #
# # #                ############################################################################
# # #                #                          SPLIT LINES INTO UTTERANCES                     #
# # #                ############################################################################
# # #                @utterance_array =
# # #                  split /\(\.\)|\(\.\.\)|\(\.\.\.\)|###|##|#|\||‖/, $input_line;
# # #
# # #                foreach $utterance (@utterance_array) {
# # #
# # #                     # Remove spaces from beginning and end of utternaces                  #
# # #                     $utterance =~ s/^ //g;
# # #                     $utterance =~ s/ $//g;
# # #
# # #                     # Convert spaces into syllable breaks                                 #
# # #                     $utterance =~ s/ /\./g;
# # #
# # #                     # Reduce doubled characters to single ones   WARNING This may not always be appropriate
# # #                     $utterance =~ s/(.)\1/$1/g;
# # #
# # #                     # Break utterance up into individual characters
# # #                     @character = split //, $utterance;
# # #
# # #                     # Get the number of characters in utterance
# # #                     my $char_count = @character;
# # #
# # #                     for ( $i = 0 ; $i < $char_count ; $i++ ) {
# # #
# # #                          #+++++                         # In the pattern V.VC. , if the vowels are identical
# # #
# # #                          #                         if ( $character[$i]      =~ m/([aeiou])/
# # #                          #                           && $character[$i+1] =~ m/$1/ ) {
# # #                          #                              splice ( @character, $i+1, 1 );
# # #                          #                         }
# # #                          #
# # #                          #                         # If two identical vowels are contiguous but have a syllable break dot     #
# # #                          #                         # between them, eliminate the first vowel and the dot                      #
# # #                          #                         if ( $character[$i]      =~ m/([aeiou])/
# # #                          #                           && $character[$i+1] eq "."
# # #                          #                           && $character[$i+2] =~ m/$1/ ) {
# # #                          #                              splice ( @character, $i, 2 );
# # #                          #                         }
# # #
# # #                          ############################################################################
# # #                          #    IF THE CHAR IS A SYLLABLE DOT, SET VAR, ERASE DOT, SKIP REST OF LOOP  #
# # #                          ############################################################################
# # #                          if ( $character[ $i + 1 ] eq "." ) {
# # #
# # #                               # Set variable to indicate that this character was a syllable break.  #
# # #                               # This will be used to reinsert the dot after processing.             #
# # #                               $next_char_syl_break = 1;
# # #
# # #                               # Extirpate the dot character's ENTIRE SLOT from the array            #
# # #                               splice( @character, $i + 1, 1 );
# # #                          }
# # #
# # #                          ############################################################################
# # #                          #                                                                          #
# # #                          #                         DO THE ALLOPHONIC PROCESSING                     #
# # #                          #                                                                          #
# # #                          ############################################################################
# # #
# # #                          # Note: Thanks to the magic performed in the previous section, you can     #
# # #                          #       process the characters as if there were never any dots.            #
# # #
# # #                          # Reduce double non-stressed vowels to single ones                         #
# # #                          #if ( $character[$i] =~ m/([aeiou])/
# # #                          #     && $character[ $i + 1 ] =~ m/$1/ ) {
# # #                          #     $character[$i] = "$1" ; #$allophone_table{'gl_fa_af'};
# # #                          #}
# # #
# # #                          # /st/ > /ht/
# # #                          if (    $character[$i] =~ m/s/
# # #                               && $character[ $i + 1 ] =~ m/[bdfkpt]/ )
# # #                          {
# # #                               $character[$i] = $allophone_table{'gl_fa_af'};
# # #                          }
# # #
# # #                          # EXAMPLE CODE TO BE ADAPTED TO ALLOPHONE PROCESSING
# # #                          #                   if (    $character[$i] =~ m/[$all_consonants]/
# # #                          #                    && $character[ $i + 1 ] =~ m/[$all_consonants]/
# # #                          #                    && $character[ $i + 2 ] =~ m/[$all_consonants]/
# # #                          #                    && $character[ $i + 3 ] =~ m/[$all_consonants]/ )
# # #                          #               {
# # #                          #
# # #                          #                    # Add syllable dot
# # #                          #                    $character[ $i + 2 ] = (".$character[$i+2]");
# # #                          #
# # #                          #                    # Increment $i so as not to repeatedly process this cluster
# # #                          #                    $i = $i + 3;
# # #                          #               }
# # #
# # #                          # If the syllable break dot was removed for processing, reinsert it now,   #
# # #                          # after the just-processed character.                                      #
# # #                          if ( $next_char_syl_break == 1 ) {
# # #                               $character[$i] = "$character[$i].";
# # #                               $next_char_syl_break = 0;    # RESET variable.
# # #                          }
# # #
# # #                     }
# # #
# # #                     $utterance = join( "", @character );    # May have to go inside previous brace
# # #
# # #                     print TEMPFILE "$utterance\n\n";
# # #                }
# # #           }
# # #      }
# NOTE END BLOCK COMMENTING-OUT

#################################################################################
# Print final message telling what file the transcription is in                 #
#################################################################################
if ( $batch_mode == "0" ) {

     if ( $lang eq "es" ) {
          $user_message = "La transcripción se guardó en el archivo UTF-8 \"$output_filename\".";
     }
     else {
          $user_message = "The transcription was saved in the UTF-8 file \"$output_filename\".";
     }

     print STDOUT "\n$user_message\n\n";
}

#################################################################################
#                                  Exit program                                 #
#################################################################################
exit;

#                                                                               #
#                                                                               #
#                                                                               #
#                                                                               #
#                            SUBROUTINES LIVE HERE...                           #
#                                                                               #
#                                                                               #
#                                                                               #
#                                                                               #

###############################################################################
#                SUBROUTINE: CONFIG FILE COULDN'T BE OPENED                   #
# NOTE: Must define lang strings HERE, and not in subroutine.                 #
###############################################################################
sub config_file_failed {

     if ( $lang eq "es" ) {
          $user_message = "ADVERTENCIA: No fue posible abrir el archivo de configuración (perkins.ini).";
     }
     else {
          $user_message = "WARNING: The configuration file (\'perkins.ini\') could not be opened.";
     }

     # Notify user that config file could NOT be opened.
     if ( ( $debug_to_logfile == 0 ) && ( $silent_mode == 0 ) ) {
          print STDOUT "\n\n$user_message\n";
     }
     elsif ( $debug_to_logfile == 1 ) {
          print LOGFILE "\n\n$user_message\n";
     }
     $config_file_present = 0;
}

###############################################################################
#                        SUBROUTINE: VERIFY CLI OPTIONS                       #
###############################################################################
sub verify_cli_options {

     # Make sure an input file was given, else die.
     if ( $input_filename eq "" ) {

          if ( $lang eq "es" ) {
               $user_message = "ERROR: Debes proporcionar el nombre del archivo a procesar. Esto se hace con la opción \'-i=input.txt\'";
          }
          else {
               $user_message = "ERROR: You must specify the name of the file to be processed with the -i flag (\'-i=input.txt\')";
          }

          &print_info_header;

          die "\n$user_message\n\n";
     }

     # TODO: Die when a non-existent option is provided

}

###############################################################################
#                        SUBROUTINE: HELP SECTION                             #
###############################################################################
sub print_help {

     &print_info_header;

     binmode STDOUT, ":utf8";
     if ( $lang eq "es" ) {

          print STDOUT "OPCIONES PRINCIPALES:";
          print STDOUT "\n -i, --input=MiArchivo.txt    Especificar el archivo que se transcribirá.";
          print STDOUT "\n                                ESTE PARÁMETRO ES OBLIGATORIO.";
          print STDOUT "\n -o, --output=MiTranscr.txt   Especificar el archivo en el que se guardará";
          print STDOUT "\n                                la transcripción. Si no se especifica, se";
          print STDOUT "\n                                creará un archivo con el mismo nombre que el";
          print STDOUT "\n                                de entrada, pero con la extensión \".phnm\".";
          print STDOUT "\n";
          print STDOUT "\n NOTA: Si contienen espacios, los nombres de archivos deben ir entre comillas.";
          print STDOUT "\n";
          print STDOUT "\n -h, --help                   Ver la ayuda de Perkins.";
          print STDOUT "\n -u, --uso                    Ver ejemplos del uso de Perkins.";
          print STDOUT "\n -cfg, -ini                   Usar el archivo de configuración (perkins.ini).";
          print STDOUT "\n -nocfg, -noini               NO usar el archivo de configuración.";
          print STDOUT "\n -b, -batch                   Ejecutar Perkins en modo batch (lotes). No envia";
          print STDOUT "\n                                 mensajes a STDOUT en este caso.";
          print STDOUT "\n -sil, --silent-mode          Modo silencioso. Se suprime todo mensaje y archivo";
          print STDOUT "\n                                de registro (incluyendo los de errores).";
          print STDOUT "\n -l, --lang [en|es]           Seleccionar el idioma de la interfaz de Perkins";
          print STDOUT "\n                                (\"es\" para español; \"en\" para inglés).";
          print STDOUT "\n -en                          Seleccionar la interfaz en inglés.";
          print STDOUT "\n -es                          Seleccionar la interfaz en español.";
          print STDOUT "\n -d, --debug                  Proporcionar información de debugging";
          print STDOUT "\n -dl, --debug-log             Guardar la información de debugging en un archivo";
          print STDOUT "\n                                de registro (termina en .log).";
          print STDOUT "\n";
          print STDOUT "\nOPCIONES DE MODO DE TRANSCRIPCIÓN:";
          print STDOUT "\n -f=, --formato=MODO          Especificar el modo o formato de la transcripción.";
          print STDOUT "\n                                NO distingue mayúsculas de minúsculas. Las";
          print STDOUT "\n                                posibilidades son las siguientes:";
          print STDOUT "\n";
          print STDOUT "\n                                   F        (transcripción fonémica)";
          print STDOUT "\n                                   CV       (consonante/vocal)";
          print STDOUT "\n                                   CVG      (consonante/vocal/glide)";
          print STDOUT "\n                                   CVN      (cons/vocal/nasal/líqida/rótica/glide)";
          print STDOUT "\n                                   M, MODO  (modo de articulación)";
          print STDOUT "\n                                   P, PUNTO (punto de articulación)";
          print STDOUT "\n                                   S, SON   (sonoridad)";
          print STDOUT "\n";
          print STDOUT "\nOPCIONES PARA DETERMINADOS FONEMAS:";
          print STDOUT "\n -multi, -ms                 Usar múltiples símbolos AFI para algunos fonemas.";
          print STDOUT "\n -och                        Representar el fonema \"ch\" como /ʧ/ independiente de";
          print STDOUT "\n                               cualquier otra configuración.";
          print STDOUT "\n -tg                         Tratar /tr/ como fonema (usar ligadura o representarlo";
          print STDOUT "\n                                como fricativa retrofleja /ʂ/).";
          print STDOUT "\n -yf                         Representar el fonema \"ye\" como fricativa /ʝ/.";
          print STDOUT "\n -ya                         Representar el fonema \"ye\" como africada /d͡ʒ/.";
          print STDOUT "\n -oye                        Representar el fonema \"ye\" como /ʝ/ independiente de";
          print STDOUT "\n                               cualquier otra configuración.";
          print STDOUT "\n -ar                         Usar diacrítico \"retraído\" en algunas africadas";
          print STDOUT "\n                             (e.g. /t̠͡ʃ/).";
          print STDOUT "\n -lig                        Usar ligaduras en /t͡ʃ/ y /d͡ʒ/. \'-nolig\' impide su uso.";
          print STDOUT "\n                               Debe usarse con la opción \'-mc\'!";
          print STDOUT "\n -dd, --dent                 Usar diacrítico dental con /t/ y /d/. Debe usarse con \'-mc\'!";
          print STDOUT "\n -age                        Agregar [g] epentética antes de /w/ (e.g. <hueco> > [gweko].";
          print STDOUT "\n";
          print STDOUT "\nOPCIONES PARA  GLIDES (SEMIVOCALES):";
          print STDOUT "\n -gd, --glides-dia           Representar glides como vocal + diacrítico \"no silábico\".";
          print STDOUT "\n -nogd, --noglides-dia       Representar glides como /j/ o /w/.";
          print STDOUT "\n -wv                         Representar wau con u + diacrítico \"no silábico\".";
          print STDOUT "\n -yv                         Representar yod con i + diacrítico \"no silábico\".";
          print STDOUT "\n";
          print STDOUT "\nOPCIONES DE ACENTUACIÓN:";
          print STDOUT "\n -at                         Representar el acento con tilde en vez del apóstrofo AFI.";
          print STDOUT "\n -ao                         Representar el acento con un apóstrofo ortográfico (no AFI).";
          print STDOUT "\n";
          print STDOUT "\nOPCIONES DE SILABIFICACIÓN:";
          print STDOUT "\n -sp, --sil-puntos           Representar las divisiones silábicas con puntos.";
          print STDOUT "\n -se, --sil-esp              Representar las divisiones silábicas con espacios.";
          print STDOUT "\n -nosd                       No representar las divisiones silábicas.";
          print STDOUT "\n -spe                        Silabificar por enunciado/oración, y no por palabra (\"los";
          print STDOUT "\n                               hombres\" > /lo.som.bres/ en vez de /los om.bres/).";
          print STDOUT "\n -nospe                      Silabificar por palabra, y no por enunciado/oración (\"los";
          print STDOUT "\n                               hombres\" > /los om.bres/ en vez de /lo.som.bres/).";
          print STDOUT "\n";
          print STDOUT "\nOPCIONES PARA LAS PAUSAS:";
          print STDOUT "\n -pi, --pausas-afi           Representar pausas con los símbolos AFI | y ‖";
          print STDOUT "\n -pl2                        Representar la pausa larga con dos barras de pausa corta (||) en"; # MUST-DOCUMENT-ON-WEBPAGE
          print STDOUT "\n                               vez de una sola barra doble (‖), la cual no puede verse en Praat.";
          print STDOUT "\n -pco                        Tratar comas como pausas.";
          print STDOUT "\n -pdp                        Tratar el símbolo : como pausa.";
          print STDOUT "\n -ppc                        Tratar el símbolo ; como pausa.";
          print STDOUT "\n -por                        Mantener divisiones entre oraciones.";
          print STDOUT "\n -ppa                        Mantener divisiones entre párrafos.";
          print STDOUT "\n -pel                        Tratar elipsis (...) como pausa.";
          print STDOUT "\n -pcr                        Convertir corchetes [] en pausas.";
          print STDOUT "\n -ppn                        Convertir parénthesis en pausas.";
          print STDOUT "\n";
          print STDOUT "\nSUSTITUCIONES: ";
          print STDOUT "\n -nap                   Convertir numerales en palabras (\"4\" > \"cuatro\").";
          print STDOUT "\n -sn=SIMBOLO            Reemplazar números por el símbolo que se especifica aquí.";
          print STDOUT "\n -mon=TEXTO             Reemplazar el símbolo \"$\" por lo que se especifica como TEXTO.";
          print STDOUT "\n -sl=TEXTO              Reemplazar el símbolo \"/\" por lo que se especifica como TEXTO.";
          print STDOUT "\n -nma                   No marcar el acento tónico.";
          print STDOUT "\n -pu                    Procesar los URL lingüísticamente. De lo contrario, se suprimen";
          print STDOUT "\n -pe                    Procesar las direcciones de e-mail lingüísticamente.";
          print STDOUT "\n                          De lo contrario, éstas se suprimen.";
          print STDOUT "\n";
          print STDOUT "\nOPCIONES DE PRESENTACIÓN:";
          print STDOUT "\n -upl                   Una palabra por línea (dividir en palabras).";
          print STDOUT "\n -usl                   Una sílaba por línea (dividir en sílabas).";
          print STDOUT "\n -mp                    Mantener la separación de párrafos. De lo contrario";
          print STDOUT "\n                          la transcripción será un solo gran muro de texto.";
          print STDOUT "\n -epc                    Eliminar palabras comunes (para fines de testeo).";
          print STDOUT "\n";
          print STDOUT "\nOPCIONES PARA NÚMEROS:";
          print STDOUT "\n -rae                   Procesar dos grupos de 4 dígios con \"-\" entre medio como un rango";
          print STDOUT "\n                          de años (\"1900-2000\" > \"1900 a 2000\" y no \"1900 menos 2000\").";
          print STDOUT "\n -raa                   Procesar dos grupos de 1-4 dígitos con \"-\" entre medio";
          print STDOUT "\n                          como un rango de años (43-103 > 43 a 103).";
          print STDOUT "\n -tra                   Procesar todos los grupos de 1-4 dígitos con un \"-\" entre medio como";
          print STDOUT "\n                          como un rango de años.";
          print STDOUT "\n -aac                   Procesar también los años A.C.";
          print STDOUT "\n";
          print STDOUT "\nMETACONFIGURACIONES:";
          print STDOUT "\n -tc, --corpus          Configuración para procesar un corpus como texto corrido";
          print STDOUT "\n -ls, --lista-sil       Configuración para generar transcripciones que.";
          print STDOUT "\n                          pueden procesarse fácilmente a nivel de sílaba.";
          print STDOUT "\n -vrt                   Configuración para generar archivos verticales (.vrt)";
          print STDOUT "\n                          compatibles con IMS CWB. No puede realizar todos los";
          print STDOUT "\n                          análisis (e.g. expansión de abreviaturas).";
          print STDOUT "\n -lp, --lista-pal       Configuración que trata el texto como una lista de";
          print STDOUT "\n                          palabras: silabiza a nivel de palabra en vez de";
          print STDOUT "\n                          enunciado.";
          print STDOUT "\n -csc, --coscach        Configuación para procesar transcripciones del Coscach.";
          print STDOUT "\n";
          print STDOUT "\nNOTA: A la mayoría de las opciones que no toman un argumento (es decir, las opciones";
          print STDOUT "\n      binarias), se les puede agregar \"no\" entre el guión y la opción misma para";
          print STDOUT "\n      producir el efecto contrario: --nomulti, --nodebug, -notrg, --nod, etc.";
          print STDOUT "\n";
          print STDOUT "\n";
     }
     else {

          print STDOUT "MAIN OPTIONS:";
          print STDOUT "\n -i, --input=MyFile.txt       Specify the file to be processed. MANDATORY.";
          print STDOUT "\n -o, --output=Transcr.txt     Specify the file in which to save Perkins' output.";
          print STDOUT "\n                                If not specified, a name will be automatically";
          print STDOUT "\n                                generated using the input file basename and an";
          print STDOUT "\n                                appropriate extension (e.g. \'.phnm\').";
          print STDOUT "\n";
          print STDOUT "\n NOTE: If filenames contain spaces, they must be enclosed in quotation marks.";
          print STDOUT "\n";
          print STDOUT "\n -h, --help                   Show this help information.";
          print STDOUT "\n -u, --usage                  Show usage information and examples.";
          print STDOUT "\n -cfg, -ini                   Use the configuration file (perkins.ini).";
          print STDOUT "\n -nocfg, -noini               DON'T use the configuration file.";
          print STDOUT "\n -b, --batch,                 Run Perkins in batch mode: suppresses all messages";
          print STDOUT "\n                                to the command line.";
          print STDOUT "\n -sm, --silent-mode           Silent mode. Suppresses all messages and logging";
          print STDOUT "\n                                (including error messages).";
          print STDOUT "\n -l, --lang [en|es]           Select Perkins' interface language (\"es\" for Spanish;";
          print STDOUT "\n                                \"en\" for English).";
          print STDOUT "\n -en                          Set interface language to English.";
          print STDOUT "\n -es                          Set interface language to Spanish.";
          print STDOUT "\n -d, --debug                  Show debugging information.";
          print STDOUT "\n -dl, --debug-log             Save debugging information to a log file (same name";
          print STDOUT "\n                                as input file, but with \".log\" extension).";
          print STDOUT "\n";
          print STDOUT "\nTRANSCRIPTION MODE OPTIONS:";
          print STDOUT "\n -f=, --format=MODE           Specify the transcription mode or format. NOT case-sensitive.";
          print STDOUT "\n                              The possible formats are:";
          print STDOUT "\n                                   PH        (phonemic transcription)";
          print STDOUT "\n                                   CV        (consonant/vowel transcription)";
          print STDOUT "\n                                   CVG       (consonant/vowel/glide transcription)";
          print STDOUT "\n                                   CVN       (cons/vowel/nasal/liquid/rhotic/glide)";
          print STDOUT "\n                                   M, MANNER (manner of articulation)";
          print STDOUT "\n                                   P, PLACE  (place of articulation)";
          print STDOUT "\n                                   V         (voicing)";
          print STDOUT "\n";
          print STDOUT "\nSPECIFIC PHONEME OPTIONS:";
          print STDOUT "\n -multi, -mc            Use multi-character IPA symbols for some phonemes.";
		print STDOUT "\n -och                   Represent the \"ch\" phoneme as /ʧ/ regardless of any other setting";
          print STDOUT "\n -tg                    Treat /tr/ as a single phoneme (use ligature or";
          print STDOUT "\n                          represent it as voiceless retroflex fricative /ʂ/).";
          print STDOUT "\n -yf                    Represent the \"ye\" phoneme as a fricative /ʝ/.";
          print STDOUT "\n -ya                    Represent the \"ye\" phoneme as an affricate /d͡ʒ/.";
          print STDOUT "\n -oye                   Represent the \"ye\" phoneme as /ʝ/ regardless of any other setting";
          print STDOUT "\n -ar                    Use the \"retracted\" diacritic in some affricates (e.g. t̠͡ʃ).";
          print STDOUT "\n -lig                   Use ligatures in /t͡ʃ/ and /d͡ʒ/. \'-nolig\' prevents their use.";
          print STDOUT "\n                         Must be used in conjunctin with the \'-mc\' switch!";
          print STDOUT "\n -dd, --dent            Use dental diacritic with /t/ and /d/. Must use with \'-mc\'!";
          print STDOUT "\n -aeg                   Add epenthetic [g] before /w/ (e.g. <hueco> > [gweko].";
          print STDOUT "\n";
          print STDOUT "\nGLIDE OPTIONS:";
          print STDOUT "\n -gd, --glides-dia      Represent glides as vowel + the \"non-syllabic\" diacritic.";
          print STDOUT "\n -nogd, --noglides-dia  Represent glides as  /j/ and /w/.";
          print STDOUT "\n -wv                    Represent wau as u + the \"non-syllabic\" diacritic.";
          print STDOUT "\n -yv                    Represent yod as i + the \"non-syllabic\" diacritic.";
          print STDOUT "\n";
          print STDOUT "\nSTRESS OPTIONS:";
          print STDOUT "\n -st                    Mark stress with tilde over vowel rather than IPA apostrophe.";
          print STDOUT "\n -oa                    Mark stress with orthographic apostrophe, rather than the IPA one.";
          print STDOUT "\n";
          print STDOUT "\nSYLLABIFICATION OPTIONS:";
          print STDOUT "\n -sd, --syl-dots        Represent syllable divisions with periods.";
          print STDOUT "\n -ss, --syl-spaces      Represent syllable divisions with spaces.";
          print STDOUT "\n -nosd                  Do not separate syllables nor mark them in any way.";
          print STDOUT "\n -sbu                   Syllabify by utterance/sentence, not by word (\"los";
          print STDOUT "\n                          hombres\" becomes /lo.som.bres/ instead of /los om.bres/).";
          print STDOUT "\n -nosbu                 Syllabify by word, not by utterance/sentence (\"los";
          print STDOUT "\n                          hombres\" > /los om.bres/ instead of /lo.som.bres/).";
          print STDOUT "\n";
          print STDOUT "\nPAUSE AND GROUP OPTIONS:";
          print STDOUT "\n -ip, --ipa-pauses      Represent pauses with the IPA symbols | and  ||";
          print STDOUT "\n -lp2                   Represent long pauses with two short pause bars (||) instead of one"; # MUST-DOCUMENT-ON-WEBPAGE
          print STDOUT "\n                          long pause double bar (‖), which Praat can't display.";
          print STDOUT "\n -cmp                   Treat commas as pauses.";
          print STDOUT "\n -clp                   Treat colons as pauses.";
          print STDOUT "\n -scp                   Treat  semicolons as pauses.";
          print STDOUT "\n -snp                   Treat sentence breaks as pauses.";
          print STDOUT "\n -ppp                   Treat paragraph breaks as pauses.";
          print STDOUT "\n -elp                   Treat ellipses (...) as pauses.";
          print STDOUT "\n -brp                   Treat brackets [] as pauses.";
          print STDOUT "\n -pnp                   Treat parentheses as pauses.";
          print STDOUT "\n";
          print STDOUT "\nSUBSTITUTION OPTIONS: ";
          print STDOUT "\n -n2w                     Convert numerals into word form (\"4\" > \"cuatro\").";
          print STDOUT "\n -sn=SYMBOL               Replace numerals with the symbol specified here.";
          print STDOUT "\n -cur=TEXT                Replace the \"$\" symbol with the text specified here.";
          print STDOUT "\n -sl=TEXT                 Replace the \"/\" symbol with the text specified here.";
          print STDOUT "\n -nsm, --no-stress-marks  Do not indicate stress in any way.";
          print STDOUT "\n -pu                      Treat URLs as linguistic items. Otherwise, they're deleted";
          print STDOUT "\n -pe                      Treat e-mail addresses as linguistic items. Otherwise, they're";
          print STDOUT "\n                            deleted.";
          print STDOUT "\n";
          print STDOUT "\nPRESENTATION OPTIONS:";
          print STDOUT "\n -owl                   One word per line (split at words).";
          print STDOUT "\n -osl                   One syllable per line (split at syllables).";
          print STDOUT "\n -kp                    Keep paragraph breaks. Otherwise, output will be a wall of text.";
          print STDOUT "\n -kc                    Eliminate common words (for testing purposes).";
          print STDOUT "\n";
          print STDOUT "\nNUMBER PROCESSING OPTIONS:";
          print STDOUT "\n -nyr                   Treat two groups of 4 digits separated by \"-\" as a range of";
          print STDOUT "\n                          years (\"1900-2000\" > \"1900 a 2000\", not \"1900 menos 2000\").";
          print STDOUT "\n -byr                   Treat two groups of 1 to 4 digits separated by \"-\" as a range of";
          print STDOUT "\n                          years (\"43-103\" > \"43 a 103\", not \"43 menos 103\").";
          print STDOUT "\n -ayr                   Treat ALL groups of 1 to 4 digits separated by a \"-\" as ranges of years.";
          print STDOUT "\n -bcy                   Also process BCE years.";
          print STDOUT "\n";
          print STDOUT "\nMETA-CONFIGURATIONS:";
          print STDOUT "\n -rt, --corpus          For processing corpora of running text.";
          print STDOUT "\n -sl, --syl-list        For creating transcriptions that permit easy processing at the";
          print STDOUT "\n                          syllable level.";
          print STDOUT "\n -vrt                   For processing verticalized text (one word per line of input). Can't";
          print STDOUT "\n                         perform all analyses (e.g. expanding abbreviations).";
          print STDOUT "\n -wl, --word-list       For processing word lists (syllabifies at word level, not sentence level).";
          print STDOUT "\n -csc, --coscach        For processing Coscach transcriptions.";
          print STDOUT "\n";
          print STDOUT "\n";
          print STDOUT "\nNOTE: Most options that don't take an argument (i.e. binary options) can be reversed or negated by adding";
          print STDOUT "\n      \"no\" between the dash and the option itself (e.g. --nomulti, --nodebug, -notr, -nod).";
          print STDOUT "\n";
          print STDOUT "\n";

     }
}

#################################################################################
#                        SUBROUTINE: USAGE SECTION                              #
#################################################################################
sub print_usage {

     &print_info_header;

     binmode STDOUT, ":utf8";

     if ( $lang eq "es" ) {
          print STDOUT "                             GUÍA DE USO";
          print STDOUT "\n     Perkins ofrece gran cantidad de opciones para la transcripción.";
          print STDOUT "\n         A continuación, se presentan algunas de las más útiles";
          print STDOUT "\n";
          print STDOUT "\nNOTAS GENERALES:";
          print STDOUT "\n - Las opciones se pueden ingresar con \"-\" o \"--\", indistintamente.";
          print STDOUT "\n - El uso del símbolo \'=\' es optativo.";
          print STDOUT "\n - El orden de las opciones y de los nombres de archivos no tiene importancia.";
          print STDOUT "\n - Las opciones binarias pueden invertirse agregando \'no\' entre el guión";
          print STDOUT "\n     y la opción misma (e.g. \'-mc\' puede desactivarse con \'-nomc\').";
          print STDOUT "\n - El número de opciones que se pueden utilizar no tiene límite.";
          print STDOUT "\n - Si el nombre de un archivo contiene un espacio, debe ir entre comillas.";
          print STDOUT "\n - Si no se especifica un archivo de salida, se genera un nombre automáticamente";
          print STDOUT "\n     a partir del nombre del archivo fuente y según el modo de transcripción.";
          print STDOUT "\n";
          print STDOUT "\nSELECCIÓN DE UN MODO DE TRANSCRIPCIÓN:";
          print STDOUT "\n - El modo de la transcripción puede elegirse desde la línea de comandos de";
          print STDOUT "\n   dos maneras distintas: -f=MODO y -MODO.";
          print STDOUT "\n - Modos válidos: F, CV, CVG, CVN, M, P, S. Para más información, ver abajo.";
          print STDOUT "\n";
          print STDOUT "\n                           EJEMPLOS DE USO:";
          print STDOUT "\n";
          print STDOUT "\nTEXTO FUENTE: En Concepción, se trata de aguantar la lluvia durante 5";
          print STDOUT "\n              meses del año. ¿Cachái?";
          print STDOUT "\n";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMANDO:      $progname -i=fuente.txt";
          print STDOUT "\n";
          print STDOUT "\nSALIDA:       en.kon.sep.ˈsjon | se.ˈt̪ɾa.t̪a.d̪e.a.gwan.ˈt̪aɾ.la.ˈʝu.bja.";
          print STDOUT "\n              d̪u.ˈɾan.t̪e.ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo ‖ ka.ˈt͡ʃaj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPCIÓN:  Opciones preconfiguradas. Transcripción fonémica. Africadas con";
          print STDOUT "\n              ligadura. Yod y wau son /j/ y /w/. Apóstrofo AFI. Dentales con";
          print STDOUT "\n              diacrítico. Símbolos de múltiples caracteres (t͡ʃ). Procesamiento";
          print STDOUT "\n              a nivel de enunciado. Fonema \"ye\" es /ʝ/.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMANDO:      $progname -i=fuente.txt -at";
          print STDOUT "\n";
          print STDOUT "\nSALIDA:       en.kon.sep.sjón | se.t̪ɾá.t̪a.d̪e.a.gwan.t̪áɾ.la.ʝú.bja.d̪u.ɾán.t̪e.sín.";
          print STDOUT "\n              ko.mé.ses.d̪e.lá.ɲo ‖ ka.t͡ʃáj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPCIÓN:  El acento tónico se señala con tildes sobre las vocales tónicas";
          print STDOUT "\n              en vez de apóstrofos AFI.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMANDO:      $progname -i=fuente.txt -ya";
          print STDOUT "\n";
          print STDOUT "\nSALIDA:       en.kon.sep.ˈsjon | se.ˈt̪ɾa.t̪a.d̪e.a.gwan.ˈt̪aɾ.la.ˈd͡ʒu.bja.d̪u.ˈɾan.";
          print STDOUT "\n              t̪e.ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo ‖ ka.ˈt͡ʃaj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPCIÓN:  El fonema \"ye\" se representa como la africada /d͡ʒ/.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMANDO:      $progname -i=fuente.txt -ya -ar";
          print STDOUT "\n";
          print STDOUT "\nSALIDA:       en.kon.sep.ˈsjon | se.ˈt̪ɾa.t̪a.d̪e.a.gwan.ˈt̪aɾ.la.ˈd̠͡ʒu.bja.d̪u.ˈɾan.";
          print STDOUT "\n              t̪e.ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo ‖ ka.ˈt̠͡ʃaj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPCIÓN:  Se utiliza el diacrítico \"retraído\" en la representación de las";
          print STDOUT "\n              dos africados (/d̠͡ʒ/ y /t̠͡ʃ/).";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMANDO:      $progname -i=fuente.txt -ya -tg";
          print STDOUT "\n";
          print STDOUT "\nSALIDA:       en.kon.sep.ˈsjon | se.ˈt̪͡ɾa.t̪a.d̪e.a.gwan.ˈt̪aɾ.la.ˈd͡ʒu.bja.d̪u.ˈɾan.";
          print STDOUT "\n              t̪e.ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo ‖ ka.ˈt͡ʃaj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPCIÓN:  Se trata el grupo \"tr\" como fonema (tal como se comporta en";
          print STDOUT "\n              muchos hablantes chilenos).";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMANDO:      $progname -i=fuente.txt -ya -tg -nomc";
          print STDOUT "\n";
          print STDOUT "\nSALIDA:       en.kon.sep.ˈsjon | se.ˈʂa.ta.de.a.gwan.ˈtaɾ.la.ˈʤu.bja.du.ˈɾan.te.";
          print STDOUT "\n              ˈsin.ko.ˈme.ses.de.ˈla.ɲo ‖ ka.ˈʧaj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPCIÓN:  Los fonemas se representan con símbolos de un solo carácter (/ʤ/; ";
          print STDOUT "\n              /ʧ/; /ʂ/ en vez de /t̪͡ɾ/), salvo los glides, que pueden configurarse";
          print STDOUT "\n              por separado con \'-gd\' y \'-nogd\'.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMANDO:      $progname -i=fuente.txt -gd";
          print STDOUT "\n";
          print STDOUT "\nSALIDA:       en.kon.sep.ˈsi̯on | se.ˈt̪ɾa.t̪a.d̪e.a.gu̯an.ˈt̪aɾ.la.ˈʝu.bi̯a.d̪u.ˈɾan.t̪e.";
          print STDOUT "\n              ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo ‖ ka.ˈt͡ʃai̯";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPCIÓN:  Representar los glides (semivocales) como vocal + diacrítco";
          print STDOUT "\n              \"no silábico\" (/i̯/, /u̯/) en vez de /j/ y /w/.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMANDO:      $progname -i=fuente.txt -nospe";
          print STDOUT "\n";
          print STDOUT "\nSALIDA:       en kon.sep.ˈsjon | se ˈt̪ɾa.t̪a d̪e a.gwan.ˈt̪aɾ la ˈʝu.bja d̪u.ˈɾan.t̪e";
          print STDOUT "\n              ˈsin.ko ˈme.ses d̪el ˈa.ɲo ‖ ka.ˈt͡ʃaj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPCIÓN:  Silabizar a nivel de palabra, y no enunciado/oración.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMANDO:      $progname -i=fuente.txt -cv";
          print STDOUT "\n";
          print STDOUT "\nSALIDA:       VC.CVC.CVC.ˈCVVC | CV.ˈCCV.CV.CV.V.CVVC.ˈCVC.CV.ˈCV.CVV.CV.ˈCVC.";
          print STDOUT "\n              CV.ˈCVC.CV.ˈCV.CVC.CVC.ˈV.CV ‖ CV.ˈCVV";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPCIÓN:  Analizar el texto fuente en términos de consonantes y vocales.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMANDO:      $progname -i=fuente.txt -cvg";
          print STDOUT "\n";
          print STDOUT "\nSALIDA:       VC.CVC.CVC.ˈCGVC | CV.ˈCCV.CV.CV.V.CGVC.ˈCVC.CV.ˈCV.CGV.CV.ˈCVC.";
          print STDOUT "\n              CV.ˈCVC.CV.ˈCV.CVC.CVC.ˈV.CV ‖ CV.ˈCVG";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPCIÓN:  Analizar el texto fuente en términos de consonantes, vocales y";
          print STDOUT "\n              glides";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMANDO:      $progname -i=fuente.txt -cvn";
          print STDOUT "\n";
          print STDOUT "\nSALIDA:       VN.CVN.CVC.ˈCGVN | CV.ˈCRV.CV.CV.V.CGVN.ˈCVR.LV.ˈCV.CGV.CV.ˈRVN.";
          print STDOUT "\n              CV.ˈCVN.CV.ˈNV.CVC.CVL.ˈV.NV ‖ CV.ˈCVG";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPCIÓN:  Analizar el texto fuente en términos de consonantes, vocales,";
          print STDOUT "\n              glides, nasales, líquidas y róticas.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMANDO:      $progname -i=fuente.txt -m";
          print STDOUT "\n";
          print STDOUT "\nSALIDA:       VN.PVN.FVP.ˈFXVN | FV.ˈPTV.PV.PV.V.PXVN.ˈPVT.LV.ˈFV.PXV.PV.ˈTVN.";
          print STDOUT "\n              PV.ˈFVN.PV.ˈNV.FVF.PVL.ˈV.NV ‖ PV.ˈAVX";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPCIÓN:  Analizar el texto fuente en términos de los MODOS de articulación";
          print STDOUT "\n              (P=plosiva, N=nasal, R=multivibrante, T=vibrante simple,";
          print STDOUT "\n              F=fricativa, L=lateral, A=africada, X=aproximante, V=vocal).";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMANDO:      $progname -i=fuente.txt -p";
          print STDOUT "\n";
          print STDOUT "\nSALIDA:       -A.V-A.A-B.ˈAP-A | A-.ˈDA-.D-.D-.-.VW-A.ˈD-A.A-.ˈP-.BP-.D-.ˈA-A.D-.";
          print STDOUT "\n              ˈA-A.V-.ˈB-.A-A.D-A.ˈ-.P- ‖ V-.ˈT-P";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPCIÓN:  Analizar el texto fuente en términos de los PUNTOS de articulación";
          print STDOUT "\n              (B=bilabial, L=labiodental, D=dental, A=alveolar, T=postalveolar, ";
          print STDOUT "\n              P=palatal, V=velar, W=labiovelar, -=vocal).";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\n";
          print STDOUT "\nPara más información, véase la ayuda: $progname -h";
          print STDOUT "\n\n";
     }
     else {
          print STDOUT "                                 USAGE GUIDE";
          print STDOUT "\n     Perkins provides a great many options for Spanish transcription.";
          print STDOUT "\n             Some of the more useful ones are presented here.";
          print STDOUT "\n";
          print STDOUT "\nGENERAL TIPS:";
          print STDOUT "\n - Options can be entered with either \"-\" or \"--\". The \'=\' is optional.";
          print STDOUT "\n - The order of options and filenames is irrelevant.";
          print STDOUT "\n - Most binary options can be inverted by inserting \'no\' between the hyphen";
          print STDOUT "\n     and the option itself (e.g. \'-mc\' can be deactivated with \'-nomc\').";
          print STDOUT "\n - There is no limit on the number of options that can be selected.";
          print STDOUT "\n - If a filename contains spaces or certain special characters, it must be";
          print STDOUT "\n     entered in quotation marks.";
          print STDOUT "\n - If an output file name is not specified, its name will be automatically";
          print STDOUT "\n     generated using the input file's base name and an extension that";
          print STDOUT "\n     reflects the transcription mode chosen.";
          print STDOUT "\n";
          print STDOUT "\nSELECTING A TRANSCRIPTION MODE:";
          print STDOUT "\n - The transcription mode to be used can be selected from the command line";
          print STDOUT "\n   in two different ways: -f=MODE and -MODE.";
          print STDOUT "\n - Valid transcription modes are: F, CV, CVG, CVN, M, P, S. See below for details.";
          print STDOUT "\n";
          print STDOUT "\n                             USAGE EXAMPLES:";
          print STDOUT "\n";
          print STDOUT "\nSOURCE TEXT:  En Concepción, se trata de aguantar la lluvia durante 5";
          print STDOUT "\n              meses del año. ¿Cachái?";
          print STDOUT "\n";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMMAND:      $progname -i=source.txt";
          print STDOUT "\n";
          print STDOUT "\nOUTPUT:       en.kon.sep.ˈsjon | se.ˈt̪ɾa.t̪a.d̪e.a.gwan.ˈt̪aɾ.la.ˈʝu.bja.";
          print STDOUT "\n              d̪u.ˈɾan.t̪e.ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo ‖ ka.ˈt͡ʃaj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPTION:  Default options. Phonemic transcription. Affricates have ligature.";
          print STDOUT "\n              Yod and wau are represented as /j/ and /w/. IPA stress apostrophe.";
          print STDOUT "\n              Dentals have diacritic. Multi-character symbols (e.g. /t͡ʃ/).";
          print STDOUT "\n              Utterance-level processing. The \"ye\" phoneme is transcribed as /ʝ/.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMMAND:      $progname -i=source.txt -at";
          print STDOUT "\n";
          print STDOUT "\nOUTPUT:       en.kon.sep.sjón | se.t̪ɾá.t̪a.d̪e.a.gwan.t̪áɾ.la.ʝú.bja.d̪u.ɾán.t̪e.sín.";
          print STDOUT "\n              ko.mé.ses.d̪e.lá.ɲo ‖ ka.t͡ʃáj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPTION:  Stress accent is marked with a tilde on the vowel instead of an";
          print STDOUT "\n              IPA apostrophe before the syllable.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMMAND:      $progname -i=source.txt -ya";
          print STDOUT "\n";
          print STDOUT "\nOUTPUT:       en.kon.sep.ˈsjon | se.ˈt̪ɾa.t̪a.d̪e.a.gwan.ˈt̪aɾ.la.ˈd͡ʒu.bja.d̪u.ˈɾan.";
          print STDOUT "\n              t̪e.ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo ‖ ka.ˈt͡ʃaj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPTION:  The \"ye\" phoneme is transcribed as the affricate /d͡ʒ/.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMMAND:      $progname -i=source.txt -ya -ar";
          print STDOUT "\n";
          print STDOUT "\nOUTPUT:       en.kon.sep.ˈsjon | se.ˈt̪ɾa.t̪a.d̪e.a.gwan.ˈt̪aɾ.la.ˈd̠͡ʒu.bja.d̪u.ˈɾan.";
          print STDOUT "\n              t̪e.ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo ‖ ka.ˈt̠͡ʃaj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPTION:  The \"retracted\" diacritic is used to represent the affricates";
          print STDOUT "\n              /d̠͡ʒ/ and /t̠͡ʃ/.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMMAND:      $progname -i=source.txt -ya -tg";
          print STDOUT "\n";
          print STDOUT "\nOUTPUT:       en.kon.sep.ˈsjon | se.ˈt̪͡ɾa.t̪a.d̪e.a.gwan.ˈt̪aɾ.la.ˈd͡ʒu.bja.d̪u.ˈɾan.";
          print STDOUT "\n              t̪e.ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo ‖ ka.ˈt͡ʃaj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPTION:  The \"tr\" cluster is treated as a phoneme (which is how it behaves";
          print STDOUT "\n              in many Chilean speakers).";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMMAND:      $progname -i=source.txt -ya -tg -nomc";
          print STDOUT "\n";
          print STDOUT "\nOUTPUT:       en.kon.sep.ˈsjon | se.ˈʂa.ta.de.a.gwan.ˈtaɾ.la.ˈʤu.bja.du.ˈɾan.te.";
          print STDOUT "\n              ˈsin.ko.ˈme.ses.de.ˈla.ɲo ‖ ka.ˈʧaj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPTION:  Phonemes are represented only with one-character symbols (/ʤ/; ";
          print STDOUT "\n              /ʧ/; /ʂ/ instead of /t̪͡ɾ/) except for glides, which may be";
          print STDOUT "\n              configured separately with the \'-gd\' and \'-nogd\' switches.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMMAND:      $progname -i=source.txt -gd";
          print STDOUT "\n";
          print STDOUT "\nOUTPUT:       en.kon.sep.ˈsi̯on | se.ˈt̪ɾa.t̪a.d̪e.a.gu̯an.ˈt̪aɾ.la.ˈʝu.bi̯a.d̪u.ˈɾan.t̪e.";
          print STDOUT "\n              ˈsin.ko.ˈme.ses.d̪e.ˈla.ɲo ‖ ka.ˈt͡ʃai̯";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPTION:  Transcribe glides as vowel + \"non-syllabic\ diacritic\" (/i̯/, /u̯/)";
          print STDOUT "\n              instead of /j/ and /w/.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMMAND:      $progname -i=source.txt -nospe";
          print STDOUT "\n";
          print STDOUT "\nOUTPUT:       en kon.sep.ˈsjon | se ˈt̪ɾa.t̪a d̪e a.gwan.ˈt̪aɾ la ˈʝu.bja d̪u.ˈɾan.t̪e";
          print STDOUT "\n              ˈsin.ko ˈme.ses d̪el ˈa.ɲo ‖ ka.ˈt͡ʃaj";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPTION:  Syllabify at word-level rather than utterance/sentence-level.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMMAND:      $progname -i=source.txt -cv";
          print STDOUT "\n";
          print STDOUT "\nOUTPUT:       VC.CVC.CVC.ˈCVVC | CV.ˈCCV.CV.CV.V.CVVC.ˈCVC.CV.ˈCV.CVV.CV.ˈCVC.";
          print STDOUT "\n              CV.ˈCVC.CV.ˈCV.CVC.CVC.ˈV.CV ‖ CV.ˈCVV";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPTION:  Analyze input in terms of consonant/vowel.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMMAND:      $progname -i=source.txt -cvg";
          print STDOUT "\n";
          print STDOUT "\nOUTPUT:       VC.CVC.CVC.ˈCGVC | CV.ˈCCV.CV.CV.V.CGVC.ˈCVC.CV.ˈCV.CGV.CV.ˈCVC.";
          print STDOUT "\n              CV.ˈCVC.CV.ˈCV.CVC.CVC.ˈV.CV ‖ CV.ˈCVG";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPTION:  Analyze input in terms of consonant/vowel/glide.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMMAND:      $progname -i=source.txt -cvn";
          print STDOUT "\n";
          print STDOUT "\nOUTPUT:       VN.CVN.CVC.ˈCGVN | CV.ˈCRV.CV.CV.V.CGVN.ˈCVR.LV.ˈCV.CGV.CV.ˈRVN.";
          print STDOUT "\n              CV.ˈCVN.CV.ˈNV.CVC.CVL.ˈV.NV ‖ CV.ˈCVG";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPTION:  Analyze input in terms of consonant/vowel/glide/nasal/liquid/rhotic.";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMMAND:      $progname -i=source.txt -m";
          print STDOUT "\n";
          print STDOUT "\nOUTPUT:       VN.PVN.FVP.ˈFXVN | FV.ˈPTV.PV.PV.V.PXVN.ˈPVT.LV.ˈFV.PXV.PV.ˈTVN.";
          print STDOUT "\n              PV.ˈFVN.PV.ˈNV.FVF.PVL.ˈV.NV ‖ PV.ˈAVX";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPTION:  Analyze input in terms of MANNERS of articulation.";
          print STDOUT "\n              (P=plosive, N=nasal, R=trill, T=tap/flap, F=fricative, L=lateral,";
          print STDOUT "\n              A=affricate, X=approximant, V=vowel).";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\nCOMMAND:      $progname -i=source.txt -p";
          print STDOUT "\n";
          print STDOUT "\nOUTPUT:       -A.V-A.A-B.ˈAP-A | A-.ˈDA-.D-.D-.-.VW-A.ˈD-A.A-.ˈP-.BP-.D-.ˈA-A.D-.";
          print STDOUT "\n              ˈA-A.V-.ˈB-.A-A.D-A.ˈ-.P- ‖ V-.ˈT-P";
          print STDOUT "\n";
          print STDOUT "\nDESCRIPTION:  Analyze input in terms of PLACES of articulation.";
          print STDOUT "\n              (B=bilabial, L=labiodental, D=dental, A=alveolar, T=post-alveolar, ";
          print STDOUT "\n              P=palatal, V=velar, W=labiovelar, -=vowel).";
          print STDOUT "\n-------------------------------------------------------------------------------";
          print STDOUT "\n";
          print STDOUT "\nFor more information, see program help: $progname -h";
          print STDOUT "\n\n";

     }
}

############################################################################
# SUBROUTINE: OPEN INPUT FILE, CREATE LOG FILE                             #
############################################################################
sub open_input_and_log_files {

     if ( $lang eq "es" ) {
          $user_message = "ERROR: No fue posible abrir el archivo de input \'$input_filename\'. Probablemente tipeaste mal su nombre.";
     }
     else {
          $user_message = "ERROR: The input file \'$input_filename\' could not be opened. Make sure you typed its name correctly.";
     }

     # Open INPUT FILE or die     # Input must be ISO-8859-1               #
     open( INPUTFILE, '<:encoding(iso-8859-1)', "$input_filename" )
       || die "\n$user_message\n\n";

     # Extract BASENAME of input file name                                 #
     $in_basename = $input_filename;
     $in_basename =~ s/(.+)\.(.+)/$1/;

     # Create DEBUG LOG file if required, now that we have the info to name it #
     if ( $debug_to_logfile == 1 ) {
          open( LOGFILE, '>:encoding(UTF-8)', "$in_basename.log" );
     }
}

############################################################################
#                                                                          #
# SUBROUTINE: PRINT DEBUG LOG HEADER, STATUS MESSAGES, CLI INFO AND        #
#             CFG FILE STATUS MESSAGES                                     #
#                                                                          #
############################################################################
sub print_header_CLI_status_msgs {

     # Print debugging log header                                               #
     if ( ( $debug == 1 ) && ( $debug_to_logfile == 1 ) ) {

          &print_info_header;

          print LOGFILE "\n|                        Perkins v$version                              |";

          print LOGFILE "\n|                          DEBUGGING LOG                               |";
          print LOGFILE "\n|                    $current_time                          |";
          print LOGFILE "\n ---------------------------------------------------------------------- ";
     }

     # Print status messages, either to console or log file.                    #
     if ( $debug == 1 ) {
          if ( $debug_to_logfile == 0 ) {
               print STDOUT "\nDEBUG CLI: \$input_filename =\t\t\t$input_filename";
               print STDOUT "\nDEBUG CLI: CLI-provided \$output_filename =\t$output_filename";
               print STDOUT "\nDEBUG CLI: CLI-provided \$output_format =\t$output_format";
          }
          if ( $debug_to_logfile == 1 ) {
               print LOGFILE "\nDEBUG CLI: \$input_filename\t\t\t\t=\t$input_filename";
               print LOGFILE "\nDEBUG CLI: CLI-provided \$output_filename\t=\t$output_filename";
               print LOGFILE "\nDEBUG CLI: CLI-provided \$output_format\t\t=\t$output_format";
          }
     }

     # Print info about CLI OPTIONS if desired, either to STDOUT or debug log   #
     if ( $debug == 1 ) {
          if ( $debug_to_logfile == 0 ) {
               print STDOUT "\nDEBUG CLI: \$in_basename =\t\t\t$in_basename";
          }
          elsif ( $debug_to_logfile == 1 ) {
               print LOGFILE "\nDEBUG CLI: \$in_basename\t\t\t\t\t=\t$in_basename";
          }
     }

     # Notify user that config file was read, either on STDOUT or in LOG FILE   #
     if ( $config_file_present == 1 ) {
          if ( ( $debug == 1 ) && ( $debug_to_logfile == 0 ) ) {
               print STDOUT "\n\n*** Configuration file (perkins.ini) successfully read. ***\n\n";
          }
          elsif ( ( $debug == 1 ) && ( $debug_to_logfile == 1 ) ) {
               print LOGFILE "\n\n*** Configuration file (perkins.ini) successfully read. ***\n";
          }
     }
}    # END SUBROUTINE: PRINT DEBUG LOG HEADER, STATUS MESSAGES, CLI INFO, ETC.

#################################################################################
# SUBROUTINE: ASSIGN DEFAULT OUTPUT FILENAME IF NECESSARY                       #
# NEW in 382: A unique file extension is assigned for each transcription format #
#################################################################################
sub assign_default_output_filename {

     # If format is VRT, append ".vrt" to BASENAME.                             #
     # NEW IN 417.                                                              #
     if ( $vrt_format == 1 ) {
          $in_basename = "$in_basename.vrt";
     }

     # For ALL formats: append relevant file extension to basename              #
     if ( $output_CV == 1 ) {
          $output_filename = "$in_basename.cv";
     }

     elsif ( $output_CVG == 1 ) {
          $output_filename = "$in_basename.cvg";
     }

     elsif ( $output_CVNLRG == 1 ) {
          $output_filename = "$in_basename.cvnlrg";
     }

     elsif ( $output_manner == 1 ) {
          $output_filename = "$in_basename.manner";
     }

     elsif ( $output_place == 1 ) {
          $output_filename = "$in_basename.place";
     }

     elsif ( $voicing == 1 ) {
          $output_filename = "$in_basename.voicing";
     }
     elsif ( $output_PHON == 1 ) {
          $output_filename = "$in_basename.phnm";
     }
     else {
          $output_filename = "$in_basename.phnm";
     }

     if ( $debug == 1 ) {
          if ( $debug_to_logfile == 0 ) {
               print STDOUT "\nDEBUG CLI: Default assigned OUTPUT filename =\t$output_filename";    # NOTE DEBUGGING
          }
          elsif ( $debug_to_logfile == 1 ) {
               print LOGFILE "\nDEBUG CLI: Default assigned OUTPUT filename\t=\t$output_filename";    # NOTE DEBUGGING
          }
     }
}

############################################################################
#            SUBROUTINE: OPEN OUTPUT FILE - Output will be UTF-8           #
############################################################################
sub open_output_file {
     open( OUTPUTFILE, '>:encoding(UTF-8)', "$output_filename" );

     # Print any debug info that may be required
     if ( $debug == 1 ) {
          if ( $debug_to_logfile == 0 ) {
               print STDOUT "\nDEBUG CLI: Will use \$output_filename = \t\t$output_filename";    # NOTE DEBUGGING
          }
          elsif ( $debug_to_logfile == 1 ) {
               print LOGFILE "\nDEBUG CLI: Will use \$output_filename\t\t=\t$output_filename\n";    # NOTE DEBUGGING
          }
     }
}

############################################################################
#               SUBROUTINE: PROCESS COMMAND LINE OPTIONS                   #
# If there are any, they supercede both the defaults and the .ini file     #
############################################################################
sub process_command_line_options {

     # Clear all default and config-file output format variables if any was given on the CLI #
     if ( $output_format ne "" ) {
          $output_CV     = 0;
          $output_CVG    = 0;
          $output_CVNLRG = 0;
          $output_manner = 0;
          $output_place  = 0;
          $voicing       = 0;
          $output_PHON   = 0;
     }

     # Set OUTPUT FORMAT (CV, CVG, etc.) VARIABLE, IF APPROPRIATE               #
     if ( $output_format eq "cv" ) {
          $output_CV = 1;
     }
     elsif ( $output_format eq "cvg" ) {
          $output_CVG = 1;
     }
     elsif ( ( $output_format eq "cvn" )
          || ( $output_format eq "cvnlrg" ) )
     {
          $output_CVNLRG = 1;
     }
     elsif ( ( $output_format eq "manner" )
          || ( $output_format eq "man" )
          || ( $output_format eq "modo" )
          || ( $output_format eq "m" ) )
     {
          $output_manner = 1;
     }
     elsif ( ( $output_format eq "place" )
          || ( $output_format eq "pl" )
          || ( $output_format eq "punto" )
          || ( $output_format eq "p" ) )
     {
          $output_place = 1;
     }
     elsif ( ( $output_format eq "voicing" )
          || ( $output_format eq "voice" )
          || ( $output_format eq "v" )
          || ( $output_format eq "sonoridad" )
          || ( $output_format eq "son" )
          || ( $output_format eq "s" ) )
     {
          $voicing = 1;
     }

     # NOTE NEW IN 358
     elsif ( ( $output_format eq "phon" )
          || ( $output_format eq "fon" )
          || ( $output_format eq "ph" )
          || ( $output_format eq "f" )
          || ( $output_format eq "IPA" )
          || ( $output_format eq "AFI" ) )
     {
          $output_PHON = 1;
     }

     if ( $debug == 1 ) {
          &print_cli_debug_info;
     }

}    #END SUBROUTINE

############################################################################
#                                                                          #
#                     SUBROUTINE: PRINT CLI DEBUGGING INFO                 #
#                                                                          #
############################################################################
sub print_cli_debug_info {

     our $debug_message = qq(

DEBUG CLI: USER OPTIONS - PROGRAM BEHAVIOR
DEBUG CLI: \$debug                     =    $debug
DEBUG CLI: \$debug_syllab_sub          =    $debug_syllab_sub
DEBUG CLI: \$debug_to_logfile          =    $debug_to_logfile
DEBUG CLI: \$silent_mode               =    $silent_mode
DEBUG CLI: \$batch_mode                =    $batch_mode
DEBUG CLI: \$use_config_file           =    $use_config_file

DEBUG CLI: META OPTIONS - FOR SPECIFIC COMBINATIONS OF VARIABLES
DEBUG CLI: \$coscach_mode              =    $coscach_mode
DEBUG CLI: \$corpus_running_text       =    $corpus_running_text
DEBUG CLI: \$syllable_list             =    $syllable_list
DEBUG CLI: \$vrt_format                =    $vrt_format
DEBUG CLI: \$all_year_ranges           =    $all_year_ranges

DEBUG CLI: USER OPTIONS - FORMAT OF TRANSCRIPTION OUTPUT
DEBUG CLI: \$output_PHON               =    $output_PHON
DEBUG CLI: \$output_CV                 =    $output_CV
DEBUG CLI: \$output_CVG                =    $output_CVG
DEBUG CLI: \$output_CVNLRG             =    $output_CVNLRG
DEBUG CLI: \$output_manner             =    $output_manner
DEBUG CLI: \$output_place              =    $output_place
DEBUG CLI: \$voicing                   =    $voicing

DEBUG CLI: USER OPTIONS - FOR SPECIFIC PHONEMES
DEBUG CLI: \$multichars                =    $multichars
DEBUG CLI: \$tr_is_group               =    $tr_is_group
DEBUG CLI: \$ch_dzh_retracted          =    $ch_dzh_retracted
DEBUG CLI: \$ye_phoneme_is_fricative   =    $ye_phoneme_is_fricative

DEBUG CLI: USER OPTIONS - FOR GLIDES
DEBUG CLI: \$glides_with_diacritics    =    $glides_with_diacritics
DEBUG CLI: \$non_syl_u_with_u_diacr    =    $non_syl_u_with_u_diacr
DEBUG CLI: \$non_syl_i_with_i_diacr    =    $non_syl_i_with_i_diacr

DEBUG CLI: USER OPTIONS - STRESS
DEBUG CLI: \$stress_using_tildes       =    $stress_using_tildes
DEBUG CLI: \$no_stress_marks           =    $no_stress_marks
DEBUG CLI: \$non_ipa_apostrophes       =    $non_ipa_apostrophes

DEBUG CLI: USER OPTIONS - SYLLABLES
DEBUG CLI: \$insert_syllable_dots      =    $insert_syllable_dots
DEBUG CLI: \$split_at_syllables        =    $split_at_syllables
DEBUG CLI: \$syllabify_by_sentence     =    $syllabify_by_sentence
DEBUG CLI: \$syllable_dots_are_spaces  =    $syllable_dots_are_spaces

DEBUG CLI: USER OPTIONS - PAUSES
DEBUG CLI: \$ipa_pause_symbols         =    $ipa_pause_symbols
DEBUG CLI: \$add_comma_pauses          =    $add_comma_pauses
DEBUG CLI: \$add_colon_pauses          =    $add_colon_pauses
DEBUG CLI: \$add_semicolon_pauses      =    $add_semicolon_pauses
DEBUG CLI: \$add_sentence_breaks       =    $add_sentence_breaks
DEBUG CLI: \$add_paragraph_breaks      =    $add_paragraph_breaks
DEBUG CLI: \$add_ellipsis_pauses       =    $add_ellipsis_pauses
DEBUG CLI: \$add_bracket_pauses        =    $add_bracket_pauses
DEBUG CLI: \$add_paren_pauses          =    $add_paren_pauses

DEBUG CLI: USER OPTIONS - NUMBERS
DEBUG CLI: \$numerals_to_words         =    $numerals_to_words
DEBUG CLI: \$num_symbol                =    $num_symbol
DEBUG CLI: \$narrow_year_ranges        =    $narrow_year_ranges
DEBUG CLI: \$broad_year_ranges         =    $broad_year_ranges
DEBUG CLI: \$bc_dates_included         =    $bc_dates_included

DEBUG CLI: USER OPTIONS - ODD CHARACTERS
DEBUG CLI: \$fix_umlauts               =    $fix_umlauts
DEBUG CLI: \$fix_grave_accents         =    $fix_grave_accents
DEBUG CLI: \$fix_circumflexes          =    $fix_circumflexes
DEBUG CLI: \$fix_nasal_tildes          =    $fix_nasal_tildes

DEBUG CLI: USER OPTIONS - SUBSTITUTIONS
DEBUG CLI: \$moneda                    =    $moneda
DEBUG CLI: \$slash                     =    $slash
DEBUG CLI: \$process_urls              =    $process_urls
DEBUG CLI: \$process_email             =    $process_email
DEBUG CLI: \$name_for_v                =    $name_for_v
DEBUG CLI: \$keep_paragraphs           =    $keep_paragraphs
DEBUG CLI: \$vertical_output           =    $vertical_output

DEBUG CLI: OPTIONS THAT USERS MAY *NOT* CONFIGURE
DEBUG CLI: \$semi_narrow               =    $semi_narrow
DEBUG CLI: \$cleanup_output_file       =    $cleanup_output_file
DEBUG CLI: \$no_separate_cleanup_file  =    $no_separate_cleanup_file

DEBUG CLI: OUTPUT: CLEANUP OPTIONS
DEBUG CLI: \$preclean_orthographic     =    $preclean_orthographic
DEBUG CLI: \$preclean_semiphonemic     =    $preclean_semiphonemic
DEBUG CLI: \$preclean_phonemic         =    $preclean_phonemic

DEBUG CLI: MISC
DEBUG CLI: \$upper_case                =    $upper_case
DEBUG CLI: \$kill_common_words         =    $kill_common_words

DEBUG CLI: \ INTERNAL VARIABLES THAT NEED INITIALIZED - DON'T CHANGE!
DEBUG CLI: \$helpme                    =    $helpme
DEBUG CLI: \$useme                     =    $useme
DEBUG CLI: \$config_file_present       =    $config_file_present
DEBUG CLI: \$output_filename           =    $output_filename
);

     if ( $debug_to_logfile == 0 ) {
          print STDOUT $debug_message;
     }
     elsif ( $debug_to_logfile == 1 ) {
          print LOGFILE $debug_message;
     }
}

############################################################################
# SUBROUTINE: FORCIBLY SET VARIABLES THAT DEPEND ON OTHER VARIABLES        #
# This has to be done here, and not earlier, so as to receive any changed  #
# variable values from the config file or command line options.            #
############################################################################
sub forcibly_set_variables {

     # Make sure values for the two "ye" phoneme variables don't contradict each other
     if ( $ye_phoneme_is_affricate == 1 ) {
          $ye_phoneme_is_fricative = 0;
     }
     else { $ye_phoneme_is_fricative = 1 }

     #######################################################################
     #                        METACONFIGURATIONS                           #
     #######################################################################

     # Allow only one meta-configuration                                   #
     if ( $corpus_running_text == 1 ) {
          $syllable_list = 0;
          $vrt_format    = 0;
          $word_list     = 0;
     }

     if ( $syllable_list == 1 ) {
          $corpus_running_text = 0;
          $vrt_format          = 0;
          $word_list           = 0;
     }

     if ( $vrt_format == 1 ) {
          $corpus_running_text = 0;
          $syllable_list       = 0;
          $word_list           = 0;
     }

     if ( $word_list == 1 ) {
          $corpus_running_text = 0;
          $syllable_list       = 0;
          $vrt_format          = 0;
     }

     # Coscach mode trumps all
     if ( $coscach_mode == 1 ) {
          $corpus_running_text = 0;
          $syllable_list       = 0;
          $vrt_format          = 0;
          $word_list           = 0;
     }

     # CORPUS OF RUNNING TEXT SETTINGS                                     #
     # Running text, syllabified at sentence level, accent using tildes,   #
     # single character per phoneme, output is phonemic transcription      #
     if ( $corpus_running_text == 1 ) {

          #$output_PHON             = 1; # Might have to disable this
          $multichars              = 0;
          $syllabify_by_sentence   = 1;
          $tr_is_group             = 0;
          $ye_phoneme_is_fricative = 1;
          $glides_with_diacritics  = 0;    # NEEDED ???
          $stress_using_tildes     = 1;
          $non_ipa_apostrophes     = 0;
          $insert_syllable_dots    = 1;
          $ipa_pause_symbols       = 1;
          $add_comma_pauses        = 1;
          $add_colon_pauses        = 1;
          $add_semicolon_pauses    = 1;
          $add_sentence_breaks     = 1;
          $add_paragraph_breaks    = 1;
          $add_ellipsis_pauses     = 1;
          $add_bracket_pauses      = 1;
          $add_paren_pauses        = 1;
          $numerals_to_words       = 1;
          $keep_paragraphs         = 1;
          $vertical_output         = 0;
          $kill_common_words       = 0;
          $silent_mode             = 1;
          $all_year_ranges         = 1;
     }

     # SYLLABLE LIST SETTINGS                                                      #
     # Doesn't specify transcription format, to allow different formats to be used.#
     # Syllabified at sentence level, running text, syllables separated by SPACE,  #
     # non-IPA apostrophe used,
     if ( $syllable_list == 1 ) {
          $multichars               = 0;
          $syllabify_by_sentence    = 1;
          $tr_is_group              = 1;
          $ye_phoneme_is_fricative  = 1;
          $glides_with_diacritics   = 0;    # NEEDED ???
          $stress_using_tildes      = 0;
          $non_ipa_apostrophes      = 1;
          $insert_syllable_dots     = 1;
          $syllable_dots_are_spaces = 1;
          $ipa_pause_symbols        = 1;
          $add_comma_pauses         = 1;
          $add_colon_pauses         = 1;
          $add_semicolon_pauses     = 1;
          $add_sentence_breaks      = 1;
          $add_paragraph_breaks     = 1;
          $add_ellipsis_pauses      = 1;
          $add_bracket_pauses       = 1;
          $add_paren_pauses         = 1;
          $numerals_to_words        = 1;
          $keep_paragraphs          = 1;
          $vertical_output          = 0;
          $kill_common_words        = 0;
          $silent_mode              = 1;
          $all_year_ranges          = 1;
     }

     # WORD LIST SETTINGS                                                            #
     # Doesn't specify transcription format, to allow different formats to be used.  #
     # Syllabified at word level, syllables separated by dot and words by a space.   #
     # Note that pauses are indeed processed (unless user indicates otherwise).      #
     # Also, note that this metaconfig sets relatively few variables.                #
     if ( $word_list == 1 ) {
          $multichars            = 0;
          $syllabify_by_sentence = 0;

          #$tr_is_group              = 1;
          #$ye_phoneme_is_fricative  = 1;
          #$glides_with_diacritics   = 0;
          #$stress_using_tildes      = 0;
          #$non_ipa_apostrophes      = 1;
          $insert_syllable_dots     = 1;
          $syllable_dots_are_spaces = 0;
          $ipa_pause_symbols        = 1;
          $add_comma_pauses         = 1;
          $add_colon_pauses         = 1;
          $add_semicolon_pauses     = 1;
          $add_sentence_breaks      = 1;
          $add_paragraph_breaks     = 1;
          $add_ellipsis_pauses      = 1;
          $add_bracket_pauses       = 1;
          $add_paren_pauses         = 1;
          $numerals_to_words        = 1;
          $keep_paragraphs          = 1;
          $vertical_output          = 0;
          $kill_common_words        = 0;
          $silent_mode              = 1;

          #$all_year_ranges          = 1;
     }

     # VERTICAL TEXT FILE (.vrt) SETTINGS                                       #
     # Doesn't specify transcription format, to allow different ones to be used.#
     # Vertical output (one word per line), syllables NOT separated, stress     #
     # using tildes.                                                            #
     if ( $vrt_format == 1 ) {

          # $output_PHON = 1;
          $multichars               = 0;
          $syllabify_by_sentence    = 0;
          $tr_is_group              = 0;
          $ye_phoneme_is_fricative  = 1;
          $glides_with_diacritics   = 0;    # NEEDED ???
          $stress_using_tildes      = 1;
          $non_ipa_apostrophes      = 0;
          $insert_syllable_dots     = 1;
          $syllable_dots_are_spaces = 0;
          $ipa_pause_symbols        = 1;
          $add_comma_pauses         = 1;
          $add_colon_pauses         = 0;
          $add_semicolon_pauses     = 1;
          $add_sentence_breaks      = 1;
          $add_paragraph_breaks     = 1;
          $add_ellipsis_pauses      = 1;
          $add_bracket_pauses       = 1;
          $add_paren_pauses         = 1;
          $numerals_to_words        = 1;
          $keep_paragraphs          = 1;
          $vertical_output          = 1;
          $kill_common_words        = 0;
          $silent_mode              = 1;
          $all_year_ranges          = 1;    # NEW IN 419
     }

     # COSCACH MODE SETTINGS                                                    #
     if ( $coscach_mode == 1 ) {

          # $output_PHON = 1;
          $multichars               = 1;
          $syllabify_by_sentence    = 1;
          $tr_is_group              = 0;
          $ye_phoneme_is_fricative  = 1;
          $glides_with_diacritics   = 0;    # NEEDED ???
          $use_ligatures            = 0;
          $use_dental_diacr         = 0;
          $stress_using_tildes      = 1;
          $non_ipa_apostrophes      = 0;
          $insert_syllable_dots     = 1;
          $syllable_dots_are_spaces = 1;    # Not sure if I really like this in Coscach transcriptions
          $ipa_pause_symbols        = 1;
          $add_comma_pauses         = 1;
          $add_colon_pauses         = 1;
          $add_semicolon_pauses     = 1;
          $add_sentence_breaks      = 1;
          $add_paragraph_breaks     = 1;
          $add_ellipsis_pauses      = 1;
          $add_bracket_pauses       = 1;
          $add_paren_pauses         = 1;
          $numerals_to_words        = 1;
          $keep_paragraphs          = 1;
          $vertical_output          = 0;
          $kill_common_words        = 0;
          $silent_mode              = 0;
          $all_year_ranges          = 1;

          $ipa_long_pause_two_singles = 1;
     }

     # SPECIFIC CONFIGURATIONS                                                  #

     # PROCESS NUMBER RANGES AS DATES
     if ( $all_year_ranges == 1 ) {
          $narrow_year_ranges = 1;
          $broad_year_ranges  = 1;
          $bc_dates_included  = 1;
     }

     # SET OPTIONS FOR USING NO STRESS MARKS
     if ( $no_stress_marks == 1 ) { $stress_using_tildes = 0 }

     # SET OPTIONS FOR SPLITTING AT SYLLABLES
     if ( $split_at_syllables == 1 ) {
          $vertical_output          = 1;
          $insert_syllable_dots     = 1;
          $no_stress_marks          = 1;
          $syllable_dots_are_spaces = 0;
     }

     # SET VALUES FOR MULTICHARS AND DIACRITICS IF A NON-PHONEMIC TRANSCRIPTION IS USED
     if (    $output_CV == 1
          || $output_CVG == 1
          || $output_CVNLRG == 1
          || $output_manner == 1
          || $output_place == 1
          || $voicing == 1 )
     {
          $multichars             = 0;
          $non_syl_u_with_u_diacr = 0;
          $non_syl_i_with_i_diacr = 0;

          $upper_case = 1;
     }

     # SET OPTIONS FOR SEMI-NARROW TRANSCRIPTION (NOT IMPLEMENTED AS OF 416...)
     if ( $semi_narrow == 1 ) {
          $multichars             = 0;
          $non_syl_u_with_u_diacr = 0;
          $non_syl_i_with_i_diacr = 0;
          $numerals_to_words      = 1;
          $fix_umlauts            = 1;
          $fix_grave_accents      = 1;
          $fix_circumflexes       = 1;
          $fix_nasal_tildes       = 1;
          $preclean_orthographic  = 1;
          $preclean_semiphonemic  = 1;
          $keep_paragraphs        = 1;
          $split_at_syllables     = 0;
          $stress_using_tildes    = 1;
          $ipa_pause_symbols      = 1;
          $vertical_output        = 0;
     }

     # SET OPTIONS FOR VERTICAL OUTPUT
     if ( $vertical_output == 1 ) {
          $add_comma_pauses     = 0;
          $add_colon_pauses     = 0;
          $add_semicolon_pauses = 0;
          $add_sentence_breaks  = 0;
          $add_paragraph_breaks = 0;
          $add_ellipsis_pauses  = 0;
          $add_bracket_pauses   = 0;
          $add_paren_pauses     = 0;
     }

     # SET OPTIONS FOR SILENT MODE
     if ( $silent_mode == 1 ) {
          $batch_mode       = 1;
          $debug            = 0;
          $debug_syllab_sub = 0;
          $debug_to_logfile = 0;
     }

     # SET OPTIONS FOR GLIDES WITH/WITHOUT DIACRITICS
     if ( $glides_with_diacritics == 1 ) {
          $non_syl_u_with_u_diacr = 1;
          $non_syl_i_with_i_diacr = 1;
     }
     elsif ( $glides_with_diacritics == 0 ) {
          $non_syl_u_with_u_diacr = 0;
          $non_syl_i_with_i_diacr = 0;
     }

     # SET OPTIONS FOR NON-IPA APOSTROPHES
     if ( $non_ipa_apostrophes == 1 ) {
          $stress_using_tildes = 0;
     }

     # Prepare for sentence-level syllabification (instead of word-level)
     if ( $syllabify_by_sentence == 1 ) {
          $split_at_syllables = 0;

          #$insert_syllable_dots = 1; #DE-ACTIVATED IN 381
     }

     # SET OPTIONS FOR SYLLABLES DOTS AS SPACES
     if ( $syllable_dots_are_spaces == 1 ) { $insert_syllable_dots = 1 }

}

############################################################################
#                             CONSOLE GREETING                             #
# This is printed in normal (non-batch/non-silent) mode, but only if the   #
# debug to log file option is OFF.                                         #
############################################################################
sub print_console_greeting {

     &print_info_header;

     if   ( $lang eq "es" ) { $user_message = "El archivo a transcribir (\"$input_filename\") se leyó exitosamente..."; }
     else                   { $user_message = "The file to be transcribed (\"$input_filename\") was successfully read..."; }
     print STDOUT "$user_message";

     if ( $use_config_file == 1 ) {
          if   ( $lang eq "es" ) { $user_message = "La opción de utilizar el archivo de configuración fue seleccionada..."; }
          else                   { $user_message = "The option to use the values in the configuration file was chosen..."; }
          print STDOUT "\n$user_message";
     }
     if ( $config_file_present == 1 ) {
          if   ( $lang eq "es" ) { $user_message = "El archivo de configuración (\"perkins.ini\") fue procesado exitosamente..."; }
          else                   { $user_message = "The configuration file (\"perkins.ini\") was successfully processed..."; }
          print STDOUT "\n$user_message";
     }

     if ( ( $use_config_file == 1 ) && ( $config_file_present == 0 ) ) {

          if   ( $lang eq "es" ) { $user_message = "** ADVERTENCIA: No se pudo procesar el archivo de configuración externo."; }
          else                   { $user_message = "** WARNING: The configuration file could not be processed."; }
          print STDOUT "\n$user_message";

          if   ( $lang eq "es" ) { $user_message = "**              Se utilizarán los valores preconfigurados..."; }
          else                   { $user_message = "**              The default configuration will be used..."; }
          print STDOUT "\n$user_message";
     }

     if   ( $lang eq "es" ) { $user_message = "PROCESANDO..."; }
     else                   { $user_message = "PROCESSING..."; }
     print STDOUT "\n\n$user_message\n";

}    # END SUBROUTINE: PRINT CONSOLE GREETING

#################################################################################
#                                                                               #
# SUBROUTINE: .VRT DISASTEROUS CHARACTER ELIMINATION                            #
# Kill odd characters that are used internally by Perkins, before anything      #
# else is replaced.                                                             #
#                                                                               #
#################################################################################
sub kill_disasterous_vrt_chars {
     my $current_item = $_[0];

     $current_item =~ s/¬/ø/g;
     $current_item =~ s/\|/ø/g;
     $current_item =~ s/¯/ø/g;
     $current_item =~ s/§/ø/g;
     $current_item =~ s/©/ø/g;
     $current_item =~ s/®/ø/g;
     $current_item =~ s/¥/ø/g;
     $current_item =~ s/\*/ø/g;

     return ($current_item);
}

#################################################################################
#                                                                               #
#   SUBROUTINE: PROCESS INTERNET STUFF                                          #
#   Note: Doesn't process certain characters in URLs (% ! = & ? # etc.), but    #
#         simply eliminates them.                                               #
#                                                                               #
#################################################################################
sub process_internet_stuff {

     my $current_item = $_[0];

     # <-- NEW IN 393
     # EXPERIMENTAL!
     my @current_segments = split /\s/, $current_item;

     foreach my $current_segment (@current_segments) {

          # END NEW IN 393 -->

          #print "\n==>PROCESS-INTERNET-STUFF--START=$current_item\n";    # AD-HOC DEBUG

          ############################################################################
          # PROCESS URLS as linguistic strings, if desired                           #
          ############################################################################

          if ( $process_urls == 1 ) {

               # Extract URLs from text                                              #

               if (

                    # NOTE: Added "?" after "(\/\/)" in the following expression in 396
                    $current_segment =~
m/<?((http|https|ftp|sftp|news|gopher|mailto):(\/\/)?|(www\.))([a-zA-Z0-9_\$\&\+\,\/\:\;\=\?\@\#\%\{\}\|\\\^\~\[\]\`\'\"\!\*\(\)\+\.\>\-]+)/
                 )
               {

                    # PROTOCOLS (Careful with ordering!)
                    $current_segment =~ s{sftp:\/\/}{eseefetepé dos puntos $slash $slash }g;
                    $current_segment =~ s{https:\/\/}{achetetepeése dos puntos $slash $slash }g;
                    $current_segment =~ s{http:\/\/}{achetetepé dos puntos $slash $slash }g;
                    $current_segment =~ s{ftp:\/\/}{efetepé dos puntos $slash $slash }g;
                    $current_segment =~ s{news:\/\/}{nius dos puntos $slash $slash }g;
                    $current_segment =~ s{gopher:\/\/}{gófer dos puntos $slash $slash }g;
                    $current_segment =~ s{mailto:}{meiltu dos puntos }g;

                    # Odd characters
                    $current_segment =~ s/\`/ acento grave /g;
                    $current_segment =~ s/\'/ apóstrofo /g;
                    $current_segment =~ s/\@/ arroba /g;
                    $current_segment =~ s/\*/ asterisco /g;
                    $current_segment =~ s/\\/ bákeslatch /g;
                    $current_segment =~ s/\|/ barra vertical /g;
                    $current_segment =~ s/\^/ circunflejo /g;
                    $current_segment =~ s/\,/ coma /g;
                    $current_segment =~ s/\"/ comillas /g;
                    $current_segment =~ s/\[/ corchete de apertura /g;
                    $current_segment =~ s/\]/ corchete de cierre /g;
                    $current_segment =~ s/\:/ dos puntos /g;
                    $current_segment =~ s/\_/ guión bajo /g;
                    $current_segment =~ s/\-/ guión /g;
                    $current_segment =~ s/\{/ llave de apertura /g;
                    $current_segment =~ s/\}/ llave de cierre /g;
                    $current_segment =~ s/\(/ paréntesis de apertura /g;
                    $current_segment =~ s/\)/ paréntesis de cierre /g;
                    $current_segment =~ s/\./ punto /g;
                    $current_segment =~ s/\;/ puntoycoma /g;
                    $current_segment =~ s/\!/ signo de exclamación /g;
                    $current_segment =~ s/\?/ signo de interrogación /g;
                    $current_segment =~ s/\%/ signo de porcentaje /g;
                    $current_segment =~ s/\#/ signo gato /g;
                    $current_segment =~ s/\=/ signo igual a /g;
                    $current_segment =~ s/\+/ signo mas /g;
                    $current_segment =~ s/\$/ signo peso /g;
                    $current_segment =~ s/\&/ signo y /g;
                    $current_segment =~ s/\// $slash /g;
                    $current_segment =~ s/\~/ tilde /g;

                    #print "==>PROCESS-INTERNET-STUFF-AFTPROT=$current_segment\n";    # AD-HOC DEBUGGING

                    # TLDs                                                           #

                    # TLDs with 3+ letters
                    $current_segment =~ s/ punto aero(\W|$)/ punto aero $1/g;
                    $current_segment =~ s/ punto asia(\W|$)/ punto asia $1/g;
                    $current_segment =~ s/ punto biz(\W|$)/ punto bis $1/g;
                    $current_segment =~ s/ punto cat(\W|$)/ punto kat $1/g;
                    $current_segment =~ s/ punto com(\W|$)/ punto kom $1/g;
                    $current_segment =~ s/ punto coop(\W|$)/ punto c o o p $1/g;
                    $current_segment =~ s/ punto edu(\W|$)/ punto e d u $1/g;
                    $current_segment =~ s/ punto gob(\W|$)/ punto g o b $1/g;
                    $current_segment =~ s/ punto gov(\W|$)/ punto g o v $1/g;
                    $current_segment =~ s/ punto info(\W|$)/ punto info $1/g;
                    $current_segment =~ s/ punto int(\W|$)/ punto i n t $1/g;
                    $current_segment =~ s/ punto jobs(\W|$)/ punto jobs $1/g;
                    $current_segment =~ s/ punto mil(\W|$)/ punto m i l $1/g;
                    $current_segment =~ s/ punto mobi(\W|$)/ punto mobi $1/g;
                    $current_segment =~ s/ punto museum(\W|$)/ punto muséum $1/g;
                    $current_segment =~ s/ punto name(\W|$)/ punto  $1/g;
                    $current_segment =~ s/ punto net(\W|$)/ punto net $1/g;
                    $current_segment =~ s/ punto org(\W|$)/ punto o r g $1/g;
                    $current_segment =~ s/ punto pro(\W|$)/ punto pro $1/g;
                    $current_segment =~ s/ punto tel(\W|$)/ punto tel $1/g;
                    $current_segment =~ s/ punto travel(\W|$)/ punto trável $1/g;

                    #print "==>PROCESS-INTERNET-STUFF-AF.xxx=$current_segment\n";    # AD-HOC DEBUGGING

                    # TLDs with 2 letters
                    $current_segment =~ s/ punto ac(\W|$)/ punto a c $1/g;
                    $current_segment =~ s/ punto ad(\W|$)/ punto a d $1/g;
                    $current_segment =~ s/ punto ae(\W|$)/ punto a e $1/g;
                    $current_segment =~ s/ punto af(\W|$)/ punto a f $1/g;
                    $current_segment =~ s/ punto ag(\W|$)/ punto a g $1/g;
                    $current_segment =~ s/ punto ai(\W|$)/ punto a i $1/g;
                    $current_segment =~ s/ punto al(\W|$)/ punto a l $1/g;
                    $current_segment =~ s/ punto am(\W|$)/ punto a m $1/g;
                    $current_segment =~ s/ punto an(\W|$)/ punto a n $1/g;
                    $current_segment =~ s/ punto ao(\W|$)/ punto a o $1/g;
                    $current_segment =~ s/ punto aq(\W|$)/ punto a q $1/g;
                    $current_segment =~ s/ punto ar(\W|$)/ punto a r $1/g;
                    $current_segment =~ s/ punto as(\W|$)/ punto a s $1/g;
                    $current_segment =~ s/ punto at(\W|$)/ punto a t $1/g;
                    $current_segment =~ s/ punto au(\W|$)/ punto a u $1/g;
                    $current_segment =~ s/ punto aw(\W|$)/ punto a w $1/g;
                    $current_segment =~ s/ punto ax(\W|$)/ punto a x $1/g;
                    $current_segment =~ s/ punto az(\W|$)/ punto a z $1/g;
                    $current_segment =~ s/ punto ba(\W|$)/ punto b a $1/g;
                    $current_segment =~ s/ punto bb(\W|$)/ punto b b $1/g;
                    $current_segment =~ s/ punto bd(\W|$)/ punto b d $1/g;
                    $current_segment =~ s/ punto be(\W|$)/ punto b e $1/g;
                    $current_segment =~ s/ punto bf(\W|$)/ punto b f $1/g;
                    $current_segment =~ s/ punto bg(\W|$)/ punto b g $1/g;
                    $current_segment =~ s/ punto bh(\W|$)/ punto b h $1/g;
                    $current_segment =~ s/ punto bi(\W|$)/ punto b i $1/g;
                    $current_segment =~ s/ punto bj(\W|$)/ punto b j $1/g;
                    $current_segment =~ s/ punto bm(\W|$)/ punto b m $1/g;
                    $current_segment =~ s/ punto bn(\W|$)/ punto b n $1/g;
                    $current_segment =~ s/ punto bo(\W|$)/ punto b o $1/g;
                    $current_segment =~ s/ punto br(\W|$)/ punto b r $1/g;
                    $current_segment =~ s/ punto bs(\W|$)/ punto b s $1/g;
                    $current_segment =~ s/ punto bt(\W|$)/ punto b t $1/g;
                    $current_segment =~ s/ punto bv(\W|$)/ punto b v $1/g;
                    $current_segment =~ s/ punto bw(\W|$)/ punto b w $1/g;
                    $current_segment =~ s/ punto by(\W|$)/ punto b igriega $1/g;
                    $current_segment =~ s/ punto bz(\W|$)/ punto b z $1/g;
                    $current_segment =~ s/ punto ca(\W|$)/ punto c a $1/g;
                    $current_segment =~ s/ punto cc(\W|$)/ punto c c $1/g;
                    $current_segment =~ s/ punto cd(\W|$)/ punto c d $1/g;
                    $current_segment =~ s/ punto cf(\W|$)/ punto c f $1/g;
                    $current_segment =~ s/ punto cg(\W|$)/ punto c g $1/g;
                    $current_segment =~ s/ punto ch(\W|$)/ punto c h $1/g;
                    $current_segment =~ s/ punto ci(\W|$)/ punto c i $1/g;
                    $current_segment =~ s/ punto ck(\W|$)/ punto c k $1/g;
                    $current_segment =~ s/ punto cl(\W|$)/ punto c l $1/g;
                    $current_segment =~ s/ punto cm(\W|$)/ punto c m $1/g;
                    $current_segment =~ s/ punto cn(\W|$)/ punto c n $1/g;
                    $current_segment =~ s/ punto co(\W|$)/ punto c o $1/g;
                    $current_segment =~ s/ punto cr(\W|$)/ punto c r $1/g;
                    $current_segment =~ s/ punto cu(\W|$)/ punto c u $1/g;
                    $current_segment =~ s/ punto cv(\W|$)/ punto c v $1/g;
                    $current_segment =~ s/ punto cx(\W|$)/ punto c x $1/g;
                    $current_segment =~ s/ punto cy(\W|$)/ punto c igriega $1/g;
                    $current_segment =~ s/ punto cz(\W|$)/ punto c z $1/g;
                    $current_segment =~ s/ punto de(\W|$)/ punto d e $1/g;
                    $current_segment =~ s/ punto dj(\W|$)/ punto d j $1/g;
                    $current_segment =~ s/ punto dk(\W|$)/ punto d k $1/g;
                    $current_segment =~ s/ punto dm(\W|$)/ punto d m $1/g;
                    $current_segment =~ s/ punto do(\W|$)/ punto d o $1/g;
                    $current_segment =~ s/ punto dz(\W|$)/ punto d z $1/g;
                    $current_segment =~ s/ punto ec(\W|$)/ punto e c $1/g;
                    $current_segment =~ s/ punto ee(\W|$)/ punto e e $1/g;
                    $current_segment =~ s/ punto eg(\W|$)/ punto e g $1/g;
                    $current_segment =~ s/ punto er(\W|$)/ punto e r $1/g;
                    $current_segment =~ s/ punto es(\W|$)/ punto e s $1/g;
                    $current_segment =~ s/ punto et(\W|$)/ punto e t $1/g;
                    $current_segment =~ s/ punto eu(\W|$)/ punto e u $1/g;
                    $current_segment =~ s/ punto fi(\W|$)/ punto f i $1/g;
                    $current_segment =~ s/ punto fj(\W|$)/ punto f j $1/g;
                    $current_segment =~ s/ punto fk(\W|$)/ punto f k $1/g;
                    $current_segment =~ s/ punto fm(\W|$)/ punto f m $1/g;
                    $current_segment =~ s/ punto fo(\W|$)/ punto f o $1/g;
                    $current_segment =~ s/ punto fr(\W|$)/ punto f r $1/g;
                    $current_segment =~ s/ punto ga(\W|$)/ punto g a $1/g;
                    $current_segment =~ s/ punto gb(\W|$)/ punto g b $1/g;
                    $current_segment =~ s/ punto gd(\W|$)/ punto g d $1/g;
                    $current_segment =~ s/ punto ge(\W|$)/ punto g e $1/g;
                    $current_segment =~ s/ punto gf(\W|$)/ punto g f $1/g;
                    $current_segment =~ s/ punto gg(\W|$)/ punto g g $1/g;
                    $current_segment =~ s/ punto gh(\W|$)/ punto g h  $1/g;
                    $current_segment =~ s/ punto gi(\W|$)/ punto g i  $1/g;
                    $current_segment =~ s/ punto gl(\W|$)/ punto g l $1/g;
                    $current_segment =~ s/ punto gm(\W|$)/ punto g m $1/g;
                    $current_segment =~ s/ punto gn(\W|$)/ punto g n $1/g;
                    $current_segment =~ s/ punto gp(\W|$)/ punto g p $1/g;
                    $current_segment =~ s/ punto gq(\W|$)/ punto g q $1/g;
                    $current_segment =~ s/ punto gr(\W|$)/ punto g r $1/g;
                    $current_segment =~ s/ punto gs(\W|$)/ punto g s $1/g;
                    $current_segment =~ s/ punto gt(\W|$)/ punto g t $1/g;
                    $current_segment =~ s/ punto gu(\W|$)/ punto g u $1/g;
                    $current_segment =~ s/ punto gw(\W|$)/ punto g w $1/g;
                    $current_segment =~ s/ punto gy(\W|$)/ punto g igriega $1/g;
                    $current_segment =~ s/ punto hk(\W|$)/ punto h k $1/g;
                    $current_segment =~ s/ punto hm(\W|$)/ punto h m $1/g;
                    $current_segment =~ s/ punto hn(\W|$)/ punto h n $1/g;
                    $current_segment =~ s/ punto hr(\W|$)/ punto h r $1/g;
                    $current_segment =~ s/ punto ht(\W|$)/ punto h t $1/g;
                    $current_segment =~ s/ punto hu(\W|$)/ punto h u $1/g;
                    $current_segment =~ s/ punto id(\W|$)/ punto i d $1/g;
                    $current_segment =~ s/ punto ie(\W|$)/ punto i e $1/g;
                    $current_segment =~ s/ punto il(\W|$)/ punto i l $1/g;
                    $current_segment =~ s/ punto im(\W|$)/ punto i m $1/g;
                    $current_segment =~ s/ punto in(\W|$)/ punto i n $1/g;
                    $current_segment =~ s/ punto io(\W|$)/ punto i o $1/g;
                    $current_segment =~ s/ punto iq(\W|$)/ punto i q $1/g;
                    $current_segment =~ s/ punto ir(\W|$)/ punto i r $1/g;
                    $current_segment =~ s/ punto is(\W|$)/ punto i s $1/g;
                    $current_segment =~ s/ punto it(\W|$)/ punto i t $1/g;
                    $current_segment =~ s/ punto je(\W|$)/ punto j e $1/g;
                    $current_segment =~ s/ punto jm(\W|$)/ punto j m $1/g;
                    $current_segment =~ s/ punto jo(\W|$)/ punto j o $1/g;
                    $current_segment =~ s/ punto jp(\W|$)/ punto j p $1/g;
                    $current_segment =~ s/ punto ke(\W|$)/ punto k e $1/g;
                    $current_segment =~ s/ punto kg(\W|$)/ punto k g $1/g;
                    $current_segment =~ s/ punto kh(\W|$)/ punto k h $1/g;
                    $current_segment =~ s/ punto ki(\W|$)/ punto k i $1/g;
                    $current_segment =~ s/ punto km(\W|$)/ punto k m $1/g;
                    $current_segment =~ s/ punto kn(\W|$)/ punto k n $1/g;
                    $current_segment =~ s/ punto kp(\W|$)/ punto k p $1/g;
                    $current_segment =~ s/ punto kr(\W|$)/ punto k r $1/g;
                    $current_segment =~ s/ punto kw(\W|$)/ punto k w $1/g;
                    $current_segment =~ s/ punto ky(\W|$)/ punto k igriega $1/g;
                    $current_segment =~ s/ punto kz(\W|$)/ punto k z $1/g;
                    $current_segment =~ s/ punto la(\W|$)/ punto l a $1/g;
                    $current_segment =~ s/ punto lb(\W|$)/ punto l b $1/g;
                    $current_segment =~ s/ punto lc(\W|$)/ punto l c $1/g;
                    $current_segment =~ s/ punto li(\W|$)/ punto l i $1/g;
                    $current_segment =~ s/ punto lk(\W|$)/ punto l k $1/g;
                    $current_segment =~ s/ punto lr(\W|$)/ punto l r $1/g;
                    $current_segment =~ s/ punto ls(\W|$)/ punto l s $1/g;
                    $current_segment =~ s/ punto lt(\W|$)/ punto l t $1/g;
                    $current_segment =~ s/ punto lu(\W|$)/ punto l u $1/g;
                    $current_segment =~ s/ punto lv(\W|$)/ punto l v $1/g;
                    $current_segment =~ s/ punto ly(\W|$)/ punto l igriega $1/g;
                    $current_segment =~ s/ punto ma(\W|$)/ punto m a $1/g;
                    $current_segment =~ s/ punto mc(\W|$)/ punto m c $1/g;
                    $current_segment =~ s/ punto md(\W|$)/ punto m d $1/g;
                    $current_segment =~ s/ punto me(\W|$)/ punto m e $1/g;
                    $current_segment =~ s/ punto mg(\W|$)/ punto m g $1/g;
                    $current_segment =~ s/ punto mh(\W|$)/ punto m h $1/g;
                    $current_segment =~ s/ punto mk(\W|$)/ punto m k $1/g;
                    $current_segment =~ s/ punto ml(\W|$)/ punto m l $1/g;
                    $current_segment =~ s/ punto mm(\W|$)/ punto m m $1/g;
                    $current_segment =~ s/ punto mn(\W|$)/ punto m n $1/g;
                    $current_segment =~ s/ punto mo(\W|$)/ punto m o $1/g;
                    $current_segment =~ s/ punto mp(\W|$)/ punto m p $1/g;
                    $current_segment =~ s/ punto mq(\W|$)/ punto m q $1/g;
                    $current_segment =~ s/ punto mr(\W|$)/ punto m r $1/g;
                    $current_segment =~ s/ punto ms(\W|$)/ punto m s $1/g;
                    $current_segment =~ s/ punto mt(\W|$)/ punto m t $1/g;
                    $current_segment =~ s/ punto mu(\W|$)/ punto m u $1/g;
                    $current_segment =~ s/ punto mv(\W|$)/ punto m v $1/g;
                    $current_segment =~ s/ punto mw(\W|$)/ punto m w $1/g;
                    $current_segment =~ s/ punto mx(\W|$)/ punto m x $1/g;
                    $current_segment =~ s/ punto my(\W|$)/ punto m igriega $1/g;
                    $current_segment =~ s/ punto mz(\W|$)/ punto m z $1/g;
                    $current_segment =~ s/ punto na(\W|$)/ punto n a $1/g;
                    $current_segment =~ s/ punto nc(\W|$)/ punto n c $1/g;
                    $current_segment =~ s/ punto ne(\W|$)/ punto n e $1/g;
                    $current_segment =~ s/ punto nf(\W|$)/ punto n f $1/g;
                    $current_segment =~ s/ punto ng(\W|$)/ punto n g $1/g;
                    $current_segment =~ s/ punto ni(\W|$)/ punto n i $1/g;
                    $current_segment =~ s/ punto nl(\W|$)/ punto n l $1/g;
                    $current_segment =~ s/ punto no(\W|$)/ punto n o $1/g;
                    $current_segment =~ s/ punto np(\W|$)/ punto n p $1/g;
                    $current_segment =~ s/ punto nr(\W|$)/ punto n r $1/g;
                    $current_segment =~ s/ punto nu(\W|$)/ punto n u $1/g;
                    $current_segment =~ s/ punto nz(\W|$)/ punto n z $1/g;
                    $current_segment =~ s/ punto om(\W|$)/ punto o m $1/g;
                    $current_segment =~ s/ punto pa(\W|$)/ punto p a $1/g;
                    $current_segment =~ s/ punto pe(\W|$)/ punto p e $1/g;
                    $current_segment =~ s/ punto pf(\W|$)/ punto p f $1/g;
                    $current_segment =~ s/ punto pg(\W|$)/ punto p g $1/g;
                    $current_segment =~ s/ punto ph(\W|$)/ punto p h $1/g;
                    $current_segment =~ s/ punto pk(\W|$)/ punto p k $1/g;
                    $current_segment =~ s/ punto pl(\W|$)/ punto p l $1/g;
                    $current_segment =~ s/ punto pm(\W|$)/ punto p m $1/g;
                    $current_segment =~ s/ punto pn(\W|$)/ punto p n $1/g;
                    $current_segment =~ s/ punto pr(\W|$)/ punto p r $1/g;
                    $current_segment =~ s/ punto ps(\W|$)/ punto p s $1/g;
                    $current_segment =~ s/ punto pt(\W|$)/ punto p t $1/g;
                    $current_segment =~ s/ punto pw(\W|$)/ punto p w $1/g;
                    $current_segment =~ s/ punto py(\W|$)/ punto p y $1/g;
                    $current_segment =~ s/ punto qa(\W|$)/ punto q a $1/g;
                    $current_segment =~ s/ punto re(\W|$)/ punto r e $1/g;
                    $current_segment =~ s/ punto ro(\W|$)/ punto r o $1/g;
                    $current_segment =~ s/ punto rs(\W|$)/ punto r s $1/g;
                    $current_segment =~ s/ punto ru(\W|$)/ punto r u $1/g;
                    $current_segment =~ s/ punto rw(\W|$)/ punto r w $1/g;
                    $current_segment =~ s/ punto sa(\W|$)/ punto s a $1/g;
                    $current_segment =~ s/ punto sb(\W|$)/ punto s b $1/g;
                    $current_segment =~ s/ punto sc(\W|$)/ punto s c $1/g;
                    $current_segment =~ s/ punto sd(\W|$)/ punto s d $1/g;
                    $current_segment =~ s/ punto se(\W|$)/ punto s e $1/g;
                    $current_segment =~ s/ punto sg(\W|$)/ punto s g $1/g;
                    $current_segment =~ s/ punto sh(\W|$)/ punto s h $1/g;
                    $current_segment =~ s/ punto si(\W|$)/ punto s i $1/g;
                    $current_segment =~ s/ punto sj(\W|$)/ punto s j $1/g;
                    $current_segment =~ s/ punto sk(\W|$)/ punto s k $1/g;
                    $current_segment =~ s/ punto sl(\W|$)/ punto s l $1/g;
                    $current_segment =~ s/ punto sm(\W|$)/ punto s m $1/g;
                    $current_segment =~ s/ punto sn(\W|$)/ punto s n $1/g;
                    $current_segment =~ s/ punto so(\W|$)/ punto s o $1/g;
                    $current_segment =~ s/ punto sr(\W|$)/ punto s r $1/g;
                    $current_segment =~ s/ punto st(\W|$)/ punto s t $1/g;
                    $current_segment =~ s/ punto su(\W|$)/ punto s u $1/g;
                    $current_segment =~ s/ punto sv(\W|$)/ punto s v $1/g;
                    $current_segment =~ s/ punto sy(\W|$)/ punto s y $1/g;
                    $current_segment =~ s/ punto sz(\W|$)/ punto s z $1/g;
                    $current_segment =~ s/ punto tc(\W|$)/ punto t c $1/g;
                    $current_segment =~ s/ punto td(\W|$)/ punto t d $1/g;
                    $current_segment =~ s/ punto tf(\W|$)/ punto t f $1/g;
                    $current_segment =~ s/ punto tg(\W|$)/ punto t g $1/g;
                    $current_segment =~ s/ punto th(\W|$)/ punto t h $1/g;
                    $current_segment =~ s/ punto tj(\W|$)/ punto t j $1/g;
                    $current_segment =~ s/ punto tk(\W|$)/ punto t k $1/g;
                    $current_segment =~ s/ punto tl(\W|$)/ punto t l $1/g;
                    $current_segment =~ s/ punto tm(\W|$)/ punto t m $1/g;
                    $current_segment =~ s/ punto tn(\W|$)/ punto t n $1/g;
                    $current_segment =~ s/ punto to(\W|$)/ punto t o $1/g;
                    $current_segment =~ s/ punto tp(\W|$)/ punto t p $1/g;
                    $current_segment =~ s/ punto tr(\W|$)/ punto t r $1/g;
                    $current_segment =~ s/ punto tt(\W|$)/ punto t t $1/g;
                    $current_segment =~ s/ punto tv(\W|$)/ punto t v $1/g;
                    $current_segment =~ s/ punto tw(\W|$)/ punto t w $1/g;
                    $current_segment =~ s/ punto tz(\W|$)/ punto t z $1/g;
                    $current_segment =~ s/ punto ua(\W|$)/ punto u a $1/g;
                    $current_segment =~ s/ punto ug(\W|$)/ punto u g $1/g;
                    $current_segment =~ s/ punto uk(\W|$)/ punto u k $1/g;
                    $current_segment =~ s/ punto us(\W|$)/ punto u s $1/g;
                    $current_segment =~ s/ punto uy(\W|$)/ punto u igriega $1/g;
                    $current_segment =~ s/ punto uz(\W|$)/ punto u z $1/g;
                    $current_segment =~ s/ punto va(\W|$)/ punto v a $1/g;
                    $current_segment =~ s/ punto vc(\W|$)/ punto v c $1/g;
                    $current_segment =~ s/ punto ve(\W|$)/ punto v e $1/g;
                    $current_segment =~ s/ punto vg(\W|$)/ punto v g $1/g;
                    $current_segment =~ s/ punto vi(\W|$)/ punto v i $1/g;
                    $current_segment =~ s/ punto vn(\W|$)/ punto v n $1/g;
                    $current_segment =~ s/ punto vu(\W|$)/ punto v u $1/g;
                    $current_segment =~ s/ punto wf(\W|$)/ punto w f $1/g;
                    $current_segment =~ s/ punto ws(\W|$)/ punto w s $1/g;
                    $current_segment =~ s/ punto ye(\W|$)/ punto igriega  $1/g;
                    $current_segment =~ s/ punto yt(\W|$)/ punto igriega  $1/g;
                    $current_segment =~ s/ punto za(\W|$)/ punto z a $1/g;
                    $current_segment =~ s/ punto zm(\W|$)/ punto z m $1/g;
                    $current_segment =~ s/ punto zw(\W|$)/ punto z w $1/g;
               }

               #print "==>PROCESS-INTERNET-STUFF-AFT.xx=$current_segment\n";    # AD-HOC DEBUGGING
          }
          else {
               #######################################################################
               # ELIMINATE URLs, replacing them with a space                         #
               #######################################################################
               $current_segment =~ s/<?(http|https|ftp|sftp|gopher|news|mailto|file):\/\/\S+/ /g;
          }

          ############################################################################
          # PROCESS e-mail addresses as linguistic strings, if desired               #
          ############################################################################

          if ( $process_email == 1 ) {

               #if ( $current_segment =~ m/[\w\-\.\+]+\@[\w.]+/ ) {
               if ( $current_segment =~ m/[\w\-\.\+]+\@[\w.]+/ ) {

                    # WARNING: MODIFIED IN 393
                    #
                    # CHANGE "-" IN E-MAIL ADDRESSES TO "GUIÓN"                                  #
                    # This can't be applied globally (i.e. in non-mail addresses) b/c it would   #
                    # break processing of dashes in compounds (e.g. "post-alveolar").            #

                    # WARNING: VRT: Might be broken as of 402

                    if ( $vrt_format == 1 ) {
                         $current_segment =~ s/\-/¬guión¬/g;
                         $current_segment =~ s/\-/¬guión¬/g;
                         $current_segment =~ s/\@/¬arroba¬/g;
                         $current_segment =~ s/\_/¬guión bajo¬/g;
                         $current_segment =~ s/\./¬punto¬/g;
                         $current_segment =~ s/\+/¬signo mas¬/g;
                    }
                    else {
                         $current_segment =~ s/\-/ guión /g;
                         $current_segment =~ s/\@/ arroba /g;
                         $current_segment =~ s/\_/ guión bajo /g;
                         $current_segment =~ s/\./ punto /g;
                         $current_segment =~ s/\+/ signo mas /g;

                         #print STDOUT "***PROCESS E-MAIL (no VRT) subroutine executed\n";
                    }
               }
          }
          else {
               #######################################################################
               # ELIMINATE e-mail addresses, replacing them with a space             #
               #######################################################################
               $current_segment =~ s/[\w\-\.\+]+\@[\w]+\.?[\w]+\.?[\w]+\.?[\w]+(\.?)[\w]+/ /g;

               #print STDOUT "***ELIMINATE E-MAIL subroutine executed\n";
          }

          #print "==>PROCESS-INTERNET-STUFF---END=$current_segment\n\n";    # AD-HOC DEBUGGING

          # CHANGE "." WHEN IT IS SURROUNDED BY LETTERS TO "PUNTO".  FOR URLs, MAINLY     #

          # WARNING: VRT: Might be broken as of 402

          if ( $vrt_format == 1 ) {
               $current_segment =~ s/([a-zA-Z]+)øøø([a-zA-Z]+)/$1¬punto¬$2/g;
               $current_segment =~ s/([a-zA-Z]+)øøø([a-zA-Z]+)/$1¬punto¬$2/g;    # Not sure why the prev line doesn't catch all instances...
               $current_segment =~ s/([a-zA-Z]+)øøø([a-zA-Z]+)/$1¬punto¬$2/g;    # This is here just for good measure.
               $current_segment =~ s/([a-zA-Z]+)øøø([a-zA-Z]+)/$1¬punto¬$2/g;    # Ditto.
               $current_segment =~ s/([a-zA-Z]+)øøø([a-zA-Z]+)/$1¬punto¬$2/g;    # Ditto.
          }
          else {
               $current_segment =~ s/([a-zA-Z]+)\.([a-zA-Z]+)/$1 punto $2/g;
               $current_segment =~ s/([a-zA-Z]+)\.([a-zA-Z]+)/$1 punto $2/g;          # Not sure why the prev line doesn't catch all instances...
               $current_segment =~ s/([a-zA-Z]+)\.([a-zA-Z]+)/$1 punto $2/g;          # This is here just for good measure.
               $current_segment =~ s/([a-zA-Z]+)\.([a-zA-Z]+)/$1 punto $2/g;          # Ditto.
               $current_segment =~ s/([a-zA-Z]+)\.([a-zA-Z]+)/$1 punto $2/g;          # Ditto.
          }

          #print "==>EXPER-INT-STUFF-SPLIT----END=$current_segment\n";                 # AD-HOC DEBUG
     }

     $current_item = join( " ", @current_segments );

     return ($current_item);

}    # END SUBROUTINE: PROCESS INTERNET STUFF

##############################################################################
#                                                                            #
#   SUBROUTINE: FIX MISCELLANEOUS PUNCTUATION                                #
#                                                                            #
##############################################################################
sub fix_misc_punctuation {

     # Read value passed into subroutine and assign it to $current_item         #
     my $current_item = $_[0];

     ############################################################################
     # INSERT .VRT FORMAT PLACEHOLDERS                                      #
     # This protects characters that would otherwise be eliminated.              #
     ############################################################################
     # WARNING: Added in 402

     if ( $vrt_format == 1 ) {

          #$temp = Encode::encode_utf8($current_item);    # AD-HOC DEBUG
          #print STDOUT "\nVRT-FORMAT-PLCHLD-BEF:$temp:\n";    # AD-HOC DEBUG

          # Things that appear alone on a line
          $current_item =~ s/^$/øø/g;          # Blank line
          $current_item =~ s/^\.$/þ/g;          # Period
          $current_item =~ s/^,$/¢/g;           # Comma
          $current_item =~ s/^\:$/ĸ/g;          # Colon
          $current_item =~ s/^\;$/ĸ/g;          # Semi-colon
          $current_item =~ s/^\-$/ð/g;          # Dash
          $current_item =~ s/^\"$/ł/g;          # Quotation mark
          $current_item =~ s/^¿$/ŋ/g;          # Opening question mark
          $current_item =~ s/^\+$/øø/g;        # Plus sign
          $current_item =~ s/^\.\.\.$/øø/g;    # Ellipsis
          $current_item =~ s/^\@$/øø/g;        # At sign

          # Things that don't necessarily have to appear alone on a line
          $current_item =~ s/\(/ø/g;            # Open paren.
          $current_item =~ s/\)/ø/g;            # Close paren.
          $current_item =~ s/¡/øø/g;          # Opening exclamation point
          $current_item =~ s/#/øø/g;           # Number sign
          $current_item =~ s/º/øø/g;          # Male ord.
          $current_item =~ s/ª/øø/g;          # Female ord.
          $current_item =~ s/°/øø/g;          # Degree symbol
          $current_item =~ s/\\/øø/g;          # Backslash
          $current_item =~ s/\|/øø/g;          # Pipe
          $current_item =~ s/\€/ euros /g;     # Euro sign
          $current_item =~ s/&/øø/g;           # Ampersand
          $current_item =~ s/~/øø/g;           # Tilde
          $current_item =~ s/\^/øø/g;          # Carat
          $current_item =~ s/'/øø/g;           # Apostrophe
          $current_item =~ s/\*/øø/g;          # Asterisk
          $current_item =~ s/_/øø/g;           # Underscore

          #$temp = Encode::encode_utf8($current_item);      # AD-HOC DEBUG
          #print STDOUT "VRT-FORMAT-PLCHLD-AFT:$temp:\n";   # AD-HOC DEBUG

     }

     #   ADD SPACE AFTER PERIOD+BRACKETS (to prevent problems with .[ .( in cites #
     $current_item =~ s/\.[\[\]\{\}\(\}]/\. /g;

     # PROCESS QUOTATION MARKS                                                    #

     # Connexor maintains quotation marks, assigning them to their own line. Thus #
     # for the .vrt format, these must be preserved.                              #
     if ( $vrt_format == 1 ) {
          $current_item =~ s/"/½/g;
     }

     # Remove quotation marks in all other cases.                                 #
     else {
          $current_item =~ s/"//g;
     }

     # ELIMINATE ELLIPSES AT BEGINNING OF LINE                                    #
     $current_item =~ s/^\.\.\.//g;

     # ADD SPACES AROUND ELLIPSES
     $current_item =~ s/\.\.\./ \.\.\. /g;

     # ADD SPACE AFTER ). COMBINATION   NOTE NEW IN 2-9-1                         #
     $current_item =~ s/\)\./\)\. /g;

     # ADD SPACE AFTER )      NOTE NEW IN 2-9-1                                   #
     $current_item =~ s/\)/\) /g;

     # ADD SPACE BEFORE (     NOTE NEW IN 2-9-1                                   #
     $current_item =~ s/\(/ \(/g;

     # print "\n==>  DASH PROCESSING BEF:: $current_item";   # DEBUG

     ##############################################################################
     # Replace em and en dashes with "--"                                         #
     ##############################################################################
     # NEW IN 401: Changed replacement from "-" to "--"
     $current_item =~ s//--/g;
     $current_item =~ s/–/--/g;
     $current_item =~ s/—/--/g;

     ##############################################################################
     # REMOVE SINGLE DASH WITH LETTERS TOUCHING ON BOTH SIDES: FOR COMPOUND WORDS #
     # (e.g. "tetra-pack", "Bío-Bío", "palato-alveolar".                          #
     ##############################################################################
     $current_item =~ s/([a-z])-([a-z])-([a-z])/$1 $2 $3/g;    # For possible phrases with two dashes
     $current_item =~ s/([a-z])-([a-z])/$1 $2/g;

     ############################################################################
     # SEPARATE LETTERS FROM NUMBERS IN WORDS CONSISTING OF LETTERS+NUMBERS     #
     # OR LETTER + DASH + NUMBER (e.g. F0, mc2, t1000, T-1000)                  #
     ############################################################################
     #print STDOUT "SEPARATE-LETTS-FROM-NUMS-BEF:$current_item\n"; # AD-HOC DEBUG

     # Letter+Numbers
     $current_item =~ s/(\W|^)([a-záéíóúñ]+)([0-9]+)(\W|$)/ $1$2 $3$4 /g;
     $current_item =~ s/(\W|^)([a-záéíóúñ]+)([0-9]+)(\W|$)/ $1$2 $3$4 /g;    # This repetition is NECESSARY.

     # Letter+Dash+Numbers
     $current_item =~ s/(\W|^)([a-záéíóúñ]+)\-([0-9]+)(\W|$)/ $1$2 $3$4 /g;

     #print STDOUT "SEPARATE-LETTS-FROM-NUMS-AFT:$current_item\n"; # AD-HOC DEBUG

     ##############################################################################
     # CHANGE MATHEMATICAL OPERATORS BETWEEN NUMERALS INTO WORDS                  #
     # (e.g. "12.345.678-9", 10-2=6)                                              #
     ##############################################################################
     $current_item =~ s/([0-9])\.([0-9][0-9][0-9])\.([0-9][0-9][0-9])( |)-( |)([0-9])/$1.$2.$3 guión $6/g;    # Process Chilean RUT numbers
     $current_item =~ s/([0-9])( |)\-( |)([0-9])/$1 menos $4/g;
     $current_item =~ s/([0-9])( |)=( |)([0-9])/$1 es igual a $4/g;
     $current_item =~ s/([0-9])( |)\+( |)([0-9])/$1 más $4/g;
     $current_item =~ s/([0-9])( |)\/( |)([0-9])/$1 dividido por $4/g;
     $current_item =~ s/([0-9])( |)\*( |)([0-9])/$1 multiplicado por $4/g;

     # NOTE Added in 380
     $current_item =~ s/([0-9])( |)×( |)([0-9])/$1 multiplicado por $4/g;
     $current_item =~ s/±( |)([0-9])/ más o menos $1$2/g;                  # This symbol can just have a num after it

     ############################################################################
     # CONVERT 2 or 3 DASHES INTO COMMA (TO MAKE PAUSE).                        #
     # (e.g. "se fue -- rápidamente --- y lloró".                               #
     # ONLY for non-VRT formats.                                                #
     ############################################################################
     if ( $vrt_format == 0 ) {
          $current_item =~ s/\-\-\-/, /g;
          $current_item =~ s/\-\-/, /g;
     }
     else {                                                                  # NEW IN 401: Change long dashes to "guión" for VRT format  #
          $current_item =~ s/\-\-\-/ guión /g;
          $current_item =~ s/\-\-/ guión /g;
     }

     ###########################################################################
     # CONVERT REMAINING CASES OF 1 DASH INTO COMMA + SPACE (TO MAKE PAUSE)    #
     ###########################################################################
     $current_item =~ s/\-/, /g;

     # print "\n==  DASH PROCESSING AFT:: $current_item";   # DEBUG

     ###########################################################################
     # ELIMINATE MOST PUNCTUATION AT END OF WORD (UTTERANCE) FOR VRT       #
     ###########################################################################
     # WARNING: Added in 401
     if ( $vrt_format == 1 ) {

          # NEW IN 402: Removed "\>" from search expression, to preserve <s> and <p>
          $current_item =~ s/(\,|\-|\_|\@|\+|\&|\.) *$//g;
     }

     ###########################################################################
     # CONVERT COMMAS INTO THE WORD "kó.ma"                                    #
     ###########################################################################
     # WARNING: Added in 401
     if ( $vrt_format == 1 ) {
          $current_item =~ s/ , / coma /g;
     }

     return ($current_item);

}    # END SUBROUTINE: FIX MISC PUNCTUATION

#################################################################################
#                                                                               #
#   SUBROUTINE: EXPAND ABBREVIATIONS IN ORTHOGRAPHIC FORM                       #
#                                                                               #
#################################################################################
sub expand_abbreviations_ortho {

     my $current_item = $_[0];

     ############################################################################
     # Process abbreviations in .VRT files                                      #
     ############################################################################
     if ( $vrt_format == 1 ) {

          #print STDOUT "VRT_ORTHO-ABBRV-BEF:$current_item\n";

          # VRT: ABBREVIATIONS WITH SLASHES
          $current_item =~ s/^a\/c$/a cuenta/g;
          $current_item =~ s/^a\/f$/a favor/g;
          $current_item =~ s/^c\/u$/cada uno/g;
          $current_item =~ s/^s\/a$/sin año/g;
          $current_item =~ s/^s\/e$/sin editorial/g;
          $current_item =~ s/^s\/f$/sin fecha/g;
          $current_item =~ s/^s\/l$/sin lugar/g;
          $current_item =~ s/^s\/n$/sin número/g;
          $current_item =~ s/^v\/s$/versus/g;
          $current_item =~ s/^y\/o$/i o/g;

          # VRT: ABBREVIATIONS WITH TWO PERIODS
          $current_item =~ s/^a\.c(|\.)$/ántes de crísto/g;
          $current_item =~ s/^a\.d(|\.)$/áno dómini/g;
          $current_item =~ s/^a\.de(|\.)$/ántes de/g;
          $current_item =~ s/^a\.de¬c(|\.)$/ántes de crísto/g;
          $current_item =~ s/^a\.m(|\.)$/ánte merídiem/g;
          $current_item =~ s/^a\.r(|\.)$/altéza reál/g;
          $current_item =~ s/^a\.t(|\.)$/antíguo testaménto/g;
          $current_item =~ s/^bs\.as(|\.)$/buénos áires/g;
          $current_item =~ s/^c\.a(|\.)$/compañía anónima/g;
          $current_item =~ s/^cap\.fed(|\.)$/capitál federál/g;
          $current_item =~ s/^c\.f(|\.)$/capitál federál/g;
          $current_item =~ s/^c\.i(|\.)$/cédula de identidád/g;
          $current_item =~ s/^c\.p(|\.)$/código postál/g;
          $current_item =~ s/^d\.de(|\.)$/después de/g;
          $current_item =~ s/^d\.c(|\.)$/después de crísto/g;
          $current_item =~ s/^d\.de¬c(|\.)$/después de crísto/g;
          $current_item =~ s/^dd\.hh$/deréchos humános/g;
          $current_item =~ s/^d\.f(|\.)$/distríto federál/g;
          $current_item =~ s/^e\.c(|\.)$/éra común/g;
          $current_item =~ s/^ee\.uu(|\.)$/estádos unídos/g;
          $current_item =~ s/^e\.u(|\.)$/estádos unídos/g;
          $current_item =~ s/^f\.c(|\.)$/ferrocarríl/g;
          $current_item =~ s/^ff\.aa(|\.)$/fuérzas armádas/g;
          $current_item =~ s/^ff\.cc(|\.)$/ferrocarríles/g;
          $current_item =~ s/^ff\.ee(|\.)$/ferrocarríles del estádo/g;
          $current_item =~ s/^i\.e(|\.)$/íd ést/g;
          $current_item =~ s/^jj\.cc(|\.)$/juventúdes comunístas/g;
          $current_item =~ s/^jj\.oo(|\.)$/juégos olímpicos/g;
          $current_item =~ s/^k\.o(|\.)$/nocáut/g;
          $current_item =~ s/^l\.c(|\.)$/lóco citáto/g;
          $current_item =~ s/^loc\.cit(|\.)$/lóco citáto/g;
          $current_item =~ s/^m\.n(|\.)$/monéda nacionál/g;
          $current_item =~ s/^n\.b(|\.)$/nóta béne/g;
          $current_item =~ s/^n\.del(|\.)$/nóta del/g;
          $current_item =~ s/^ob\.cit(|\.)$/óbra citáda/g;
          $current_item =~ s/^oo\.pp(|\.)$/óbras públicas/g;
          $current_item =~ s/^óp\.cit(|\.)$/ópere citáto/g;
          $current_item =~ s/^p\.d(|\.)$/posdáta/g;
          $current_item =~ s/^p\.ej(|\.)$/por ejémplo/g;
          $current_item =~ s/^p\.ejem(|\.)$/por ejémplo/g;
          $current_item =~ s/^p\.m(|\.)$/póst merídiem/g;
          $current_item =~ s/^p\.s(|\.)$/póst scríptum/g;
          $current_item =~ s/^rr\.hh(|\.)$/recúrsos humános/g;
          $current_item =~ s/^s\.a(|\.)$/sin áño/g;
          $current_item =~ s/^s\.a(|\.)$/sociedád anónima/g;
          $current_item =~ s/^s\.d(|\.)$/síne dáta/g;
          $current_item =~ s/^s\.f(|\.)$/sín fécha/g;
          $current_item =~ s/^s\.l(|\.)$/sín lugár/g;
          $current_item =~ s/^s\.n(|\.)$/sín número/g;
          $current_item =~ s/^u\.e(|\.)$/unión européa/g;
          $current_item =~ s/^v\.g(|\.)$/vérbi grátia/g;
          $current_item =~ s/^v\.gr(|\.)$/vérbi grátia/g;
          $current_item =~ s/^v\.s(|\.)$/vuéstra señoría/g;
          $current_item =~ s/^w\.c(|\.)$/doblevesé/g;

          # VRT: ABBREVIATIONS WITH THREE PERIODS
          $current_item =~ s/^a\.de¬j\.c(|\.)$/ántes de jesucrísto/g;
          $current_item =~ s/^a\.j\.c(|\.)$/ántes de jesucrísto/g;
          $current_item =~ s/^d\.de¬j\.c(|\.)$/después de jesucrísto/g;
          $current_item =~ s/^d\.j\.c(|\.)$/después de jesucrísto/g;
          $current_item =~ s/^o\.e\.a(|\.)$/oéa/g;
          $current_item =~ s/^o\.n\.u(|\.)$/ónu/g;
          $current_item =~ s/^p\.v\.p(|\.)$/précio de vénta al público/g;
          $current_item =~ s/^r\.p\.m(|\.)$/revoluciónes por minúto/g;

          # VRT: ABBREVIATIONS WITH NO PUNCTUATION, BUT ODD CHARACTERS
          $current_item =~ s/^n°$/número /g;
          $current_item =~ s/^nº$/número /g;
          $current_item =~ s/^v°( |)b°$/vísto buéno/g;
          $current_item =~ s/^vº( |)bº$/vísto buéno/g;

          # VRT: ABBREVIATIONS WITH ONE PERIOD, AT END.
          $current_item =~ s/^afma(|\.)$/afectísima/g;
          $current_item =~ s/^afmo(|\.)$/afectísimo/g;
          $current_item =~ s/^alfz(|\.)$/alférez/g;
          $current_item =~ s/^almte(|\.)$/almirante/g;
          $current_item =~ s/^apdo(|\.)$/apartado/g;
          $current_item =~ s/^art(|\.)$/artículo/g;
          $current_item =~ s/^arz(|\.)$/arzobispo/g;
          $current_item =~ s/^atta(|\.)$/atenta/g;
          $current_item =~ s/^atte(|\.)$/atentamente/g;
          $current_item =~ s/^atto(|\.)$/atento/g;
          $current_item =~ s/^av(|\.)$/avenida/g;
          $current_item =~ s/^avda(|\.)$/avenida/g;
          $current_item =~ s/^bco(|\.)$/banco/g;
          $current_item =~ s/^bibl(|\.)$/biblioteca/g;
          $current_item =~ s/^cap(|\.)$/capítulo/g;
          $current_item =~ s/^cént(|\.)$/céntimo/g;
          $current_item =~ s/^cf(|\.)$/confere/g;
          $current_item =~ s/^cfr(|\.)$/confere/g;
          $current_item =~ s/^cía(|\.)$/compañía/g;
          $current_item =~ s/^cmdt(|\.)$/comandante/g;
          $current_item =~ s/^cmte(|\.)$/comandante/g;
          $current_item =~ s/^cnel(|\.)$/coronel/g;
          $current_item =~ s/^cód(|\.)$/código/g;
          $current_item =~ s/^comod(|\.)$/comodoro/g;
          $current_item =~ s/^comte(|\.)$/comandante/g;
          $current_item =~ s/^conf(|\.)$/confere/g;
          $current_item =~ s/^cónf(|\.)$/confere/g;
          $current_item =~ s/^confr(|\.)$/confere/g;
          $current_item =~ s/^cónfr(|\.)$/confere/g;
          $current_item =~ s/^contralmte(|\.)$/contralmirante/g;
          $current_item =~ s/^coord(|\.)$/coordinador/g;
          $current_item =~ s/^cp(|\.)$/compárese/g;
          $current_item =~ s/^cta(|\.)$/cuenta/g;
          $current_item =~ s/^cte(|\.)$/corriente/g;
          $current_item =~ s/^ctv(|\.)$/centavo/g;
          $current_item =~ s/^ctvo(|\.)$/centavo/g;
          $current_item =~ s/^depto(|\.)$/departamento/g;
          $current_item =~ s/^der(|\.)$/derecho/g;
          $current_item =~ s/^diag(|\.)$/diagonal/g;
          $current_item =~ s/^dicc(|\.)$/diccionario/g;
          $current_item =~ s/^dir(|\.)$/director/g;
          $current_item =~ s/^dn(|\.)$/don/g;
          $current_item =~ s/^dña(|\.)$/doña/g;
          $current_item =~ s/^dpto(|\.)$/departamento/g;
          $current_item =~ s/^dr(|\.)$/doctor/g;
          $current_item =~ s/^dra(|\.)$/doctora/g;
          $current_item =~ s/^edo(|\.)$/estado/g;
          $current_item =~ s/^ej(|\.)$/ejemplo/g;
          $current_item =~ s/^et ál(|\.)$/et álii/g;
          $current_item =~ s/^etc(|\.)$/etcétera/g;
          $current_item =~ s/^etc\.(|\.)$/etcétera\./g;           # Catch "etc..", i.e. "etc." at end of sentence.
          $current_item =~ s/^excmo(|\.)$/excelentísimo/g;
          $current_item =~ s/^fdo(|\.)$/firmado/g;
          $current_item =~ s/^fig(|\.)$/figura/g;
          $current_item =~ s/^gen(|\.)$/general/g;
          $current_item =~ s/^gral(|\.)$/general/g;
          $current_item =~ s/^ib(|\.)$/ibídem/g;
          $current_item =~ s/^ibíd(|\.)$/ibídem/g;
          $current_item =~ s/^íd(|\.)$/ídem/g;
          $current_item =~ s/^ilmo(|\.)$/ilustrísimo/g;
          $current_item =~ s/^incl(|\.)$/inclusive/g;
          $current_item =~ s/^izq(|\.)$/izquierda/g;
          $current_item =~ s/^lcda(|\.)$/licenciada/g;
          $current_item =~ s/^lcdo(|\.)$/licenciado/g;
          $current_item =~ s/^lic(|\.)$/licenciado/g;
          $current_item =~ s/^ltda(|\.)$/limitada/g;
          $current_item =~ s/^ltdo(|\.)$/limitado/g;
          $current_item =~ s/^máx(|\.)$/máximo/g;
          $current_item =~ s/^mín(|\.)$/mínimo/g;
          $current_item =~ s/^mons(|\.)$/monseñor/g;
          $current_item =~ s/^ms(|\.)$/manuscrito/g;
          $current_item =~ s/^ne(|\.)$/noreste/g;
          $current_item =~ s/^nro(|\.)$/número/g;
          $current_item =~ s/^ntra(|\.)$/nuestra/g;
          $current_item =~ s/^ntro(|\.)$/nuestro/g;
          $current_item =~ s/^núm(|\.)$/número/g;
          $current_item =~ s/^ob(|\.)$/obispo/g;
          $current_item =~ s/^ofc(|\.)$/oficina/g;
          $current_item =~ s/^pág(|\.)$/páginas/g;
          $current_item =~ s/^párr(|\.)$/párrafo/g;
          $current_item =~ s/^pbro(|\.)$/presbítero/g;
          $current_item =~ s/^pdta(|\.)$/presidenta/g;
          $current_item =~ s/^pdte(|\.)$/presidente/g;
          $current_item =~ s/^pg(|\.)$/página/g;
          $current_item =~ s/^plza(|\.)$/plaza/g;
          $current_item =~ s/^pp(|\.)$/páginas/g;
          $current_item =~ s/^presb(|\.)$/presbítero/g;
          $current_item =~ s/^prof(|\.)$/profesor/g;
          $current_item =~ s/^profa(|\.)$/profesora/g;
          $current_item =~ s/^prov(|\.)$/provincia/g;
          $current_item =~ s/^pza(|\.)$/plaza/g;
          $current_item =~ s/^rte(|\.)$/remitente/g;
          $current_item =~ s/^se(|\.)$/sudeste/g;
          $current_item =~ s/^sgto(|\.)$/sargento/g;
          $current_item =~ s/^sig(|\.)$/siguiente/g;
          $current_item =~ s/^so(|\.)$/sudoeste/g;
          $current_item =~ s/^sr(|\.)$/señor/g;
          $current_item =~ s/^sra(|\.)$/señora/g;
          $current_item =~ s/^srta(|\.)$/señorita/g;
          $current_item =~ s/^ss(|\.)$/siguientes/g;
          $current_item =~ s/^sta(|\.)$/santa/g;
          $current_item =~ s/^sto(|\.)$/santo/g;
          $current_item =~ s/^tel(|\.)$/teléfono/g;
          $current_item =~ s/^teléf(|\.)$/teléfono/g;
          $current_item =~ s/^tte(|\.)$/teniente/g;
          $current_item =~ s/^ud(|\.)$/usted/g;
          $current_item =~ s/^uds(|\.)$/ustedes/g;
          $current_item =~ s/^univ(|\.)$/universidad/g;
          $current_item =~ s/^vd(|\.)$/usted/g;
          $current_item =~ s/^vda(|\.)$/viuda/g;
          $current_item =~ s/^vdo(|\.)$/viudo/g;
          $current_item =~ s/^vds(|\.)$/ustedes/g;
          $current_item =~ s/^vid(|\.)$/vide/g;
          $current_item =~ s/^vol(|\.)$/volumen/g;
          $current_item =~ s/^vs(|\.)$/versus/g;

          # VRT: SINGLE LETTERS WITH ONE PERIOD FOLLOWING ("J. L. Borges")
          $current_item =~ s/^a(|\.)$/a /g;
          $current_item =~ s/^b(|\.)$/be /g;
          $current_item =~ s/^c(|\.)$/se /g;
          $current_item =~ s/^d(|\.)$/de /g;
          $current_item =~ s/^e(|\.)$/e /g;
          $current_item =~ s/^f(|\.)$/éfe /g;
          $current_item =~ s/^g(|\.)$/je /g;
          $current_item =~ s/^h(|\.)$/áche /g;
          $current_item =~ s/^i(|\.)$/i /g;
          $current_item =~ s/^j(|\.)$/jóta /g;
          $current_item =~ s/^k(|\.)$/ka /g;
          $current_item =~ s/^l(|\.)$/éle /g;
          $current_item =~ s/^m(|\.)$/éme /g;
          $current_item =~ s/^n(|\.)$/éne /g;
          $current_item =~ s/^ñ(|\.)$/éñe /g;
          $current_item =~ s/^o(|\.)$/o /g;
          $current_item =~ s/^p(|\.)$/pe /g;
          $current_item =~ s/^q(|\.)$/cu /g;
          $current_item =~ s/^r(|\.)$/érre /g;
          $current_item =~ s/^s(|\.)$/ése /g;
          $current_item =~ s/^t(|\.)$/te /g;
          $current_item =~ s/^u(|\.)$/u /g;
          $current_item =~ s/^v(|\.)$/$name_for_v /g;
          $current_item =~ s/^w(|\.)$/doblebé /g;
          $current_item =~ s/^x(|\.)$/équis /g;

          # $current_item =~ s/^y(|\.)$/igriega /g; # For VRT, this turns conjunction "y" into letter.
          $current_item =~ s/^z(|\.)$/séta /g;

          #print STDOUT "VRT_ORTHO-ABBRV-AFT:$current_item\n\n";
     }
     else {
          ############################################################################
          # Process abbreviations in .VRT files                                      #
          ############################################################################

          #print STDOUT "NON-VRT_ABBREV-DEBUG-BEF:$current_item:\n";    # AD HOC DEBUG

          # ABBREVIATIONS WITH SLASHES
          $current_item =~ s/(\W|^)a\/c(\W)/$1a cuenta /g;
          $current_item =~ s/(\W|^)a\/f(\W)/$1a favor /g;
          $current_item =~ s/(\W|^)c\/u(\W)/$1cada uno /g;
          $current_item =~ s/(\W|^)s\/a(\W)/$1sin año /g;
          $current_item =~ s/(\W|^)s\/e(\W)/$1sin editorial /g;
          $current_item =~ s/(\W|^)s\/f(\W)/$1sin fecha /g;
          $current_item =~ s/(\W|^)s\/l(\W)/$1sin lugar /g;
          $current_item =~ s/(\W|^)s\/n(\W)/$1sin número /g;
          $current_item =~ s/(\W|^)v\/s(\W)/$1versus /g;
          $current_item =~ s/(\W|^)y\/o(\W)/$1i o /g;

          # ABBREVIATIONS WITH THREE PERIODS
          $current_item =~ s/(\W|^)a\.( |)de j\.( |)c\./$1antes de jesucristo/g;
          $current_item =~ s/(\W|^)a\.( |)j\.( |)c\./$1antes de jesucristo/g;
          $current_item =~ s/(\W|^)d\.( |)de j\.( |)c\./$1después de jesucristo/g;
          $current_item =~ s/(\W|^)d\.( |)j\.( |)c\./$1después de jesucristo/g;
          $current_item =~ s/(\W|^)o\.( |)e\.( |)a\./$1oéa/g;
          $current_item =~ s/(\W|^)o\.( |)n\.( |)u\./$1ónu/g;
          $current_item =~ s/(\W|^)p\.( |)v\.( |)p\./$1precio de venta al público/g;
          $current_item =~ s/(\W|^)r\.( |)p\.( |)m\./$1revoluciones por minuto/g;

          # ABBREVIATIONS WITH TWO PERIODS
          $current_item =~ s/(\W|^)a\.( |)c\./$1antes de cristo/g;
          $current_item =~ s/(\W|^)a\.( |)d\./$1ano dómini/g;
          $current_item =~ s/(\W|^)a\.( |)de c\./$1antes de cristo/g;
          $current_item =~ s/(\W|^)a\.( |)m\./$1ante merídiem/g;
          $current_item =~ s/(\W|^)a\.( |)r\./$1alteza real/g;
          $current_item =~ s/(\W|^)a\.( |)t\./$1antiguo testamento/g;
          $current_item =~ s/(\W|^)bs\.( |)as\./$1buenos aires/g;
          $current_item =~ s/(\W|^)c\.( |)a\./$1compañía anónima/g;
          $current_item =~ s/(\W|^)cap\.( |)fed\./$1capital federal/g;
          $current_item =~ s/(\W|^)c\.( |)f\./$1capital federal/g;
          $current_item =~ s/(\W|^)c\.( |)i\./$1cédula de identidad/g;
          $current_item =~ s/(\W|^)c\.( |)p\./$1código postal/g;
          $current_item =~ s/(\W|^)d\.( |)c\./$1después de cristo/g;
          $current_item =~ s/(\W|^)d\.( |)de c\./$1después de cristo/g;
          $current_item =~ s/(\W|^)dd\.( |)hh\./$1derechos humanos/g;
          $current_item =~ s/(\W|^)d\.( |)f\./$1distrito federal/g;
          $current_item =~ s/(\W|^)e\.( |)c\./$1era común/g;
          $current_item =~ s/(\W|^)ee\.( |)uu\./$1estados unidos/g;
          $current_item =~ s/(\W|^)e\.( |)u\./$1estados unidos/g;
          $current_item =~ s/(\W|^)f\.( |)c\./$1ferrocarril/g;
          $current_item =~ s/(\W|^)ff\.( |)aa\./$1fuerzas armadas/g;
          $current_item =~ s/(\W|^)ff\.( |)cc\./$1ferrocarriles/g;
          $current_item =~ s/(\W|^)ff\.( |)ee\./$1ferrocarriles del estado/g;
          $current_item =~ s/(\W|^)i\.( |)e\./$1id est/g;
          $current_item =~ s/(\W|^)jj\.( |)cc\./$1juventudes comunistas/g;
          $current_item =~ s/(\W|^)jj\.( |)oo\./$1juegos olímpicos/g;
          $current_item =~ s/(\W|^)k\.( |)o\./$1nocaut/g;
          $current_item =~ s/(\W|^)l\.( |)c\./$1loco citato/g;
          $current_item =~ s/(\W|^)loc\.( |)cit\./$1loco citato/g;
          $current_item =~ s/(\W|^)m\.( |)n\./$1moneda nacional/g;
          $current_item =~ s/(\W|^)n\.( |)b\./$1nota bene/g;
          $current_item =~ s/(\W|^)n\.( |)del t\./$1nota del traductor/g;
          $current_item =~ s/(\W|^)ob\.( |)cit\./$1obra citada/g;
          $current_item =~ s/(\W|^)oo\.( |)pp\./$1obras públicas/g;
          $current_item =~ s/(\W|^)óp\.( |)cit\./$1ópere citato/g;
          $current_item =~ s/(\W|^)p\.( |)d\./$1posdata/g;
          $current_item =~ s/(\W|^)p\.( |)ej\./$1por ejemplo/g;
          $current_item =~ s/(\W|^)p\.( |)ejem\./$1por ejemplo/g;
          $current_item =~ s/(\W|^)p\.( |)m\./$1post merídiem/g;
          $current_item =~ s/(\W|^)p\.( |)s\./$1post scríptum/g;
          $current_item =~ s/(\W|^)rr\.( |)hh\./$1recursos humanos/g;
          $current_item =~ s/(\W|^)s\.( |)a\./$1sin año/g;
          $current_item =~ s/(\W|^)s\.( |)a\./$1sociedad anónima/g;
          $current_item =~ s/(\W|^)s\.( |)d\./$1sine data/g;
          $current_item =~ s/(\W|^)s\.( |)f\./$1sin fecha/g;
          $current_item =~ s/(\W|^)s\.( |)l\./$1sin lugar/g;
          $current_item =~ s/(\W|^)s\.( |)n\./$1sin número/g;
          $current_item =~ s/(\W|^)u\.( |)e\./$1unión europea/g;
          $current_item =~ s/(\W|^)v\.( |)g\./$1verbi gratia/g;
          $current_item =~ s/(\W|^)v\.( |)gr\./$1verbi gratia/g;
          $current_item =~ s/(\W|^)v\.( |)s\./$1vuestra señoría/g;
          $current_item =~ s/(\W|^)w\.( |)c\./$1doblevesé/g;

          # ABBREVIATIONS WITH NO PUNCTUATION, BUT ODD CHARACTERS
          $current_item =~ s/(\W|^)n°/$1número /g;
          $current_item =~ s/(\W|^)nº/$1número /g;
          $current_item =~ s/(\W|^)v°( |)b°/$1visto bueno/g;
          $current_item =~ s/(\W|^)vº( |)bº/$1visto bueno/g;

          # MISC ABBREVIATIONS

          # ABBREVIATIONS WITH ONE PERIOD, AT END.
          $current_item =~ s/(\W|^)afma\./$1afectísima/g;
          $current_item =~ s/(\W|^)afmo\./$1afectísimo/g;
          $current_item =~ s/(\W|^)alfz\./$1alférez/g;
          $current_item =~ s/(\W|^)almte\./$1almirante/g;
          $current_item =~ s/(\W|^)apdo\./$1apartado/g;
          $current_item =~ s/(\W|^)art\./$1artículo/g;
          $current_item =~ s/(\W|^)arz\./$1arzobispo/g;
          $current_item =~ s/(\W|^)atta\./$1atenta/g;
          $current_item =~ s/(\W|^)atte\./$1atentamente/g;
          $current_item =~ s/(\W|^)atto\./$1atento/g;
          $current_item =~ s/(\W|^)av\./$1avenida/g;
          $current_item =~ s/(\W|^)avda\./$1avenida/g;
          $current_item =~ s/(\W|^)bco\./$1banco/g;
          $current_item =~ s/(\W|^)bibl\./$1biblioteca/g;
          $current_item =~ s/(\W|^)cap\./$1capítulo/g;
          $current_item =~ s/(\W|^)cént\./$1céntimo/g;
          $current_item =~ s/(\W|^)cf\./$1confere/g;
          $current_item =~ s/(\W|^)cfr\./$1confere/g;
          $current_item =~ s/(\W|^)cía\./$1 compañía/g;
          $current_item =~ s/(\W|^)cmdt\./$1comandante/g;
          $current_item =~ s/(\W|^)cmte\./$1comandante/g;
          $current_item =~ s/(\W|^)cnel\./$1coronel/g;
          $current_item =~ s/(\W|^)cód\./$1código/g;
          $current_item =~ s/(\W|^)comod\./$1comodoro/g;
          $current_item =~ s/(\W|^)comte\./$1comandante/g;
          $current_item =~ s/(\W|^)conf\./$1confere/g;
          $current_item =~ s/(\W|^)cónf\./$1confere/g;
          $current_item =~ s/(\W|^)confr\./$1confere/g;
          $current_item =~ s/(\W|^)cónfr\./$1confere/g;
          $current_item =~ s/(\W|^)contralmte\./$1contralmirante/g;
          $current_item =~ s/(\W|^)coord\./$1coordinador/g;
          $current_item =~ s/(\W|^)cp\./$1compárese/g;
          $current_item =~ s/(\W|^)cta\./$1cuenta/g;
          $current_item =~ s/(\W|^)cte\./$1corriente/g;
          $current_item =~ s/(\W|^)ctv\./$1centavo/g;
          $current_item =~ s/(\W|^)ctvo\./$1centavo/g;
          $current_item =~ s/(\W|^)depto\./$1departamento/g;
          $current_item =~ s/(\W|^)der\./$1derecho/g;
          $current_item =~ s/(\W|^)diag\./$1diagonal/g;
          $current_item =~ s/(\W|^)dicc\./$1diccionario/g;
          $current_item =~ s/(\W|^)dir\./$1director/g;
          $current_item =~ s/(\W|^)dn\./$1don/g;
          $current_item =~ s/(\W|^)dña\./$1doña/g;
          $current_item =~ s/(\W|^)dpto\./$1departamento/g;
          $current_item =~ s/(\W|^)dr\./$1doctor/g;
          $current_item =~ s/(\W|^)dra\./$1doctora/g;
          $current_item =~ s/(\W|^)edo\./$1estado/g;
          $current_item =~ s/(\W|^)ej\./$1ejemplo/g;
          $current_item =~ s/(\W|^)et ál\./$1et álii/g;
          $current_item =~ s/(\W|^)etc\./$1etcétera/g;
          $current_item =~ s/(\W|^)etc\.\./$1etcétera\./g;           # Catch "etc..", i.e. "etc." at end of sentence.
          $current_item =~ s/(\W|^)excmo\./$1excelentísimo/g;
          $current_item =~ s/(\W|^)fdo\./$1firmado/g;
          $current_item =~ s/(\W|^)fig\./$1figura/g;
          $current_item =~ s/(\W|^)gen\./$1general/g;
          $current_item =~ s/(\W|^)gral\./$1general/g;
          $current_item =~ s/(\W|^)ib\./$1ibídem/g;
          $current_item =~ s/(\W|^)ibíd\./$1ibídem/g;
          $current_item =~ s/(\W|^)íd\./$1ídem/g;
          $current_item =~ s/(\W|^)ilmo\./$1ilustrísimo/g;
          $current_item =~ s/(\W|^)incl\./$1inclusive/g;
          $current_item =~ s/(\W|^)izq\./$1izquierda/g;
          $current_item =~ s/(\W|^)lcda\./$1licenciada/g;
          $current_item =~ s/(\W|^)lcdo\./$1licenciado/g;
          $current_item =~ s/(\W|^)lic\./$1licenciado/g;
          $current_item =~ s/(\W|^)ltda\./$1limitáda/g;
          $current_item =~ s/(\W|^)ltdo\./$1limitádo/g;
          $current_item =~ s/(\W|^)máx\./$1máximo/g;
          $current_item =~ s/(\W|^)mín\./$1mínimo/g;
          $current_item =~ s/(\W|^)mons\./$1monseñór/g;
          $current_item =~ s/(\W|^)ms\./$1manuscríto/g;
          $current_item =~ s/(\W|^)ne\./$1noréste/g;
          $current_item =~ s/(\W|^)no\.( |)(\d)/$1número$2$3/g;      # Fixed in 325: Only acts on "no." followed by number
          $current_item =~ s/(\W|^)nro\./$1número/g;
          $current_item =~ s/(\W|^)ntra\./$1nuéstra/g;
          $current_item =~ s/(\W|^)ntro\./$1nuéstro/g;
          $current_item =~ s/(\W|^)núm\./$1número/g;
          $current_item =~ s/(\W|^)ob\./$1obíspo/g;
          $current_item =~ s/(\W|^)ofc\./$1oficína/g;
          $current_item =~ s/(\W|^)pág\./$1páginas/g;
          $current_item =~ s/(\W|^)párr\./$1párrafo/g;
          $current_item =~ s/(\W|^)pbro\./$1presbítero/g;
          $current_item =~ s/(\W|^)pdta\./$1presidénta/g;
          $current_item =~ s/(\W|^)pdte\./$1presidénte/g;
          $current_item =~ s/(\W|^)pg\./$1página/g;
          $current_item =~ s/(\W|^)plza\./$1pláza/g;
          $current_item =~ s/(\W|^)pp\./$1páginas/g;
          $current_item =~ s/(\W|^)presb\./$1presbítero/g;
          $current_item =~ s/(\W|^)prof\./$1profesór/g;
          $current_item =~ s/(\W|^)profa\./$1profesóra/g;
          $current_item =~ s/(\W|^)prov\./$1província/g;
          $current_item =~ s/(\W|^)pza\./$1 pláza/g;
          $current_item =~ s/(\W|^)rte\./$1remiténte/g;
          $current_item =~ s/(\W|^)se\./$1sudéste/g;
          $current_item =~ s/(\W|^)sgto\./$1sargénto/g;
          $current_item =~ s/(\W|^)sig\./$1siguiénte/g;
          $current_item =~ s/(\W|^)so\./$1sudoéste/g;
          $current_item =~ s/(\W|^)sr\./$1señór/g;
          $current_item =~ s/(\W|^)sra\./$1señóra/g;
          $current_item =~ s/(\W|^)srta\./$1señoríta/g;
          $current_item =~ s/(\W|^)ss\./$1siguiéntes/g;
          $current_item =~ s/(\W|^)sta\./$1sánta/g;
          $current_item =~ s/(\W|^)sto\./$1sánto/g;
          $current_item =~ s/(\W|^)tel\./$1teléfono/g;
          $current_item =~ s/(\W|^)teléf\./$1teléfono/g;
          $current_item =~ s/(\W|^)tte\./$1teniénte/g;
          $current_item =~ s/(\W|^)ud\./$1ustéd/g;
          $current_item =~ s/(\W|^)uds\./$1ustédes/g;
          $current_item =~ s/(\W|^)univ\./$1universidád/g;
          $current_item =~ s/(\W|^)vd\./$1ustéd/g;
          $current_item =~ s/(\W|^)vda\./$1viúda/g;
          $current_item =~ s/(\W|^)vdo\./$1viúdo/g;
          $current_item =~ s/(\W|^)vds\./$1ustédes/g;
          $current_item =~ s/(\W|^)vid\./$1víde/g;
          $current_item =~ s/(\W|^)vol\./$1volúmen/g;
          $current_item =~ s/(\W|^)vs\./$1vérsus/g;

          # SINGLE LETTERS WITH ONE PERIOD FOLLOWING ("J. L. Borges")
          $current_item =~ s/(\W|^)a\./$1a /g;
          $current_item =~ s/(\W|^)b\./$1be /g;
          $current_item =~ s/(\W|^)c\./$1se /g;
          $current_item =~ s/(\W|^)d\./$1de /g;
          $current_item =~ s/(\W|^)e\./$1e /g;
          $current_item =~ s/(\W|^)f\./$1éfe /g;
          $current_item =~ s/(\W|^)g\./$1je /g;
          $current_item =~ s/(\W|^)h\./$1áche /g;
          $current_item =~ s/(\W|^)i\./$1i /g;
          $current_item =~ s/(\W|^)j\./$1jóta /g;
          $current_item =~ s/(\W|^)k\./$1ka /g;
          $current_item =~ s/(\W|^)l\./$1éle /g;
          $current_item =~ s/(\W|^)m\./$1éme /g;
          $current_item =~ s/(\W|^)n\./$1éne /g;
          $current_item =~ s/(\W|^)ñ\./$1éñe /g;
          $current_item =~ s/(\W|^)o\./$1o /g;
          $current_item =~ s/(\W|^)p\./$1pe /g;
          $current_item =~ s/(\W|^)q\./$1cu /g;
          $current_item =~ s/(\W|^)r\./$1érre /g;
          $current_item =~ s/(\W|^)s\./$1ése /g;
          $current_item =~ s/(\W|^)t\./$1te /g;
          $current_item =~ s/(\W|^)u\./$1u /g;
          $current_item =~ s/(\W|^)v\./$1$name_for_v /g;
          $current_item =~ s/(\W|^)w\./$1doblebé /g;
          $current_item =~ s/(\W|^)x\./$1équis /g;
          $current_item =~ s/(\W|^)y\./$1igriéga /g;
          $current_item =~ s/(\W|^)z\./$1séta /g;

          #print STDOUT "NON-VRT_ABBREV-DEBUG-BEF:$current_item:\n\n";    # AD HOC DEBUG
     }

     return ($current_item);

}

#################################################################################
#                                                                               #
#   SUBROUTINE: CONVERT NUMERALS TO WORDS & PROCESS PUNCT. INSIDE NUMBERS       #
#                                                                               #
#################################################################################
sub convert_numerals_to_words {

     my $current_item = $_[0];

     # Invoke the Lingua::ES::Numeros module and set options                    #
     $numeral_converter_obj = Lingua::ES::Numeros->new(
          DECIMAL     => ',',
          SEPARADORES => '.',
          UNMIL       => '0',
     );


     #print STDOUT "ALL-NUM_CONV-BEGINNING-OF-SUB:$current_item\n";    # AD-HOC DEBUG

     ############################################################################
     #                                                                          #
     #          PROCESS DATE RANGES AS SUCH, RATHER THAN AS EQUATIONS           #
     #                                                                          #
     ############################################################################

     # BROAD DATE RANGES (1-4 digit numbers)                                    #
     # Treat two consecutive 1-4 digit numbers with a minus sign in between as  #
     # a range of years rather than as an equation (e.g. 24-110 = "24 a 110",   #
     # not "24-110"                                                             #
     if ( $broad_year_ranges == 1 ) {    # Process 1-4 digit numbers

          if ( $bc_dates_included == 0 ) {    # DON'T process when 2nd is smaller than 1st
               if ( ( $current_item =~ m/([0-9]{1,4}) menos ([0-9]{1,4})/ ) && ( $2 > $1 ) ) {
                    $current_item =~ s/([0-9]{1,4}) menos ([0-9]{1,4})/$1 a $2/g;
               }
          }
          elsif ( $bc_dates_included == 1 ) {    # DO process when 2nd is smaller than 1st
               if ( $current_item =~ m/([0-9]{1,4}) menos ([0-9]{1,4})/ ) {
                    $current_item =~ s/([0-9]{1,4}) menos ([0-9]{1,4})/$1 a $2/g;
               }
          }
     }

     # NARROW DATE RANGES (only 4-digit numbers)                                #
     # Treat two consecutive 4-digit numbers with a minus sign in betwen as a   #
     # range of years rather than as an equation (e.g. 1900-1990 = "1900 a      #
     # 1990", not "1900-1990"                                                   #
     elsif ( $narrow_year_ranges == 1 ) {        # Process two 4-digit nums

          if ( $bc_dates_included == 0 ) {       # DON'T process when 2nd is smaller than 1st
               if ( ( $current_item =~ m/([0-9]{4}) menos ([0-9]{4})/ ) && ( $2 > $1 ) ) {
                    $current_item =~ s/([0-9]{4}) menos ([0-9]{4})/$1 a $2/g;
               }
          }
          elsif ( $bc_dates_included == 1 ) {    # DO process when 2nd is smaller than 1st
               if ( $current_item =~ m/([0-9]{4}) menos ([0-9]{4})/ ) {
                    $current_item =~ s/([0-9]{4}) menos ([0-9]{4})/$1 a $2/g;
               }
          }
     }

     ############################################################################
     #                                                                          #
     #                    CONVERT ANY FORMAT **EXCEPT** VRT                     #
     #                                                                          #
     ############################################################################
     if ( $vrt_format == 0 ) {

          #print STDOUT "NON-VRT-NUM_CONV-BEF-CnvNm:$current_item\n";    # AD-HOC DEBUG

          # DISABLED, ALSO IN 416. Works fine in most cases, but turns comma +  #
          # number (e.g. "allá, 400 personas...") into "menos" + number ("allá, #
          # menos 400 personas". This is b/c a prior processing stage turns the #
          # comma, dash, etc. into a common pause symbol.                       #
          #
          ## Convert multiple spaces to just one space.                          #
          ## NOTE: May not be necessary.                                         #
          ## WARNING: New in 416                                                 #
          ##$current_item =~ s/ +/ /g;
          #
          ## If a number starts with a minus sign (negative number), change that #
          ## sign to "menos".                                                    #
          ## WARNING: New in 416
          #if ( $current_item =~ m/, [0-9]/ ) {
          #     $current_item =~ s/, ([0-9])/menos $1/g;
          #}

          # Process 4-digit integers without period separator, which are not    #
          # caught by the regex pattern used here.                              #
          $current_item =~ s/( |\(|\{|\[|\/|^)(\d{4})(\D|$)/eval q{
               " " .                                    # Prepend a space
               $numeral_converter_obj->cardinal($2)     # Convert numeral to words
               . " ";                                   # Postpend a space
          } /ge;

          #print STDOUT "NON-VRT-NUM_CONV-AFT-4DIGT:$current_item\n";    # AD-HOC DEBUG

          # Process all other integer numbers                                            #
          # Don't use "\b" in the first search expr - it catches too much ("2" in "3,2") #
          $current_item =~ s/( |\(|\{|\[|\/|^)(\d{1,3})((\.\d{3})*)(\D|$)/eval q{

               # print STDOUT "1=$1\t2=$2\t3=$3\t4=$4\t5=$5\t6=$6\ttemp_num=$temp_num\n"; # AD-HOC DEBUG

               $temp_num = join ('', $2, $3);               # Concatenate the parts of the extracted integer

               if ( $5 eq "," ) {                                # If $5 is a comma, do this...
                    " " .                                        # Prepend a space
                    $numeral_converter_obj->cardinal($temp_num)  # Convert numeral to words
                    . ">"                                        # Add special > char to indicate $5 came after number
                    . $5                                         # Add the non-number trailing char
                    #. " ";                                      # Postpend a space
               }
               else {                                            # If $5 isn't a comma, do this...
                    " " .                                        # Prepend a space
                    $numeral_converter_obj->cardinal($temp_num)  # Convert numeral to words
                    . $5                                         # Add the non-number trailing char
                    #. " ";                                      # Postpend a space
               }
          } /ge;

          #print STDOUT "NON-VRT-NUM_CONV-AFT-AOINT:$current_item\n";    # AD-HOC DEBUG

          # Process fractions (numbers to right of decimal point)               #
          $current_item =~ s/(,)(\d+)/eval q{

               # print STDOUT "1=$1\t2=$2\n"; # AD-HOC DEBUG

               " kóma " .                                        # Convert ">," to " kóma "
               &convert_fractional_nums_to_words($2)             # Send fractional num to conversion subroutine
          }/ge;

          #print STDOUT "NON-VRT-NUM_CONV-AFT-FRACT:$current_item\n";    # AD-HOC DEBUG

          # Process numbers with leading 0s (01, 001, 0001, 00001) and after commas #
          $current_item =~ s/( |\(|\{|\[|\/|^)([\d]+)(\D|$)/eval q{
               $1 .                                     # Prepend a space if there already was one
               &convert_fractional_nums_to_words($2)    # Send number to conversion subroutine
               . $3;                                    # Postpend a space
          } /ge;

          #print STDOUT "NON-VRT-NUM_CONV-AFT-LDNG0:$current_item\n";    # AD-HOC DEBUG

          ############################################################################
          # CONVERT PERIODS AND COMMAS IN NUMERALS BUT NOT ELSEWHERE                 #
          ############################################################################
          $current_item =~ s/\.([0-9])/punto $1/g;
          $current_item =~ s/,([0-9])/coma $1/g;

          ############################################################################
          # ELIMINATE COLONS BETWEEN NUMERALS BUT NOT ELSEWHERE (E.G. "15:30")       #
          ############################################################################
          $current_item =~ s/([0-9]):([0-9])/$1  $2/g;

          #######################################################################
          # Convert certain number-related symbols                              #
          #######################################################################
          $current_item =~ s/%/ porcientos /g;
          $current_item =~ s/\+/ más /g;

          ############################################################################
          # CHANGE SPECIFIC COMBINATIONS OF LETTERS AND NUMBERS TO WORD FORM         #
          # (e.g. "abc1", "mc2")                                                     #
          ############################################################################
          # WARNING: Moved this in 398 - Confirm that it works
          $current_item =~ s/(\W|^)abc1/$1abeseúno /g;
          $current_item =~ s/(\W|^)mc2/$1emesedós /g;

          #print STDOUT "\n>LET+NUM AFT: $current_item";    # DEBUG
     }

     ############################################################################
     #                                                                          #
     #                             CONVERT .VRT FORMAT                          #
     #                                                                          #
     ############################################################################

     # If generating .VRT files, put ¬ after numerals converted into            #
     # words instead of a space, so "2000" doesn't end up occupying 4 lines     #
     # (dos\nsero\nsero\nsero)                                                  #

     if ( $vrt_format == 1 ) {

          #print STDOUT "\nVRT-NUM_CONV-----START:$current_item:\n";    # AD-HOC DEBUG

          # Convert multiple spaces to just one space.                          #
          $current_item =~ s/ +/ /g;

          # NEW IN 417 #

          # If a number starts with a minus sign (negative number), change that #
          # sign to "menos".                                                    #
          # WARNING: New in 416
          if ( $current_item =~ m/^, [0-9]/ ) {
               $current_item =~ s/^,/menos /g;
          }

          # Convert "," at beginning of line to the word "coma" followed by space. #
          # This catches (rare) things like ",333".                                #
          $current_item =~ s/^\,/coma /g;

          # Process 4-digit integers without period separator, which are not    #
          # caught by the regex pattern used here.                              #
          $current_item =~ s/( |\(|\{|\[|\/|^)(\d{4})(\D|$)/eval q{
               " " .                                    # Prepend a space
               $numeral_converter_obj->cardinal($2)     # Convert numeral to words
               . " ";                                   # Postpend a space
          } /ge;

          #print STDOUT "VRT-NUM_CONV-AFT-4DIGT:$current_item:\n";    # AD-HOC DEBUG

          # Process all other integer numbers                                            #
          # Don't use "\b" in the first search expr - it catches too much ("2" in "3,2") #
          $current_item =~ s/( |\(|\{|\[|\/|^)(\d{1,3})((\.\d{3})*)(\D|$)/eval q{

               #print STDOUT "1=$1\t2=$2\t3=$3\t4=$4\t5=$5\t6=$6\ttemp_num=$temp_num\n"; # AD-HOC DEBUG

               $temp_num = join ('', $2, $3);               # Concatenate the parts of the extracted integer

               if ( $5 eq "," ) {                                # If $5 is a comma, do this...
                    " " .                                        # Prepend a space
                    $numeral_converter_obj->cardinal($temp_num)  # Convert numeral to words
                    . ">"                                        # Add special > char to indicate $5 came after number
                    . $5                                         # Add the non-number trailing char
                    #. " ";                                      # Postpend a space
               }
               else {                                            # If $5 isn't a comma, do this...
                    " " .                                        # Prepend a space
                    $numeral_converter_obj->cardinal($temp_num)  # Convert numeral to words
                    . $5                                         # Add the non-number trailing char
                    #. " ";                                      # Postpend a space
               }
          } /ge;

          #print STDOUT "VRT-NUM_CONV-AFT-AOINT:$current_item:\n";    # AD-HOC DEBUG

          # Process fractions (numbers to right of decimal point)               #
          # 392: TESTING: Changed "(\d+)?" to "(\d)", as I think it was changing all commas.
          $current_item =~ s/(>?,)(\d+)/eval q{

               #print STDOUT "1=$1\t2=$2\n"; # AD-HOC DEBUG

               " koma " .                                        # Convert ">," to " koma "
               &convert_fractional_nums_to_words($2)             # Send fractional num to conversion subroutine
          }/ge;

          #print STDOUT "VRT-NUM_CONV-AFT-FRACT:$current_item:\n";    # AD-HOC DEBUG

          # Process numbers with leading 0s (01, 001, 0001, 00001) and after commas #
          $current_item =~ s/( |\(|\{|\[|\/|^)([\d]+)(\D|$)/eval q{
               $1 .                                     # Prepend a space if there already was one
               &convert_fractional_nums_to_words($2)    # Send number to conversion subroutine
               . $3;                                    # Postpend a space
          } /ge;

          #print STDOUT "VRT-NUM_CONV-AFT-LDNG0:$current_item:\n";    # AD-HOC DEBUG

          ############################################################################
          # CONVERT PERIODS AND COMMAS BEFORE NUMERALS BUT NOT ELSEWHERE             #
          # NEW IN 401: Also catch orphaned ">," groups.                             #
          ############################################################################
          $current_item =~ s/\.([0-9])/punto $1/g;
          $current_item =~ s/>, / guión /g;         # WARNING: CHANGED IN 401

          #print STDOUT "VRT-NUM_CONV-AFT-CNV.,:$current_item:\n";    # AD-HOC DEBUG

          #############################################################################
          ## ELIMINATE COLONS BETWEEN NUMERALS BUT NOT ELSEWHERE (E.G. "15:30")       #
          #############################################################################
          #if ( $vrt_format == 0 ) {
          #     $current_item =~ s/([0-9]):([0-9])/$1 $2/g;
          #}

          #######################################################################
          # Convert certain number-related symbols                              #
          #######################################################################
          # TODO Move up to non-VRT section
          $current_item =~ s/%/ porcientos /g;
          $current_item =~ s/\+/ más /g;

          #print STDOUT "NON-VRT-NUM_CONV-AFT-NMSYM:$current_item\n";    # AD-HOC DEBUG

          #print "\n>LET+NUM AFT: $current_item";    # DEBUG

          # Convert conjunction "y" to "i" (it's inserted by the number conversion routine, #
          # but is analyzed as the phoneme "ye" by Perkins without this fix)                #
          $current_item =~ s/ y / i /g;
     }
     return ($current_item);

}    # END SUBROUTINE: CONVERT NUMERALS TO WORDS

#################################################################################
#                                                                               #
#   SUBROUTINE: CONVERT FRACTIONAL NUMBERS TO WORDS                             #
#                                                                               #
#################################################################################
sub convert_fractional_nums_to_words {

     my $current_item = $_[0];

     my @current_fractional_digit = split //, $current_item;

     foreach my $digit (@current_fractional_digit) {
          $digit =~ s/0/cero/g;
          $digit =~ s/1/uno/g;
          $digit =~ s/2/dos/g;
          $digit =~ s/3/tres/g;
          $digit =~ s/4/cuatro/g;
          $digit =~ s/5/cinco/g;
          $digit =~ s/6/seis/g;
          $digit =~ s/7/siete/g;
          $digit =~ s/8/ocho/g;
          $digit =~ s/9/nueve/g;
     }

     $current_item = join( " ", @current_fractional_digit );

     #$temp = Encode::encode_utf8($current_item);    # AD-HOC DEBUG
     #print STDOUT "FRACT-NUM-AFT-PROCESS :$temp\n";    # AD-HOC DEBUG

     #print STDOUT "CURR_FRAC_DIG=$current_item\n";     # AD-HOC DEBUGGING

     return ($current_item);

}    # END SUBROUTINE: CONVERT FRACTIONAL NUMBERS TO WORDS

##############################################################################
#                                                                            #
#   SUBROUTINE: CHANGE CERTAIN SYMBOLS TO WORD FORM                          #
#                                                                            #
##############################################################################
sub change_some_symbols_to_words {

     my $current_item = $_[0];

     if ( $vrt_format == 1 ) {
          $current_item =~ s/@/¬arroba¬/g;
          $current_item =~ s/\$/$moneda¬/g;         # Replace "$" character with word stored in $moneda
          $current_item =~ s/&/¬y¬/g;
          $current_item =~ s/_/¬guión¬bajo¬/g;
          $current_item =~ s/\//ø$slash\ø/g;
     }
     else {
          $current_item =~ s/@/ arroba /g;
          $current_item =~ s/\$/$moneda /g;          # Replace "$" character with word stored in $moneda
          $current_item =~ s/&/ y /g;
          $current_item =~ s/_/ guión bajo /g;
          $current_item =~ s/\// $slash /g;
     }

     # WARNING Testing TESTING
     # Change remaining dashes to spaces
     if ( $vrt_format == 1 ) {
          $current_item =~ s/\-/¬/g;
     }
     else {
          $current_item =~ s/\-/ /g;
     }

     return ($current_item);

}

##############################################################################
#                                                                            #
#   SUBROUTINE: SEARCH AND REPLACE MULTI-WORD PHRASES                        #
#                                                                            #
##############################################################################
sub replace_multiword_phrases {

     my $current_item = $_[0];

     # Adverbs ending in "-mente"

     # EPIPHANY : VITAL ADDITION: REGEX WAS SELECTING FROM BEG OF LINE TO LAST -MENTE! #
     # NOTE Changed in 383 to process .vrt format                                      #
     if ( $vrt_format == 1 ) {

          # WARNING: This does NOT produce perfect output: only "mente" is assigned          #
          #          a stress accent. But the alternative is to have the first element       #
          #          of the word (e.g. "brusca") split from "mente" and put on seperate lines#
          $current_item =~ s/(\w+)mente/$1ménte/g;    # Space and underscore added to allow temporary processing and later rejoining
     }
     else {
          $current_item =~ s/(\w+)mente/$1 _ménte/g;    # Space and underscore added to allow temporary processing and later rejoining
     }

                    # FOR DEBUGGING
                    #print STDOUT "\n$current_item"; # FOR DEBUGGING

     # Other phrases and things which need spaces on either end or in the middle.
     $current_item =~ s/afdd/asociación de familiares de detenidos desaparecidos/g;
     $current_item =~ s/beethoven/betoven/g;
     $current_item =~ s/bio bio/bíobío/g;
     $current_item =~ s/bio\-bio/bíobío/g;
     $current_item =~ s/biobio/bíobío/g;
     $current_item =~ s/bío bio/bíobío/g;
     $current_item =~ s/bío\-bio/bíobío/g;
     $current_item =~ s/bíobio/bíobío/g;
     $current_item =~ s/bio bío/bíobío/g;
     $current_item =~ s/bio\-bío/bíobío/g;
     $current_item =~ s/biobío/bíobío/g;
     $current_item =~ s/bío \- bío/bíobío/g;
     $current_item =~ s/bío bío/bíobío/g;
     $current_item =~ s/bío\-bío/bíobío/g;
     $current_item =~ s/bíobío/bíobío/g;
     $current_item =~ s/blue jeans/bluyíns/g;
     $current_item =~ s/byte(s|)($| )/báit$1$2/g;
     $current_item =~ s/canada dry/cánada drai/g;
     $current_item =~ s/christian/cristian/g;
     $current_item =~ s/christopher/crístofer/g;
     $current_item =~ s/data show/dátacho/g;
     $current_item =~ s/eeuu/estados unidos/g;
     $current_item =~ s/( |^)eua/$1estados unidos/g;
     $current_item =~ s/gamecube/gueim kiub/g;
     $current_item =~ s/ginger ale/yínyereil/g;
     $current_item =~ s/higgins/jíguins/g;
     $current_item =~ s/hip hoper(o|a)(s|)/jipjopér$1$2/g;
     $current_item =~ s/hip(\-| |)hop/jipjóp/g;
     $current_item =~ s/hot dog/jotdóg/g;
     $current_item =~ s/hot pant(s|)/jótpant/g;
     $current_item =~ s/jet( |)set/yetsét/g;
     $current_item =~ s/jhonny/yóni/g;
     $current_item =~ s/nintendo, seis cuatro/nintendo sesentaicuatro/g;
     $current_item =~ s/o'higgins/ojíguins/g;
     $current_item =~ s/pie de limón/pai de limón/g;
     $current_item =~ s/ping pong/pinpón/g;
     $current_item =~ s/play station, dos/plei esteichon dos/g;
     $current_item =~ s/seven up/sevenap/g;
     $current_item =~ s/skateboard/skeit bord/g;
     $current_item =~ s/webmaster/webmáster/g;
     $current_item =~ s/website/wébsait/g;
     $current_item =~ s/jean pier(r|)e/yonpier/g;
     $current_item =~ s/jean paul/yonpól/g;
     $current_item =~ s/plan b/planbé/g;
     $current_item =~ s/data show/datachó/g;

     # NEW IN 102: Process multi-word backchannel vocalizations
     #   +++++     These must be in ALL CAPS.
     $current_item =~ s/mm hm/MMHM/g;
     $current_item =~ s/nn nn/NNNN/g;
     $current_item =~ s/uh huh/UHHUH/g;
     $current_item =~ s/uh oh/UHOH/g;
     $current_item =~ s/uh uh/UHUH/g;

     # NEW IN 103
     $current_item =~ s/wi fi/wáifai/g;

     # REMOVE MULTIPLE SPACES
     $current_item =~ s/ ( )+/ /g;

     return ($current_item);

}

############################################################################
#                                                                          #
# SUBROUTINE: Fix specific rarities                                        #
#                                                                          #
############################################################################
sub fix_specific_rarities {

     my $current_item = $_[0];

     # WARNING This doesn't work in words without orthographical tilde
     $current_item =~ s/(\w+)mente/_ménte/g;    # Adds a temporary _ to permit double accentuation in one word
                                                 # EPIPHANY: UNGREEDY MATCHING
     $current_item =~ s/º//g;
     $current_item =~ s/°//g;
     $current_item =~ s/ª//g;
     $current_item =~ s/¿//g;
     $current_item =~ s/¡//g;

     # NOTE New in 380...
     $current_item =~ s/\^//g;
     $current_item =~ s/~//g;
     $current_item =~ s/¬//g;
     $current_item =~ s/|//g;
     $current_item =~ s/¯//g;
     $current_item =~ s/§//g;
     $current_item =~ s/©//g;
     $current_item =~ s/®//g;
     $current_item =~ s/¥//g;
     $current_item =~ s/#//g;

     return ($current_item);

}


############################################################################
# NEW IN 104!                                                              #
# SUBROUTINE: Double vowels to singles                                     #
#                                                                          #
############################################################################
sub double_vowels_to_single_vowels {

	my $current_item = $_[0];

	# DEBUG:
	#print STDOUT "BEFORE: $current_item\n";

     $current_item =~ s/[a]+/a/g;
     $current_item =~ s/[e]+/e/g;
     $current_item =~ s/[i]+/i/g;
     $current_item =~ s/[o]+/o/g;
     $current_item =~ s/[u]+/u/g;

	# DEBUG:
     #print STDOUT "AFTER: $current_item\n\n";

     return ($current_item);
}

#################################################################################
#                SUBROUTINE: PRE-PROCESSING: Fix odd characters                 #
#################################################################################
sub fix_odd_characters {

     my $current_item = $_[0];

     # Umlauts > bare vowels (except ü, which is the diéresis)                  #
     if ( $fix_umlauts == 1 ) {
          $current_item =~ s/ä/a/g;
          $current_item =~ s/ë/e/g;
          $current_item =~ s/ï/i/g;
          $current_item =~ s/ö/o/g;
     }

     # Grave accents > accute accents (using graves is a pretty common typing mistake)
     if ( $fix_grave_accents == 1 ) {
          $current_item =~ s/à/á/g;
          $current_item =~ s/è/é/g;
          $current_item =~ s/ì/í/g;
          $current_item =~ s/ò/ó/g;
          $current_item =~ s/ò/ú/g;
     }

     # Circumflexes > bare vowels                                                    #
     if ( $fix_circumflexes == 1 ) {
          $current_item =~ s/â/a/g;
          $current_item =~ s/ê/e/g;
          $current_item =~ s/î/i/g;
          $current_item =~ s/ô/o/g;
          $current_item =~ s/û/u/g;
     }

     # Nasal tildes > bare vowels                                                    #
     if ( $fix_nasal_tildes == 1 ) {
          $current_item =~ s/ã/a/g;
          $current_item =~ s/õ/o/g;
     }

     return ($current_item);
}    # END SUBROUTINE

############################################################################
# VRT PRE-PROCESSING                                                       #
# If reading .vrt text files produced by Connexor, replace <tags>, commas, #
# periods, etc. with special characters (which will be converted into the  #
# original Connexor symbols later)                                         #
############################################################################
sub do_vrt_preprocessing {

     my $current_item = $_[0];

     $temp = Encode::encode_utf8($current_item);    # AD-HOC DEBUG
                                                    #print STDOUT "VRT-PREPROCESSING-BEF:$temp:\n";    # AD-HOC DEBUG

     # Strip punctuation from numbers
     $current_item =~ s/([0-9])(-)+/$1/g;

     # Process certain characters and Connexor symbols                     #
     $current_item =~ s/ /¬/g;                     # Connexor treats things like "estados unidos" as a unit, but w/ a space.
     $current_item =~ s/-/ø/g;                     # Dashes. Connexor keeps them in things like "fonético-fonológico".
     $current_item =~ s/<p>/µµ/g;                 # Connexor paragraph symbols.
     $current_item =~ s/<s>/µ/g;                   # Connexor sentence symbols.
     $current_item =~ s/\./øøø/g;
     $current_item =~ s/\+/øøø/g;

     $temp = Encode::encode_utf8($current_item);    # AD-HOC DEBUG
                                                    #print STDOUT "VRT-PREPROCESSING-AFT:$temp:\n";    # AD-HOC DEBUG

     return ($current_item);
}

##############################################################################
#                                                                            #
#   SUBROUTINE: KILL COMMON WORDS (FOR TESTING)                              #
#                                                                            #
##############################################################################
sub kill_common_words {

     my $current_item = $_[0];

     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)el($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)la($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)los($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)las($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)un($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)una($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)uno($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)unos($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)unas($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)y($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)e($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)o($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)u($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)de($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)por($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)para($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)con($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)desde($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hacia($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hasta($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sin($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)es($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)son($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)este($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)esto($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)esta($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)estos($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)estas($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)aquél($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)aquello($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)aquela($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)aquelas($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)en($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)del($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)solo($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sólo($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sola($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)solos($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)solas($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ha($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)han($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)como($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sea($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sean($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sino($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)más($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)menos($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ese($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)eso($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)esa($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)esos($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)que($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)qué($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)porque($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)donde($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)dónde($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cual($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cuál($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cuales($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cuáles($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)como($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cómo($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cuando($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cuándo($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)quien($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)quién($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)quienes($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)quiénes($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cuanto($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cuantos($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cuanta($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cuantas($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cuánto($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cuántos($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cuánta($|\.|,|:|;|"|-|‖|\]|\)|\})//g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cuántas($|\.|,|:|;|"|-|‖|\]|\)|\})//g;

     return ($current_item);

}

#################################################################################
# SUBROUTINE: MODIFY SINGLE WORDS IN ORTHOGRAPHIC FORM                          #
#################################################################################
sub modify_single_ortho_words {
     my $current_item = $_[0];

     #print STDOUT "\nSingle-Ortho-Words-BEF:$current_item:";

     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{| )abc($|\.|,|:|;|"|-|‖|\]|\)|\}| )/$1abecé$2/g
       ;    # Added "| " to beginning and end of expression to catch "abc1" > "abc uno"
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)addend(a|um|ums)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1adénd$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)affaire(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1afér$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)age($|\.|,|:|;|"|-|‖|\]|\)|\})/$1eich$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)alzheimer(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1alsjéimer$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)angie($|\.|,|:|;|"|-|‖|\]|\)|\})/$1anyi$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ángstrom($|\.|,|:|;|"|-|‖|\]|\)|\})/$1angstrom$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)antonella($|\.|,|:|;|"|-|‖|\]|\)|\})/$1antonela$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)aol($|\.|,|:|;|"|-|‖|\]|\)|\})/$1aoele$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)apple(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ápel$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)arlette($|\.|,|:|;|"|-|‖|\]|\)|\})/$1arlet$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)aylton($|\.|,|:|;|"|-|‖|\]|\)|\})/$1eilton$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)aylwin($|\.|,|:|;|"|-|‖|\]|\)|\})/$1eilwin$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)baby(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1beibi$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ballet(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1balét$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)barbie(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1barbi$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)bayron($|\.|,|:|;|"|-|‖|\]|\)|\})/$1bairon$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)bbc($|\.|,|:|;|"|-|‖|\]|\)|\})/$1bebesé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)becker(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1béquer$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)berger(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1bérguer$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)berries($|\.|,|:|;|"|-|‖|\]|\)|\})/$1bérris$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)berry($|\.|,|:|;|"|-|‖|\]|\)|\})/$1bérri$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)bestseller(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1bestséler$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)bieber($|\.|,|:|;|"|-|‖|\]|\)|\})/$1bíber$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)blockbuster(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1blokbáster$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)blogger(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1blóguer$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)blogspot(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1blógspot$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)blue(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1blu$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)boulevard(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1bulevár$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)break(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1brék$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(brian|brallan)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1bráyan$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)bridge($|\.|,|:|;|"|-|‖|\]|\)|\})/$1brích$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)brit(t|)an(n|)(i|y|ie)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1brítani$5/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)bulldog(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1búldog$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)bungalow(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1búngalow$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)byronian(o|a)(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1baironian$2$3$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)byron(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1bairon$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cabaret(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1kabarét$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cancel($|\.|,|:|;|"|-|‖|\]|\)|\})/$1cáncel$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)carn(é|e)(t|)(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1karné$3$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)carrie($|\.|,|:|;|"|-|‖|\]|\)|\})/$1kari$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cd(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1sedé$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)chalet(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1chalét$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)charlo(t|tt|tte|th)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1chárlot$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)chv($|\.|,|:|;|"|-|‖|\]|\)|\})/$1chilevisión$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(c|k)atchup($|\.|,|:|;|"|-|‖|\]|\)|\})/$1$2áchup$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(c|k)atherin(e|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1káterin$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)clinic($|\.|,|:|;|"|-|‖|\]|\)|\})/$1klínik$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)closet(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1klóset$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cnn($|\.|,|:|;|"|-|‖|\]|\)|\})/$1seeneéne$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)complot(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1complót$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)coñac(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1coñác$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)confort(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1confórt$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)conicyt(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1kónisit$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)contrafagot(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1contrafagót$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)copyright(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1cópirait$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cowboy(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1cówboy$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)crush($|\.|,|:|;|"|-|‖|\]|\)|\})/$1crash$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cullen($|\.|,|:|;|"|-|‖|\]|\)|\})/$1calen$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)c(u|ú)chen(e|)(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1c$2jen$3$4$5/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)dastyn($|\.|,|:|;|"|-|‖|\]|\)|\})/$1dástin$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)datashow(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1dátacho$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)davis($|\.|,|:|;|"|-|‖|\]|\)|\})/$1déivis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)dc($|\.|,|:|;|"|-|‖|\]|\)|\})/$1desé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)debut(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1debút$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)dellanira($|\.|,|:|;|"|-|‖|\]|\)|\})/$1deyanira$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)derek($|\.|,|:|;|"|-|‖|\]|\)|\})/$1dérek$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)dieciseis($|\.|,|:|;|"|-|‖|\]|\)|\})/$1dieciséis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)digg($|\.|,|:|;|"|-|‖|\]|\)|\})/$1dig$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)dj(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1diyei$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)dreamcast(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1drímcast$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)dry($|\.|,|:|;|"|-|‖|\]|\)|\})/$1drai$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)dvd(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1devedé$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ebay($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ibei$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(e|é)lite($|\.|,|:|;|"|-|‖|\]|\)|\})/$1elít$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)e-mail($|\.|,|:|;|"|-|‖|\]|\)|\})/$1imeil$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)email($|\.|,|:|;|"|-|‖|\]|\)|\})/$1imeil$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)emily($|\.|,|:|;|"|-|‖|\]|\)|\})/$1émili$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)empires($|\.|,|:|;|"|-|‖|\]|\)|\})/$1émpaiers$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(e|)slip(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1eslíp$3$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(e|)snob(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1esnób$3$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(e|)spot(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1espót$3$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)etc($|\.|,|:|;|"|-|‖|\]|\)|\})/$1etcétera$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)facebook($|\.|,|:|;|"|-|‖|\]|\)|\})/$1feisbuk$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)fagot(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1fagót$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)fahrenheit($|\.|,|:|;|"|-|‖|\]|\)|\})/$1fárenjait$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)falabella($|\.|,|:|;|"|-|‖|\]|\)|\})/$1falabela$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)firefox($|\.|,|:|;|"|-|‖|\]|\)|\})/$1faierfox$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)flickr($|\.|,|:|;|"|-|‖|\]|\)|\})/$1flíquer$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)fmr($|\.|,|:|;|"|-|‖|\]|\)|\})/$1efeemeére$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)fondecyt(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1fóndesit$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)foster($|\.|,|:|;|"|-|‖|\]|\)|\})/$1fóster$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)fpmr($|\.|,|:|;|"|-|‖|\]|\)|\})/$1efepeemeére$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)freezer(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1fríser$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)frizer($|\.|,|:|;|"|-|‖|\]|\)|\})/$1fríser$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)game($|\.|,|:|;|"|-|‖|\]|\)|\})/$1gueim$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)gangster(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1gánster$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)gángster(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1gánster$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)gay(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1guei$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)gb($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yígabaits$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)g(é|e)iser(es|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1gu$2iser$3$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)geisha(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1gueicha$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)geocities($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jeositis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)george(t|tt|tte)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yoryet$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)gerbner($|\.|,|:|;|"|-|‖|\]|\)|\})/$1guérbner$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)gibson($|\.|,|:|;|"|-|‖|\]|\)|\})/$1guibson$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)gigoló(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yigoló$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)gin($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yin$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)gmail($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jemeil$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)goldfarb($|\.|,|:|;|"|-|‖|\]|\)|\})/$1góldfarb$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)google($|\.|,|:|;|"|-|‖|\]|\)|\})/$1gúguel$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)h(a|á)mster(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jámster$3$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)h(a|á)ndicap(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jándicap$3$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hall(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jol$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)happening(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jápening$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hardware(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1járwer$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hasbro($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jasbro$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hawaiana(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jaguayana$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hepburn($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jepburn$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hil(l|)ar(i|y)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jílari$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hipp(y|ie)(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jipi$3$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hobbies($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jobis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hobby($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jobi$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hobbys($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jobis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hockey(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jókei$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hollywood(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jóligwud$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hotmail($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jótmeil$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ic($|\.|,|:|;|"|-|‖|\]|\)|\})/$1isé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)iceberg(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1aisberg$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)imdb($|\.|,|:|;|"|-|‖|\]|\)|\})/$1iemedebé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)input(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ínput$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)isabella($|\.|,|:|;|"|-|‖|\]|\)|\})/$1isabela$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)jacqu(elín|elin|eline)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yákelin$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)jacqui($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yáki$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)jamie($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yeimi$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)jazz($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yas$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)jeans($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yins$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)jeep(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yip$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)jet(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yet$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)j(|h)ander($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yánder$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)jockey(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yóqui$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)journal(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yórnal$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)jumper(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yámper$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)junior(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yúnior$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(j|y)e(f|ff)r(y|i|ie)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yéfri$5/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(j|y)eimy(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yeimi$3$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(j|y)e(s|ss|c)e(n|nn)ia($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yesenia$5/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(j|y)e(s|ss|c)i(c|cc|k)a($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yésika$5/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(j|y)o(s|ss|c)el(i|í|y)n($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yóselin$5/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(j|y)ustin($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yastin$3$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)kb($|\.|,|:|;|"|-|‖|\]|\)|\})/$1kílobaits$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)kiwi(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1quigüi$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)k(u|ú)chen(e|)(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1k$2jen$3$4$5/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)live($|\.|,|:|;|"|-|‖|\]|\)|\})/$1laib$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)livejournal($|\.|,|:|;|"|-|‖|\]|\)|\})/$1laibyórnal$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)locker($|\.|,|:|;|"|-|‖|\]|\)|\})/$1lóquer$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)lycra(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1laicra$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)magic($|\.|,|:|;|"|-|‖|\]|\)|\})/$1máyik$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)mail($|\.|,|:|;|"|-|‖|\]|\)|\})/$1meil$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ma(i|y)(c|k|ch)o(l|ll)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1máicol$5/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)mall(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1mol$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)marshall($|\.|,|:|;|"|-|‖|\]|\)|\})/$1márchal$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)mb($|\.|,|:|;|"|-|‖|\]|\)|\})/$1mégabaits$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{| )mc($|\.|,|:|;|"|-|‖|\]|\)|\}| )/$1emesé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)messenger(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1mésenyer$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)metempsicosis($|\.|,|:|;|"|-|‖|\]|\)|\})/$1metemsicosis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)microsoft(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1maicrosof$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)miley($|\.|,|:|;|"|-|‖|\]|\)|\})/$1maili$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)moulinex($|\.|,|:|;|"|-|‖|\]|\)|\})/$1múlinex$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)mouse($|\.|,|:|;|"|-|‖|\]|\)|\})/$1maus$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)mouses($|\.|,|:|;|"|-|‖|\]|\)|\})/$1mauses$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)mozilla(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1mosila$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)msn(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1emesene$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)myspace(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1maispes$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)nashville($|\.|,|:|;|"|-|‖|\]|\)|\})/$1náchvil$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ni(c|k)ole($|\.|,|:|;|"|-|‖|\]|\)|\})/$1nikol$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)nietzsche($|\.|,|:|;|"|-|‖|\]|\)|\})/$1níche$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)nietzschean(a|o)(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1nichean$2$3$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)noam($|\.|,|:|;|"|-|‖|\]|\)|\})/$1nóam$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)nordic($|\.|,|:|;|"|-|‖|\]|\)|\})/$1nórdik$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)of($|\.|,|:|;|"|-|‖|\]|\)|\})/$1af$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)office($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ófis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)offices($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ófises$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ok($|\.|,|:|;|"|-|‖|\]|\)|\})/$1okey$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)okay($|\.|,|:|;|"|-|‖|\]|\)|\})/$1okey$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)orange($|\.|,|:|;|"|-|‖|\]|\)|\})/$1óranch$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)output($|\.|,|:|;|"|-|‖|\]|\)|\})/$1áutput$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)outsource($|\.|,|:|;|"|-|‖|\]|\)|\})/$1autsors$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)outsourcing($|\.|,|:|;|"|-|‖|\]|\)|\})/$1áutsorsin$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)paper(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1péper$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)paypal($|\.|,|:|;|"|-|‖|\]|\)|\})/$1peipal$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)pc(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pesé$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)pdc($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pedesé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)pdf(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pedeéfe$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)pdi($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pedeí$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)peak($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pik$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ph($|\.|,|:|;|"|-|‖|\]|\)|\})/$1peache$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)picnic($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pícnik$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)play(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1plei$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)pn($|\.|,|:|;|"|-|‖|\]|\)|\})/$1peéne$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)pool(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pul$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)powerpoint(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1páwerpoint$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)power(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1páwer$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ppd($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pepedé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ppt(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pepeté$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)pq($|\.|,|:|;|"|-|‖|\]|\)|\})/$1porque$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)pr($|\.|,|:|;|"|-|‖|\]|\)|\})/$1peérre$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)prsd($|\.|,|:|;|"|-|‖|\]|\)|\})/$1perresedé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ps($|\.|,|:|;|"|-|‖|\]|\)|\})/$1peése$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)pub(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pab$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)puzzle(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pusle$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)python($|\.|,|:|;|"|-|‖|\]|\)|\})/$1paiton$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)quatro($|\.|,|:|;|"|-|‖|\]|\)|\})/$1cuatro$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)quix($|\.|,|:|;|"|-|‖|\]|\)|\})/$1kwix$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)rally($|\.|,|:|;|"|-|‖|\]|\)|\})/$1rali$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)rallys($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ralis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ranger(|s)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1rányer$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)rapidshare($|\.|,|:|;|"|-|‖|\]|\)|\})/$1rápidcher$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)reader($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ríderr$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)reality($|\.|,|:|;|"|-|‖|\]|\)|\})/$1reáliti$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)reggaetón($|\.|,|:|;|"|-|‖|\]|\)|\})/$1reguetón$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)reggaetoner(o|a|os|as)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1reguetoner$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)rémington(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1réminton$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ripley($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ríplei$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)rn($|\.|,|:|;|"|-|‖|\]|\)|\})/$1erreéne$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)rob(b|)(y|ie)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1robi$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)rugby(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ragbi$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)s(a|á)n(d|)wich($|\.|,|:|;|"|-|‖|\]|\)|\})/$1sándwich$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sadowsk(y|i)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1sadoski$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)scarle(t|tt|tte|th)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1skárlet$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)scooter(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1scúter$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)scotch(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1scoch$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)scott(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1eskot$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sevenup(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1sevenáp$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)skateboard(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1skeitbord$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)skater(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1skéiter$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)skate(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1skeit$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)skype($|\.|,|:|;|"|-|‖|\]|\)|\})/$1eskaip$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)snowboard(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1snówbord$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)socialite(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1socialité$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sourceforge($|\.|,|:|;|"|-|‖|\]|\)|\})/$1sórsforch$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sour(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ságüer$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)spaghetti($|\.|,|:|;|"|-|‖|\]|\)|\})/$1espaguéti$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)starcraft($|\.|,|:|;|"|-|‖|\]|\)|\})/$1stárcraft$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)station(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1steichon$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)subway($|\.|,|:|;|"|-|‖|\]|\)|\})/$1sábwei$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)surf(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1serf$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sydney($|\.|,|:|;|"|-|‖|\]|\)|\})/$1sídnei$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)symantec($|\.|,|:|;|"|-|‖|\]|\)|\})/$1simántek$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)tb($|\.|,|:|;|"|-|‖|\]|\)|\})/$1térabaits$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)thunderbird(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1tánderberd$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)toilette(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1twalét$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)tripod($|\.|,|:|;|"|-|‖|\]|\)|\})/$1traipod$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)tvn($|\.|,|:|;|"|-|‖|\]|\)|\})/$1teveéne$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)tv(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1tevé$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)twister($|\.|,|:|;|"|-|‖|\]|\)|\})/$1twíster$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)twitter($|\.|,|:|;|"|-|‖|\]|\)|\})/$1twíter$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)up($|\.|,|:|;|"|-|‖|\]|\)|\})/$1upé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)upgrade($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ápgreid$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)upgrades($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ápgreids$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)url(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1uereéle$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)usenet($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yúsnet$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)wc(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1doblevesé$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)windsurf($|\.|,|:|;|"|-|‖|\]|\)|\})/$1wínserf$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)wok(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1gwok$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xa(b|v)ier(it|)(a|o|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jabier$3$4$5/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xa(v|b)i($|\.|,|:|;|"|-|‖|\]|\)|\})/$1javi$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xbox($|\.|,|:|;|"|-|‖|\]|\)|\})/$1éxbox$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xbox(e|)s($|\.|,|:|;|"|-|‖|\]|\)|\})/$1éxbox$2s$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ximena(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jimena$2$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xy($|\.|,|:|;|"|-|‖|\]|\)|\})/$1éxboxquis i$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xml($|\.|,|:|;|"|-|‖|\]|\)|\})/$1equisemeéle$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)yahoo($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yajú$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)(y|j)on(n|)at(t|h|)an($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yónatan$5/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)youtube($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yutub$2/g;

     # NEW AS OF 0451
     # Exceptions for single words!
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)evelyn($|\.|,|:|;|"|-|‖|\]|\)|\})/$1évelin$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)denis(|s)e($|\.|,|:|;|"|-|‖|\]|\)|\})/$1denís$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)marketing($|\.|,|:|;|"|-|‖|\]|\)|\})/$1márketin$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)psu($|\.|,|:|;|"|-|‖|\]|\)|\})/$1peeseú$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)giselle($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ymiaisél$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)robinson($|\.|,|:|;|"|-|‖|\]|\)|\})/$1róbinson$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)francesca($|\.|,|:|;|"|-|‖|\]|\)|\})/$1franchéska$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ebner($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ébner$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)molotov($|\.|,|:|;|"|-|‖|\]|\)|\})/$1mólotov$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)eduvigis($|\.|,|:|;|"|-|‖|\]|\)|\})/$1eduvíguis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)vries($|\.|,|:|;|"|-|‖|\]|\)|\})/$1vríes$2/g;

     # NEW AS OF 101
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)j(h|)o(h|)n($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yon$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)j(h|)o(h|)nat(h|)an($|\.|,|:|;|"|-|‖|\]|\)|\})/$1yónatan$5/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)antoine($|\.|,|:|;|"|-|‖|\]|\)|\})/$1antwán$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)washington($|\.|,|:|;|"|-|‖|\]|\)|\})/$1wáchinton$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)face($|\.|,|:|;|"|-|‖|\]|\)|\})/$1feis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hd($|\.|,|:|;|"|-|‖|\]|\)|\})/$1achedé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)mar(i|y)l(i|y|iy)n($|\.|,|:|;|"|-|‖|\]|\)|\})/$1márilin$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)punk(|s)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pank$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cal(i|e)fon(t|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1cálifon$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cal(i|e)fon(t|)s($|\.|,|:|;|"|-|‖|\]|\)|\})/$1cálifons$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)diet($|\.|,|:|;|"|-|‖|\]|\)|\})/$1dáyet$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)heavy($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jevi$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hiphoper(o|a)(s|)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jipjopér$4/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)light($|\.|,|:|;|"|-|‖|\]|\)|\})/$1lait$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)notebook($|\.|,|:|;|"|-|‖|\]|\)|\})/$1nótbuk$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)panties($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pántis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)pre(u|ú)($|\.|,|:|;|"|-|‖|\]|\)|\})/$1preú$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)reggaet(o|ó)n($|\.|,|:|;|"|-|‖|\]|\)|\})/$1reguetón$3/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)software($|\.|,|:|;|"|-|‖|\]|\)|\})/$1sófwer$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)super($|\.|,|:|;|"|-|‖|\]|\)|\})/$1súper$2/g;

	# NEW IN 104:
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)afp($|\.|,|:|;|"|-|‖|\]|\)|\})/$1aefepé$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)abp($|\.|,|:|;|"|-|‖|\]|\)|\})/$1abepé$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)avf($|\.|,|:|;|"|-|‖|\]|\)|\})/$1abeefe$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)acdc($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ásedése$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)macchu($|\.|,|:|;|"|-|‖|\]|\)|\})/$1machu$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)picchu($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pichu$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)photoshop($|\.|,|:|;|"|-|‖|\]|\)|\})/$1fotochop$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)philadelphia($|\.|,|:|;|"|-|‖|\]|\)|\})/$1filadelfia$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sd($|\.|,|:|;|"|-|‖|\]|\)|\})/$1esedé$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xd($|\.|,|:|;|"|-|‖|\]|\)|\})/$1equisdé$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hd($|\.|,|:|;|"|-|‖|\]|\)|\})/$1achedé$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xs($|\.|,|:|;|"|-|‖|\]|\)|\})/$1equisése$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xp($|\.|,|:|;|"|-|‖|\]|\)|\})/$1equispé$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)vhs($|\.|,|:|;|"|-|‖|\]|\)|\})/$1veacheése$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)udd($|\.|,|:|;|"|-|‖|\]|\)|\})/$1udedé$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ubb($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ubebé$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ip($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ipé$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cft($|\.|,|:|;|"|-|‖|\]|\)|\})/$1sefeté$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)war(c|k)raft($|\.|,|:|;|"|-|‖|\]|\)|\})/$1wárcraft$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)walter($|\.|,|:|;|"|-|‖|\]|\)|\})/$1wálter$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)walker($|\.|,|:|;|"|-|‖|\]|\)|\})/$1wálker$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)vtr($|\.|,|:|;|"|-|‖|\]|\)|\})/$1veteérre$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)tweet($|\.|,|:|;|"|-|‖|\]|\)|\})/$1twit$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)tweets($|\.|,|:|;|"|-|‖|\]|\)|\})/$1twits$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)tuit($|\.|,|:|;|"|-|‖|\]|\)|\})/$1twit$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)tuits($|\.|,|:|;|"|-|‖|\]|\)|\})/$1twits$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)tour($|\.|,|:|;|"|-|‖|\]|\)|\})/$1tur$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)tours($|\.|,|:|;|"|-|‖|\]|\)|\})/$1turs$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)touch($|\.|,|:|;|"|-|‖|\]|\)|\})/$1tach$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)good($|\.|,|:|;|"|-|‖|\]|\)|\})/$1gud$2/g;
	$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)wood($|\.|,|:|;|"|-|‖|\]|\)|\})/$1wud$2/g;

     # Convert *common* Roman numerals to Hindu-Arabic ones.                          #
     # Those that coincide with single latin letters (e.g. "i") and words (e.g. "vi") #
     # are NOT converted.                                                             #

     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ii($|\.|,|:|;|"|-|‖|\]|\)|\})/$1dos$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)iii($|\.|,|:|;|"|-|‖|\]|\)|\})/$1tres$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)iv($|\.|,|:|;|"|-|‖|\]|\)|\})/$1cuatro$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ix($|\.|,|:|;|"|-|‖|\]|\)|\})/$1nueve$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)vii($|\.|,|:|;|"|-|‖|\]|\)|\})/$1siete$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)viii($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ocho$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xi($|\.|,|:|;|"|-|‖|\]|\)|\})/$1once$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xii($|\.|,|:|;|"|-|‖|\]|\)|\})/$1doce$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xiii($|\.|,|:|;|"|-|‖|\]|\)|\})/$1trece$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xiv($|\.|,|:|;|"|-|‖|\]|\)|\})/$1catorce$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xix($|\.|,|:|;|"|-|‖|\]|\)|\})/$1diecinueve$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xv($|\.|,|:|;|"|-|‖|\]|\)|\})/$1quince$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xvi($|\.|,|:|;|"|-|‖|\]|\)|\})/$1dieciséis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xvii($|\.|,|:|;|"|-|‖|\]|\)|\})/$1diecisiete$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xviii($|\.|,|:|;|"|-|‖|\]|\)|\})/$1dieciocho$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xx($|\.|,|:|;|"|-|‖|\]|\)|\})/$1veinte$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xxi($|\.|,|:|;|"|-|‖|\]|\)|\})/$1veintiuno$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xxii($|\.|,|:|;|"|-|‖|\]|\)|\})/$1veintidos$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xxiii($|\.|,|:|;|"|-|‖|\]|\)|\})/$1veintitres$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xxiv($|\.|,|:|;|"|-|‖|\]|\)|\})/$1veinticuatro$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xxv($|\.|,|:|;|"|-|‖|\]|\)|\})/$1veinticinco$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xxvi($|\.|,|:|;|"|-|‖|\]|\)|\})/$1veintiséis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xxvii($|\.|,|:|;|"|-|‖|\]|\)|\})/$1veintisiete$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xxviii($|\.|,|:|;|"|-|‖|\]|\)|\})/$1veintiocho$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xxix($|\.|,|:|;|"|-|‖|\]|\)|\})/$1veintinueve$2/g;

     # "xxx" is not treated as a Roman numeral.
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)xxx($|\.|,|:|;|"|-|‖|\]|\)|\})/$1tripleéquis$2/g;

     # COMMON URL COMPONENTS (ALL BUT ONE ARE FILE EXTENSIONS)
     # NEW IN 396: Added "|>" to search expression following the target term, to catch things  #
     #             like ".htm" in "<www.blah.com/page.htm>"                                    #
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)www($|\.|,|:|;|"|-|‖|\]|\)|\})/$1tripledoblebé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)html($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1acheteemeéle$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)htm($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1acheteéme$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cfm($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1seefeéme$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)aspx($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1aesepeéquis$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)asp($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1aesepé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)php($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1peachepé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)jsp($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1jotaesepé$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cgi($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1segeí$2/g;

     # NEW IN 102: Process SINGLE-word backchannel vocalizations
     #   +++++     These must be in ALL CAPS.
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ah($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1AH$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ch($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1CH$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)eh($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1EH$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ff($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1FF$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)mm($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1MM$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)oh($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1OH$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)pf($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1PF$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sh($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1SH$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)uh($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1UH$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)hm($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1HM$2/g;

     # NEW IN 103: New exceptions
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)kaiser($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1káiser$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)benji($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1benyi$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)anthony($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1ántoni$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)wifi($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1wáifai$2/g;
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)kinder($|\.|,|:|;|"|-|‖|\]|\)|\}|>)/$1kínder$2/g;

     return ($current_item);
}

#################################################################################
#                            SPELL OUT SINGLE LETTERS                           #
#################################################################################
sub spell_out_single_letters {

     my $current_item = $_[0];

     if ( $vrt_format == 1 ) {

          #print STDOUT "SPELL-OUT-VRT-BEF:$current_item\n"; # AD-HOC DEBUG

          $current_item =~ s/(^| |ø)b( |ø|$)/$1belárga$2/g;
          $current_item =~ s/(^| |ø)c( |ø|$)/$1se$2/g;
          $current_item =~ s/(^| |ø)d( |ø|$)/$1de$2/g;
          $current_item =~ s/(^| |ø)f( |ø|$)/$1éfe$2/g;
          $current_item =~ s/(^| |ø)g( |ø|$)/$1je$2/g;
          $current_item =~ s/(^| |ø)h( |ø|$)/$1áche$2/g;
          $current_item =~ s/(^| |ø)j( |ø|$)/$1jóta$2/g;
          $current_item =~ s/(^| |ø)k( |ø|$)/$1ca$2/g;
          $current_item =~ s/(^| |ø)l( |ø|$)/$1éle$2/g;
          $current_item =~ s/(^| |ø)m( |ø|$)/$1éme$2/g;
          $current_item =~ s/(^| |ø)n( |ø|$)/$1éne$2/g;
          $current_item =~ s/(^| |ø)ñ( |ø|$)/$1éñe$2/g;
          $current_item =~ s/(^| |ø)p( |ø|$)/$1pe$2/g;
          $current_item =~ s/(^| |ø)q( |ø|$)/$1cu$2/g;
          $current_item =~ s/(^| |ø)r( |ø|$)/$1ére$2/g;
          $current_item =~ s/(^| |ø)s( |ø|$)/$1ése$2/g;
          $current_item =~ s/(^| |ø)t( |ø|$)/$1te$2/g;
          $current_item =~ s/(^| |ø)v( |ø|$)/$1$name_for_v$2/g;
          $current_item =~ s/(^| |ø)w( |ø|$)/$1doblebé$2/g;
          $current_item =~ s/(^| |ø)x( |ø|$)/$1équis$2/g;
          $current_item =~ s/(^| |ø)z( |ø|$)/$1séta$2/g;

          #print STDOUT "SPELL-OUT-VRT-AFT:$current_item\n\n"; # AD-HOC DEBUG
     }
     else {
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)b($|\.|,|:|;|"|-|‖|\]|\)|\})/$1be$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)c($|\.|,|:|;|"|-|‖|\]|\)|\})/$1se$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)d($|\.|,|:|;|"|-|‖|\]|\)|\})/$1de$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)f($|\.|,|:|;|"|-|‖|\]|\)|\})/$1efe$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)g($|\.|,|:|;|"|-|‖|\]|\)|\})/$1je$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)h($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ache$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)j($|\.|,|:|;|"|-|‖|\]|\)|\})/$1jota$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)k($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ca$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)l($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ele$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)m($|\.|,|:|;|"|-|‖|\]|\)|\})/$1eme$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)n($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ene$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ñ($|\.|,|:|;|"|-|‖|\]|\)|\})/$1eñe$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)p($|\.|,|:|;|"|-|‖|\]|\)|\})/$1pe$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)q($|\.|,|:|;|"|-|‖|\]|\)|\})/$1cu$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)r($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ere$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)s($|\.|,|:|;|"|-|‖|\]|\)|\})/$1ese$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)t($|\.|,|:|;|"|-|‖|\]|\)|\})/$1te$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)v($|\.|,|:|;|"|-|‖|\]|\)|\})/$1$name_for_v$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)w($|\.|,|:|;|"|-|‖|\]|\)|\})/$1doblebé$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)x($|\.|,|:|;|"|-|‖|\]|\)|\})/$1equis$2/g;
          $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)z($|\.|,|:|;|"|-|‖|\]|\)|\})/$1seta$2/g;
     }

     return ($current_item);
}

###########################################################################################
# SUBROUTINE: FIX LETTER PATTERNS                                                         #
###########################################################################################
sub fix_letter_patters {

     my $current_item = $_[0];

     ######################################################################################
     # Replace ANYWHERE                                                                   #
     ######################################################################################
     $current_item =~ s/aa/a/g;                               # sAA > sA
     $current_item =~ s/cc([aou])/k$1/g;                      # staCCato > staCato # WARNING New in 3-0-8
     $current_item =~ s/ck/k/g;                               # chadwiCK > chadwik
     $current_item =~ s/cq/q/g;                               # beCQueriano > bekeriano
     $current_item =~ s/ff/f/g;                               # maFFia > maFia (as in Pedro...)
     $current_item =~ s/gh/gu/g;                              # "ghetto" = [geto], not [jeto]
     $current_item =~ s/mm/m/g;                               # digaMMa > digaMa, graMMy > graMy
     $current_item =~ s/pp/p/g;                               # shoPPing > shoPing
     $current_item =~ s/sch/ch/g;                             # SCHafer > CHafer
     $current_item =~ s/sh/ch/g;                              # SHOpping > CHÓping, traSH > traSH
     $current_item =~ s/ss/s/g;                               # es.trap.les.s > es.trap.les
     $current_item =~ s/tch/ch/g;                             # keTCHup > keCHup # WARNING New in 2-9-8. Watch for regressions
     $current_item =~ s/tt/t/g;                               # maTThei > maThei
     $current_item =~ s/ym/im/g;                              # aYMara > aIMara (otherwise it would become /aʤ.ˈma.ɾa/)
     $current_item =~ s/ll([$orthog_epenth_e_cons])/l$1/g;    # "bulldozer" = bul.do.ser, "allcu" = "al.ku"
     $current_item =~ s/gnn/gn/g;                             # "Agnnes" = agn.nes > ag.nes

     ######################################################################################
     # Change at BEGINNING of word                                                        #
     ######################################################################################
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)mn/$1n/g;       # MNemotecnia > Nemotecnia
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)out/$1aut/g;    # MNemotecnia > Nemotecnia
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)ps/$1s/g;       # PSicología > Sicología
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)pt/$1t/g;       # PTerodáctilo > Terodáctilo
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)sh/$1ch/g;      # SHafer > CHafer
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)shw/$1chw/g;    # SHWartz: makes it /ʧu̯aɾts/, NOT /su̯aɾts/
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)st/$1est/g;     # STange > ESTange
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)mc/$1mak/g;     # MCiver > MAKiver     # WARNING Added in 3-0-6
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)cn/$1n/g;       # CNeorácea > Neorácea # WARNING Added in 3-0-8
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)gn/$1n/g;       # GNomo > Nomo, GNeiss > Neiss  # WARNING Added in 3-0-8
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)chr/$1cr/g;     # "christopher" > cristopher # WARNING Added in 312
                                                                     # WARNING Added in 3-0-0.

	# Added conditional statement in 103
	if ( $add_epenthetic_g == 1 ) {
		#$current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)w/$1gw/g;       # Westfaliano > GWestfaliano, Web > GWeb
		}

     # Add epenthetic /s/ at beginning of word
     $current_item =~ s/(^|\.|,|:|;|"|-|‖|\[|\(|\{)s($orthog_epenth_e_cons)/es$2/g;

     ######################################################################################
     # Replace at END of word                                                             #
     ######################################################################################
     $current_item =~ s/eaux($|\.|,|:|;|"|-|‖|\]|\)|\})/ó$1/g;             # SubercasEAUX > subercasó
     $current_item =~ s/iaux($|\.|,|:|;|"|-|‖|\]|\)|\})/ió$1/g;            # vIAUX > vió # NOTE This produces /ˈbi̯o/ (/bjo/) instead of /bi.'o/
     $current_item =~ s/ll($|\.|,|:|;|"|-|‖|\]|\)|\})/l$1/g;                # lluLL > lluL
     $current_item =~ s/lls($|\.|,|:|;|"|-|‖|\]|\)|\})/ls$1/g;              # nonparells, wells, balcells
     $current_item =~ s/ng($|\.|,|:|;|"|-|‖|\]|\)|\})/n$1/g;                # shoppiNG > shoppin
     $current_item =~ s/ngs($|\.|,|:|;|"|-|‖|\]|\)|\})/ns$1/g;              # liviNGS > liviNS
     $current_item =~ s/ys($|\.|,|:|;|"|-|‖|\]|\)|\})/is$1/g;               # currys > [kuris] and not [kur.dzhs]
     $current_item =~ s/lds($|\.|,|:|;|"|-|‖|\]|\)|\})/ld$1/g;              # mcdonaLDS > mcdonaLD  # WARNING Added in 306
     $current_item =~ s/nds($|\.|,|:|;|"|-|‖|\]|\)|\})/ns$1/g;              # estaNDS > estaNS # WARNING Added in 308
     $current_item =~ s/q($|\.|,|:|;|"|-|‖|\]|\)|\})/k$1/g;                 # estaNDS > estaNS # WARNING Added in 378
     $current_item =~ s/matic($|\.|,|:|;|"|-|‖|\]|\)|\})/mátic$1/g;        # NEW IN 419 "Drivematic", etc.
     $current_item =~ s/omic($|\.|,|:|;|"|-|‖|\]|\)|\})/ómich$1/g;         # NEW IN 419 "Tomic", etc.
     $current_item =~ s/añalic($|\.|,|:|;|"|-|‖|\]|\)|\})/áñalich$1/g;   # NEW IN 419 "Mañalic", etc.
     $current_item =~ s/endic($|\.|,|:|;|"|-|‖|\]|\)|\})/éndic$1/g;        # NEW IN 419 "Rendic", etc.
     $current_item =~ s/unovic($|\.|,|:|;|"|-|‖|\]|\)|\})/únovich$1/g;     # NEW IN 419 "Simunovic", etc.
     $current_item =~ s/omicic($|\.|,|:|;|"|-|‖|\]|\)|\})/ómicich$1/g;     # NEW IN 419 "Tomicic", etc.
     $current_item =~ s/evesic($|\.|,|:|;|"|-|‖|\]|\)|\})/évesich$1/g;     # NEW IN 419 "Chevesic", etc.
     $current_item =~ s/adic($|\.|,|:|;|"|-|‖|\]|\)|\})/ádich$1/g;         # NEW IN 419 "Fadic", etc.
     $current_item =~ s/inovic($|\.|,|:|;|"|-|‖|\]|\)|\})/ínovich$1/g;     # NEW IN 419 "Marinovic", etc.
     return ($current_item);

}

############################################################################
# SUBROUTINE: CONVERT PUNCTUATION TO PAUSES                                #
############################################################################
sub convert_punctuation_to_pauses {

     my $current_item = $_[0];

     ############################################################################
     # Catch ELLIPSES                                                           #
     ############################################################################
     if ( $current_item =~ m/\.\.\./ ) {
          $ellipsis_pause = 1;

          # Change ellipsis to € to avoid counting it as a periods, too. The € will
          # later be checked to see if it occurs right before a newline.
          $current_item =~ s/\.\.\./€/g;    # WARNING The ellipsis routine may not be fully implemented!
                                              # WARNING: In 400: Seems that € (formerly ¬) is never changed back
     }

     ############################################################################
     # Catch PERIODS for later insertion as "##" breaks                         #
     ############################################################################
     if ( $current_item =~ m/\./ ) {
          $sentence_break = 1;
     }

     ############################################################################
     # Catch COMMAS for later insertion as "(..)" pauses                        #
     ############################################################################
     if ( $current_item =~ m{,} ) {
          $comma_pause = 1;
     }

     ############################################################################
     # Catch SEMICOLONS for later insertion as "(...)" pauses                   #
     ############################################################################
     if ( $current_item =~ m{;} ) {
          $semicolon_pause = 1;
     }

     ############################################################################
     # Catch COLONS for later insertion as "(..)" pauses                        #
     ############################################################################
     if ( $current_item =~ m{:} ) {
          $colon_pause = 1;
     }

     ############################################################################
     # Catch BRACKETS for later insertion as "(.)" pauses                       #
     ############################################################################

     ############################################################################
     # INITIAL BRACKETS                                                         #
     if ( $current_item =~ m{\[} ) {
          $initial_bracket_pause = 1;
     }

     ############################################################################
     # FINAL BRACKETS                                                           #
     if ( $current_item =~ m{\]} ) {
          $final_bracket_pause = 1;
     }

     ############################################################################
     # Catch PARENS for later insertion as "(.)" pauses                         #
     ############################################################################

     ############################################################################
     # INITIAL PARENS                                                           #
     if ( $current_item =~ m{\(} ) {
          $initial_paren_pause = 1;
     }

     ############################################################################
     # FINAL PARENS                                                             #
     if ( $current_item =~ m{\)} ) {
          $final_paren_pause = 1;
     }

     ############################################################################
     #  Strip ALL whitespace, punctuation and other non-alphabetic chars from   #
     #  word.                                                                   #
     #                        (FOR NON-VRT FORMATS)                             #
     ############################################################################
     if ( $vrt_format == 0 ) {
          $current_item =~ s{\W}{}g;
     }
     ############################################################################
     # Strip whitespace, punctuation and other non-alphabetic chars from        #
     # BEGINNING and END of each word (which can actually be 1+ words in VRT    #
     # format).                                                                 #
     #                           (FOR VRT FORMAT)                               #
     ############################################################################
     if ( $vrt_format == 1 ) {
          $current_item =~ s{^\W}{}g;
          $current_item =~ s{\W$}{}g;
     }

     return ($current_item);
}

############################################################################
# CONVERT BACKCHANNEL VOCALIZATIONS                                        #
# NEW IN 102 - TESTING - DANGER!                                           #
# +++++                                                                    #
############################################################################

sub convert_backchannel_vocalizations {

     # To add backchannel vocalizations several things need to be done:
     # 1a. If they're multi-word (e.g. "mm hm"), you have to go to the
     #    replace_multiword_phrases subroutine and add an entry for them,
     #    converting them into some intermediate single-word representation
     #    that is in ALL CAPS.
     # 1b. If they're single-word, you have to do the same thing in the
     #    modify_single_ortho_words section.
     # 2. Add an entry here providing the definitive phonetic transcription,
     #    including syllabification. This MIGHT cause problems with certain
     #    types of transcripcion (e.g. CV)... haven't tested this yet. Some things
     #    don't work quite right, either: /ch/ gets a dental diacritic placed on the t.

     my $current_item = $_[0];

               # DEBUG
               #print STDOUT "\n\$current_item = $current_item";    # NOTE: DEBUG

     $current_item =~ s/MMHM/m̩.ˈhm̩/g;
     $current_item =~ s/NNNN/ˈnt̚.n̩/g;
     $current_item =~ s/UHHUH/ʔʌ.ˈhʌ/g;
     $current_item =~ s/UHOH/ˈʔʌ.ʔo/g;
     $current_item =~ s/UHUH/ˈʔʌ.ʔʌ/g;

     $current_item =~ s/AH/aː/g;
     $current_item =~ s/EH/eː/g;
     $current_item =~ s/OH/oː/g;
     $current_item =~ s/UH/uː/g;

     $current_item =~ s/FF/f̩ː/g;
     $current_item =~ s/PF/pf̩ː/g;
     $current_item =~ s/MM/m̩ː/g;
     $current_item =~ s/HM/hm̩ː/g;
     $current_item =~ s/CH/ʧʃ ̩ː/g;
     $current_item =~ s/SH/ʃ ̩ː/g;

     return ($current_item);

}


############################################################################
# SUBROUTINE: CONVERT (MOST) GRAPHEMES TO INTERMEDIATE REPRESENTATIONS OF  #
#             PHONEMES                                                     #
############################################################################

sub convert_graphemes_to_interm_phonemes {

     my $current_item = $_[0];

     # /tr/ cluster
     $current_item =~ s/tr/\{TR\}/g;

     # <ll> cluster
     $current_item =~ s/ll/\{J\}/g;

     # Grapheme <t>
     $current_item =~ s/t/\{T\}/g;

     # Grapheme <d>
     $current_item =~ s/d/\{D\}/g;

     # Grapheme <ñ>
     $current_item =~ s/ñ/\{Ñ\}/g;

     # Grapheme <v>
     $current_item =~ s/v/\{B\}/g;

     # <ch> cluster
     $current_item =~ s/ch/\{CH\}/g;

     # <qu> cluster
     $current_item =~ s/qui(e|é)/\{K\}i$1/g;    # To avoid conflicts with expressions below, "j" is represented as "\{J\}" here.
                                                 # WARNING WARNING WARNING I just changed the replace expression here from \{J\} to i
                                                 #    to fix errors like "quién" > /k.ʤen/, which I just started noticing in 2.7.2.
                                                 #  EXTENSIVE REGRESSION TESTING IS REQUIRED NOW.

     $current_item =~ s/qu(i|í)$/\{K\}$1/g;     # To catch words like "aquí".
     $current_item =~ s/qu(o|ó)/\{K\}\{W\}$1/g; # For latinisms like "quorum", etc.
     $current_item =~ s/qu/\{K\}/g;

     # Grapheme <x>
     $current_item =~ s/^x/\{S\}/g;              # <x> at beginning of word > /s/ ("xilófono").
     $current_item =~ s/x/\{KS\}/g;              # For all other words ("máximo", "aproximado", "Axolotl").

     # Grapheme <ü>
     # NOTE: This *retains* [g] in words with orthographic <g> plus <ü> (e.g. <agüero>).
     #       A distinction is thus introduced between <hu> and <gü> (e.g. <huevón> vs. <güevón>). This
     #       distinction is artificial and not reflected in language use; it exists to allow words like
     #       <agüero> to retain /g/, while not introducing the epenthetic [g] (if so desired) in words
     #       words like <huevo>. Thus, it should only be a problem with variant spellings that are considered
     #       incorrect, like "güevo".
     $current_item =~ s/ü/\{W\}/g;

     # Grapheme <h>
     # Changed in 0462: Add option to NOT add epenthetic [g]
     if ( $add_epenthetic_g == 1 ) {
          $current_item =~ s/hu$all_vowels/\{G\}\{W\}$1/g;    # "huevo" > hwebo > /gwebo/, "huacho" > /gwacho/
     }
     else {
          $current_item =~ s/hu$all_vowels/\{W\}$1/g;    # "huevo" > hwebo > /webo/, "huacho" > /wacho/
     }

     $current_item =~ s/h//g;                            # Eliminate <h> in all other cases.

     # Grapheme <g>
     $current_item =~ s/gu(i|í|e|é)/\{G\}$1/g;         # Catch words like "Guevara" and "guita" and avoid /gwe.../, /gwi.../
     $current_item =~ s/g(a|á|o|ó|u|ú)/\{G\}$1/g;
     $current_item =~ s/g(i|í|e|é)/\{X\}$1/g;

     # Grapheme <r>, in various combinations
     $current_item =~ s/rr/\{RR\}/g;
     $current_item =~ s/^r/\{RR\}/g;
     $current_item =~ s/sr/s\{RR\}/g;
     $current_item =~ s/zr/z\{RR\}/g;                    # As in "azre"
     $current_item =~ s/lr/l\{RR\}/g;                    # Is this actually the linguistic case?
     $current_item =~ s/nr/n\{RR\}/g;                    # Is this actually the linguistic case?
     $current_item =~ s/r/\{R\}/g;

     # Grapheme <j>
     $current_item =~ s/j/\{X\}/g;

     # Grapheme <c>
     $current_item =~ s/c(i|í|e|é)/\{S\}$1/g;
     $current_item =~ s/c/\{K\}/g;

     # TODO 105: Key line for fixing voseo accentuation
     # Grapheme <y> in general
     $current_item =~ s/y/\{J\}/g;
     #print "\n$current_item";	# DEBUG

     # NEW in 105: Key line for fixing voseo accentuation
     # WARNING TESTING
     # If there's a word-final grapheme "y", make the last vowel acute.
	$current_item =~ s/i\{J\}$/íj/g;
	$current_item =~ s/e\{J\}$/éj/g;
	$current_item =~ s/a\{J\}$/áj/g;
	$current_item =~ s/o\{J\}$/ój/g;
	$current_item =~ s/u\{J\}$/új/g;

	#print "\n$current_item";	# DEBUG


     # NEW in 105: Key line for fixing voseo accentuation
     # WARNING TESTING
     # I disabled the following, as the preceding should take care of it.
     #
     #
     # Fix grapheme <y> at end of word, so it's /i/ (or /j/), and not /ʤ/
     #$current_item =~ s/\{J\}$/i/g;
     #print "\n$current_item";	# DEBUG

     # Fix the grapheme <y> when it's representing the preposition "y"
     $current_item =~ s/^\{J\}$/i/g;
     # DEBUG
	#print "\n$current_item";	# DEBUG

     return ($current_item);

}

############################################################################
# SUBROUTINE: CHANGE INTERMEDIATE REPRESENTATIONS OF PHONEMES TO THEIR     #
#                    DEFINITIVE **ONE-CHARACTER** FORMS                    #
############################################################################
sub change_interm_phonemes_to_one_char {

     my $current_item = $_[0];

     $current_item =~ s/\{B\}/b/g;
     $current_item =~ s/\{CH\}/ʧ/g;
     $current_item =~ s/\{D\}/d/g;
     $current_item =~ s/\{G\}/g/g;
     $current_item =~ s/\{J\}/ʤ/g;
     $current_item =~ s/\{K\}/k/g;
     $current_item =~ s/\{KS\}/ks/g;
     $current_item =~ s/\{Ñ\}/ɲ/g;
     $current_item =~ s/\{R\}/ɾ/g;
     $current_item =~ s/\{RR\}/r/g;
     $current_item =~ s/\{S\}/s/g;
     $current_item =~ s/\{TR\}/ʂ/g;
     $current_item =~ s/\{T\}/t/g;
     $current_item =~ s/\{W\}/w/g;
     $current_item =~ s/\{X\}/x/g;

     return ($current_item);

}

############################################################################
# SUBROUTINE: PROCESS DIPHTHONGS                                           #
#   /j/ and /w/ are used as intermetiate representations of                #
#   non-syllabic vowels                                                    #
############################################################################
sub process_diphthongs {

     my $current_item = $_[0];

     ############################################################################
     # Turn <unaccented vowel> + <i> into [új].                                 #
     # Makes "Jujuy" > [xu.'xuj] (and not ['xu.xwi]. But DOESN'T process "fui". #
     ############################################################################
     if (    $current_item !~ m/áéíóú/
          && $current_item ne "fui" )
     {
          $current_item =~ s/ui$/új/g;
     }

     ############################################################################
     # Phoneme /j/ in diphthongs                                                #
     $current_item =~ s/i(e|a|o|u|é|ó|ú)/j$1/g;    # FIX ME!!!

     # Added in 390 WARNING Watch for regressions!
     $current_item =~ s/éis$/éjs/g;

     ############################################################################
     # Phoneme /w/ in diphthongs                                                #
     $current_item =~ s/u(i|e|a|o|í|é|á|ó)/w$1/g;

     ############################################################################
     # Turn /i/ into /j/ in diphthongs
     $current_item =~ s/(a|e|a|o|u)i/$1j/g;
     $current_item =~ s/(a|e|a|o)u/$1w/g;

	#print "\n==> DIPHTHONG PROCESSED: $current_item"; # DEBUG 105

     return ($current_item);

}

###############################################################################
#                                                                             #
# SUBROUTINE: STRESS ACCENT ROUTINE - PREPARATION                             #
#                                                                             #
###############################################################################
# NOTE: This section need to be *here*, before tildes are removed from vowels.#
###############################################################################
sub stress_accent_routine {

     my $current_item = $_[0];

     # print binmode "START-STRESS-ACCENT-RT:$current_item\n"; # AD-HOC DEBUG

     # Split current word up into characters and assign each to an array
     @character = split //, $current_item;

     # Get number of items (characters) in the character array
     my $char_count = @character;

     # Get the vowel characters and count them.
     $vowels = $current_item;

     # Here is an odd but necessary mix of phonemes (b,d,ɾ) and graphemes (y,z). #
     # This line removes them to leave just vowels.                              #
     $vowels =~ s/(b|ʧ|d|ʤ|f|g|j|k|l|m|n|ɲ|p|ɾ|r|s|ʂ|t|w|x|y|z)//g;

     #print "\n$vowels";	# DEBUG

     $accent         = "";    # Reset this just in case.
     $last_vowel_pos = "";    # Reset this just in case.

     # Get the number of vowels in the word being analyzed.
     $vowel_count = length($vowels);

     #print "\nCurrent Item:\t$current_item\nVowels:\t\t$vowels ($vowel_count)\n";	# DEBUG 105

     ############################################################################
     #                   STRESS ACCENT ROUTINE - LOGIC AND ACTION               #
     ############################################################################

     ############################################################################
     # If word is monosyllabic, assign accent to its lone vowel                 #
     # NOTE: The vowels of monosyllabic words should NOT get a tilde (or,       #
     #       later, a stress mark ').                                           #
     if ( $vowel_count == 1 ) {
          $accent = "monosyllabic";

          # Remove tildes from monosyllabic words, or else they'll get stress accent symbols
          $current_item =~ s/á/a/;
          $current_item =~ s/é/e/;
          $current_item =~ s/í/i/;
          $current_item =~ s/ó/o/;
          $current_item =~ s/ú/u/;
     }

     ############################################################################
     # Skip words that have tildes, as their stress is already indicated        #
     ############################################################################
     elsif ( $vowels =~ m/$stressed_vowels/ ) {
          $accent = "tilde";
     }

     ############################################################################
     # DANGER Changed in 105                                                    #
     # This, along with the other changes, finally fixed the accentuation error #
     # that was affecting mainly Chilean voseo verb forms.                      #
     #                                                                          #
     # If word ends in acute-izing consonant, stress is on last syllable        #
     ############################################################################
     #elsif ( $character[-1] =~ m/[$acute_consonants]/ ) {
     #     $accent = "acute";
	elsif ( $character[-1] =~ m/[$acute_consonants_except_j]/ ) {
           $accent = "acute";

          #######################################################################
          # This is a rather complex way of figuring out the last vowel.        #
          #######################################################################

          # First, reverse the list of vowels, split it and put it into an array.
          @rev_vowels = ( split //, reverse($vowels) );

          # The first element of the array, @rev_vowels[0], is the first vowel.
          $last_vowel_pos = rindex( $current_item, $rev_vowels[0] );

          # Now replace unaccented last vowel with accented version
          $character[$last_vowel_pos] =~ s/a/á/;
          $character[$last_vowel_pos] =~ s/e/é/;
          $character[$last_vowel_pos] =~ s/i/í/;
          $character[$last_vowel_pos] =~ s/o/ó/;
          $character[$last_vowel_pos] =~ s/u/ú/;

          # Rebuild $current_item using the characters in the array @character
          $current_item = join( "", @character );
     }

     ############################################################################
     # In all other cases, stress is on second-to-last syllable.                #
     ############################################################################
     else {
          $accent = "grave";

          ############################################################################
          # This is a roundabout way of figuring out the second-to-last vowel.       #
          ############################################################################

          # First, reverse the list of vowels, split it and put it into an array.    #
          @rev_vowels = ( split //, reverse($vowels) );

          # The first element of the array, $rev_vowels[0], is the first vowel.      #
          $last_vowel_pos = rindex( $current_item, $rev_vowels[0] );
          $sec_last_vowel_pos = rindex( $current_item, $rev_vowels[1], $last_vowel_pos - 1 );

          # Now replace unaccented last vowel with accented version                  #
          $character[$sec_last_vowel_pos] =~ s/a/á/;
          $character[$sec_last_vowel_pos] =~ s/e/é/;
          $character[$sec_last_vowel_pos] =~ s/i/í/;
          $character[$sec_last_vowel_pos] =~ s/o/ó/;
          $character[$sec_last_vowel_pos] =~ s/u/ú/;

          # Rebuild $current_item using the characters in the array @character               #
          $current_item = join( '', @character );
     }

     #print "Accent: $accent\t$current_item\n";	# DEBUG

     return ($current_item);

}

############################################################################
# SUBROUTINE: FINAL TOUCHES TO THE BROAD TRANSCRIPTION                     #
############################################################################
sub final_touches_broad_transcr {

     my $current_item = $_[0];

     # Grapheme <z>
     $current_item =~ s/z/s/g;

     # Phoneme /j/ at end of word
     $current_item =~ s/([^$all_vowels])j$/$1i/g;    # <y> a final de palabra = /i/: "Uruguay"

     return ($current_item);

}

############################################################################
#                                                                          #
#                        SUBROUTINE: SYLLABIFICATION                       #
#                                                                          #
############################################################################
sub perform_syllabification {

     my ($current_item) = $_[0];

     if ( $debug_syllab_sub == 1 ) {
          print STDOUT "\n\$current_item = $current_item";    # NOTE DEBUG
     }

     @character = split //, $current_item;

     my $char_count = @character;

     for ( $i = 0 ; $i < $char_count ; $i++ ) {

          #################################################################################
          #                           SYLLABIFICATION RULE 1                              #
          #                                                                               #
          # AFFECTS: C + /bdfgkp/ + /ɾl/ + /j/                                            #
          # CHANGES: Inserts syllable break between consonants 1 & 2                      #
          # EXAMPLE: em.bɾja.gaɾ                                                          #
          #################################################################################
          # WARNING 2: Added "l" to the second expression below; used to be only ɾ        #
          if (    $character[$i] =~ m/[$all_consonants]/
               && $character[ $i + 1 ] =~ m/[bdfgkp]/
               && $character[ $i + 2 ] =~ m/[ɾl]/
               && $character[ $i + 3 ] eq "j" )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 3;
          }

          # WARNING Added "w" to "j" in final expression in 311 WARNING                   #
          #################################################################################
          #                           SYLLABIFICATION RULE 2                              #
          #                                                                               #
          # AFFECTS: /bdfgkp/ + /ɾl/ + /jw/                                               #
          # CHANGES: Inserts NO syllable break                                            #
          # EXAMPLE: gɾje.ga (crianza, briana, etc.)                                      #
          #################################################################################
          # WARNING 2: Added "l" to the second expression below; used to be only ɾ        #
          # WARNING Added "w" to "j" in third expression below in 311                     #
          elsif ( $character[$i] =~ m/[bdfgkp]/
               && $character[ $i + 1 ] =~ m/[ɾl]/
               && $character[ $i + 2 ] =~ m/[jw]/ )
          {

               # Add NO syllable dot

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 3                              #
          #     Same as a later rule, but catches this cluster when preceeded by vowel.   #
          #                                                                               #
          # AFFECTS: V + /bdfgkp/ + /ɾl/ + /jw/ # DANGER Added /w/ to /j/ in 311          #
          # CHANGES: Inserts syllable break after vowel                                   #
          # EXAMPLE: i.gɾje.ga   (acrianza, apriori, adriático, etc.)                     #
          #################################################################################
          # WARNING 2: Added "l" to the second expression below; used to be only ɾ        #
          # WARNING: Added "w" to "j" in final expression in 311                          #

          elsif ( $character[$i] =~ m/[$all_vowels]/
               && $character[ $i + 1 ] =~ m/[bdfgkp]/
               && $character[ $i + 2 ] =~ m/[ɾl]/
               && $character[ $i + 3 ] =~ m/[jw]/ )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 3;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 4                              #
          #                                                                               #
          # AFFECTS: 4 consecutive MISC CONS                                              #
          # CHANGES: Inserts syllable break between consonants 2 & 3                      #
          # EXAMPLE: in.scrito, ek.s(tr)anjero                                            #
          #################################################################################
          elsif ( $character[$i] =~ m/[$all_consonants]/
               && $character[ $i + 1 ] =~ m/[$all_consonants]/
               && $character[ $i + 2 ] =~ m/[$all_consonants]/
               && $character[ $i + 3 ] =~ m/[$all_consonants]/ )
          {

               # Add syllable dot
               $character[ $i + 2 ] = (".$character[$i+2]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 3;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 5                              #
          #                                                                               #
          # AFFECTS: MISC CONS + /s/ + APPRX                                              #
          # CHANGES: Inserts syllable break between consonants 1 & 2                      #
          # EXAMPLE: op.sión sek.swál                                                     #
          #################################################################################
          elsif ( $character[$i] =~ m/[$all_consonants]/
               && $character[ $i + 1 ] eq "s"
               && $character[ $i + 2 ] =~ m/[jw]/ )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 6                              #
          #                                                                               #
          # AFFECTS: MISC CONS + /s/ + MISC CONS (NON-APPRX)                              #
          #          ($all_consonants includes approximants, but they are processed in    #
          #          this environment by Syllabification Rule 2).                         #
          # CHANGES: Inserts syllable break between consonants 2 & 3                      #
          # EXAMPLE: ins.pirado, eks.perjensja                                            #
          #################################################################################
          elsif ( $character[$i] =~ m/[$all_consonants]/
               && $character[ $i + 1 ] eq "s"
               && $character[ $i + 2 ] =~ m/[$all_consonants]/ )
          {

               # Add syllable dot
               $character[ $i + 2 ] = (".$character[$i+2]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 7                              #
          #                                                                               #
          # AFFECTS: /s/ + /u/ + /b/ + /lɾw/ at BEGINNING OF WORD                         #
          # CHANGES: Inserts syllable break after /b/. Basically for prefix "sub-"        #
          # EXAMPLE: SU.Brep.ti.sjo > SUB.rep.ti.sjo                                      #
          #################################################################################
          # NOTE In 317, changed the second argument from [$all_vowels] to eq "u", as it  #
          #      was syllabifying "imposible" > im.posib.le, etc.                         #
          #      Also changed it to only apply at the beginning of words (in effect, to   #
          #      prefix "sub-").                                                          #
          elsif ( $character[$i] eq "s"
               && $character[ $i + 1 ] eq "u"
               && $character[ $i + 2 ] eq "b"
               && $character[ $i + 3 ] =~ m/[lɾw]/ )
          {

               # Limit this rule to cases where /sub/ is at the beginning of the word     #
               # since the rule seems to only apply at that position                      #
               if ( $i == 0 ) {

                    # Add syllable dot
                    $character[ $i + 3 ] = (".$character[$i+3]");

                    # Increment $i so as not to repeatedly process this cluster
                    $i = $i + 3;
               }
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 8                              #
          #                                                                               #
          # AFFECTS: VOWEL + /b/ + LIQUID                                                 #
          # CHANGES: Inserts syllable break between VOWEL and /b/.                        #
          # EXAMPLE: This gets words like "pro.blema", "ha.blar" and "a.brir", but it     #
          #          DOESN'T get words like "increíble", which comes out as in.kɾe.ÍBLE   #
          #          without additional (later) measures                                  #
          #################################################################################
          elsif ( $character[$i] =~ m/[$all_vowels]/
               && $character[ $i + 1 ] eq "b"
               && $character[ $i + 2 ] =~ m/[lrɾ]/ )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 9                              #
          #                                                                               #
          # AFFECTS: [s] + [t] + C                                                        #
          # CHANGES: Inserts syllable break between 2nd and 3rd.                          #
          # EXAMPLE: poSTData, poSTPalatal, poSTGuerra,                                   #
          #          ("postraumático" shouldn't be included as /tr/ is one phoneme        #
          #################################################################################
          elsif ( $character[$i] eq "s"
               && $character[ $i + 1 ] eq "t"
               && $character[ $i + 2 ] =~ m/[$all_consonants]/ )
          {

               # Add syllable dot
               $character[ $i + 2 ] = (".$character[$i+2]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 10                             #
          #                                                                               #
          # AFFECTS: [w] + [bkdfgxp] + [ɾl]                                               #
          # CHANGES: Inserts syllable break between 2nd and 3rd syllable.                 #
          # EXAMPLE: "Louvre" = lowb.ɾe > low.bɾe                                         #
          #################################################################################
          # WARNING ADDED IN 320.                                                         #
          elsif ( $character[$i] eq "w"
               && $character[ $i + 1 ] =~ m/[bkdfgxp]/
               && $character[ $i + 2 ] =~ m/[ɾl]/ )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }






          #################################################################################
          #                           SYLLABIFICATION RULE 10-B                           #
          #                                                                               #
          # AFFECTS: [w] + C + [j]                                                        #
          # CHANGES: Inserts syllable break between 1st and 2nd syllable.                 #
          # EXAMPLE: Claudia > klaw.dja, NOT klawd.jazz                                   #
          #################################################################################
          # WARNING Added this rule in 0457                                               #
          elsif ( $character[$i] eq "w"
               && $character[ $i + 1 ] =~ m/[$all_consonants]/
               && $character[ $i + 2 ] =~ m/[j]/ )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }





         #################################################################################
          #                           SYLLABIFICATION RULE 11                             #
          #                                                                               #
          # AFFECTS: [w] + C + C                                                          #
          # CHANGES: Inserts syllable break between 2nd and 3rd syllable.                 #
          # EXAMPLE: output, outsource                                                    #
          #################################################################################
          # WARNING Added this rule in 320                                                #
          elsif ( $character[$i] eq "w"
               && $character[ $i + 1 ] =~ m/[$all_consonants]/
               && $character[ $i + 2 ] =~ m/[$all_consonants]/ )
          {

               # Add syllable dot
               $character[ $i + 2 ] = (".$character[$i+2]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 12                             #
          #                                                                               #
          # AFFECTS: [ɾ]  +  [kg]  +  [s]                                                 #
          # CHANGES: Inserts syllable break between 2nd and 3rd.                          #
          # EXAMPLE: mark.sis.ta, ber.gso.nja.no > berg.so.nja.no                         #
          #################################################################################
          elsif ( $character[$i] eq "ɾ"
               && $character[ $i + 1 ] =~ /[gk]/
               && $character[ $i + 2 ] eq "s" )
          {

               # Add syllable dot
               $character[ $i + 2 ] = (".$character[$i+2]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 13                             #
          #                      Exceptions to 12 (3 consec misc cons)                    #
          #                                                                               #
          # AFFECTS: 3 consecutive MISC CONS (SPECIFIC ONES, THOUGH)                      #
          # CHANGES: Inserts syllable break between 2nd and 3rd.                          #
          # EXAMPLE: corp.banca, gold.farb, gerb.ner, lamb.da                             #
          #################################################################################
          # TESTING WARNING Added in 320
          elsif ( $character[$i] =~ m/[lɾm]/
               && $character[ $i + 1 ] =~ m/[bpd]/
               && $character[ $i + 2 ] =~ m/[bdnf]/ )
          {

               # Add syllable dot
               $character[ $i + 2 ] = (".$character[$i+2]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 14                             #
          #                                                                               #
          # AFFECTS: 3 consecutive MISC CONS                                              #
          # CHANGES: Inserts syllable break between 1st and 2nd.                          #
          # EXAMPLE: in.creíble, im.provisar, es.drújula.                                 #
          #################################################################################

          # FIX ME!!! 390 -- this incorrectly turns "bejntiséjs" into "bej.ntiéjejs"
          # Changed from $all_consonants in 390. EXPERIMENTAL!
          elsif ( $character[$i] =~ m/[$all_consonants_but_glides]/
               && $character[ $i + 1 ] =~ m/[$all_consonants]/
               && $character[ $i + 2 ] =~ m/[$all_consonants]/ )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 15                             #
          #                                                                               #
          # AFFECTS: LIQUID + LIQUID                                                      #
          # CHANGES: Inserts syllable break between 1st and 2nd.                          #
          # EXAMPLE: ar.let (?), alrededor (?) NOTE: must verify examples                 #
          #################################################################################
          elsif ( $character[$i] =~ m/[lrɾ]/
               && $character[ $i + 1 ] =~ m/[lrɾ]/ )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 1;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 16                             #
          #                                                                               #
          # AFFECTS: /j/ + LIQUID                                                         #
          # CHANGES: Inserts syllable break between them.                                 #
          # EXAMPLE: paj.lón (?)  NOTE: must verify examples                              #
          #################################################################################

          elsif ( $character[$i] eq "j"
               && $character[ $i + 1 ] =~ m/[lrɾ]/ )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 1;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 17                             #
          #                                                                               #
          # AFFECTS: ACUTE CONS (NOT /n,s/) + LIQUID                                      #
          # CHANGES: This PREVENTS a syllable break from being inserted between them.     #
          # EXAMPLE: PREVENTS f.río, hab.lar (but PERMITS is.rael, en.redado).            #
          #################################################################################
          elsif ( $character[$i] =~ m/[$acute_consonants]/
               && $character[ $i + 1 ] =~ m/[lrɾ]/ )
          {

               # Do not introduce syllable break - this just skips this
               # cluster to avoid incorrect syllabification

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 1;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 18                             #
          #                                                                               #
          # AFFECTS: MISC CONS + /j,w/                                                    #
          # CHANGES: This PREVENTS a syllable break from being inserted between them.     #
          # EXAMPLE: PREVENTS k.watro, k.jen                                              #
          #################################################################################
          elsif ( $character[$i] =~ m/[$all_consonants]/
               && $character[ $i + 1 ] =~ m/[jw]/ )
          {

               # Do not introduce syllable break

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 1;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 19                             #
          #                                                                               #
          # AFFECTS: MISC CONS + MISC CONS                                                #
          # CHANGES: Inserts a syllable break between the two.                            #
          # EXAMPLE: ac.ción tam.bién can.sado                                            #
          #################################################################################
          # FIX ME!!! This rule turns "veintiséis" into /bej.ntiséjs/
          # WARINING - Changed variable in next line to $all_consonants_but_glides in 390!!!
          elsif ( $character[$i] =~ m/[$all_consonants_but_glides]/
               && $character[ $i + 1 ] =~ m/[$all_consonants]/ )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 1;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 20                             #
          #                                                                               #
          # AFFECTS: VOWEL + /[ʧdfgkp]/ + /ɾ/                                             #
          # CHANGES: Inserts syllable break between VOWEL and /[ʧdfgkp]/                  #
          # EXAMPLE: Should make "Pedro" y "adramático" become /pe.dɾo/, /a.dɾa.../ and   #
          #          NOT /pedɾo/, /adɾa.ma.../.                                           #
          #################################################################################
          elsif (
                  $character[$i] =~ m/[$all_vowels]/
               && $character[ $i + 1 ] =~ m/[ʧdfgkp]/    # NOTE I need a different accent for [mnx] - MAKE NEW RULE MAYBE!
               && $character[ $i + 2 ] eq "ɾ"
            )    # Might be necessary to add a 4th place here - a
                 # trailing vowel - to prevent false positives
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 21                             #
          #                                                                               #
          # AFFECTS: VOWEL  +  /ɾ/  +  /w/                                                #
          # CHANGES: Inserts a syllable break between /ɾ/ and /w/.                        #
          # EXAMPLE: da.ɾwin > daɾ.win                                                    #
          #################################################################################
          elsif ( $character[$i] =~ m/[$all_vowels]/
               && $character[ $i + 1 ] eq "ɾ"
               && $character[ $i + 2 ] eq "w" )
          {

               # Add syllable dot
               $character[ $i + 2 ] = (".$character[$i+2]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 22                             #
          #                                                                               #
          # AFFECTS: MISC CONS + VOWEL                                                    #
          # CHANGES: Inserts a syllable break BEFORE CONS.                                #
          # EXAMPLE: to.ma.te, a.mi.go, ca.mi.se.ta                                       #
          #################################################################################
          elsif ( $character[$i] =~ m/[$all_consonants]/
               && $character[ $i + 1 ] =~ m/[$all_vowels]/ )
          {

               # Add syllable dot
               $character[$i] = (".$character[$i]");

               # Increment $i so as not to repeatedly process this cluster
               #$i = $i + 1;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 23                             #
          #                                                                               #
          # AFFECTS: VOWEL *without* tilde   +   VOWEL *with* tilde                       #
          # CHANGES: Inserts a syllable break between them.                               #
          # EXAMPLE: fre.ír, a.ún, pro.híbe, ba.úl, pe.ón                                 #
          #################################################################################
          elsif ( $character[$i] =~ m/[$unstressed_vowels]/
               && $character[ $i + 1 ] =~ m/[$stressed_vowels]/ )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # DON'T DO IT! This makes the script miss increíble > Í.BLE!
               # Increment $i so as not to repeatedly process this cluster
               #$i = $i + 1;    # NOTE: DOUBTFUL!!!
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 24                             #
          #                                                                               #
          # AFFECTS: VOWEL *with* tilde   +   VOWEL *without* tilde                       #
          # CHANGES: Inserts a syllable break between them.                               #
          # EXAMPLE: pí.o, trí.o, frí.o                                                   #
          #################################################################################
          elsif ( $character[$i] =~ m/[$stressed_vowels]/
               && $character[ $i + 1 ] =~ m/[$unstressed_vowels]/ )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 1;    # NOTE: DOUBTFUL!!!
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 25                             #
          #                                                                               #
          # AFFECTS: STRONG VOWEL  +  STRONG VOWEL                                        #
          # CHANGES: Inserts a syllable break between them.                               #
          # EXAMPLE: pa.ola, co.articular, a.edo, pe.atón                                 #
          #################################################################################
          elsif ( $character[$i] =~ m/[$strong_vowels]/
               && $character[ $i + 1 ] =~ m/[$strong_vowels]/ )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 26                             #
          #                                                                               #
          # AFFECTS: [u]  +  [u]                                                          #
          # CHANGES: Inserts a syllable break between them.                               #
          # EXAMPLE: con.ti.nuum >con.ti.nu.um                                            #
          #################################################################################
          elsif ( $character[$i] eq "u"
               && $character[ $i + 1 ] eq "u" )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 1;    # NOTE: DOUBTFUL!!!
          }

          #################################################################################
          #####                    Miscellaneous syllabification                     ######
          #################################################################################

          #################################################################################
          #                           SYLLABIFICATION RULE 27                             #
          #                                                                               #
          # AFFECTS: VOWEL  +  MISC CONS  +  /j,w/                                        #
          # CHANGES: Inserts a syllable break between VOWEL + CONS.                       #
          # EXAMPLE: a.kwerdo (?)                                                         #
          #################################################################################
          elsif ( $character[$i] =~ m/[$all_vowels]/
               && $character[ $i + 1 ] =~ m/[$all_consonants]/
               && $character[ $i + 2 ] =~ m/[jw]/ )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 28                             #
          #                                                                               #
          # AFFECTS: VOWEL  +  /ɾ/  +  /t/ + /l/                                          #
          # CHANGES: Inserts a syllable break after /t/.                                  #
          # EXAMPLE: por.tland > port.land                                                #
          #################################################################################
          elsif ( $character[$i] =~ m/[$all_vowels]/
               && $character[ $i + 1 ] eq "ɾ"
               && $character[ $i + 2 ] eq "t"
               && $character[ $i + 3 ] eq "l" )
          {

               # Add syllable dot
               $character[ $i + 3 ] = (".$character[$i+3]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 3;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 29                             #
          #                                                                               #
          # AFFECTS: VOWEL  +  /fgkmptx/  +  /l/                                          #
          # CHANGES: Inserts a syllable break after VOWEL.                                #
          # EXAMPLE: a.tlántico, a.clarar, a.glutina, ba.plazar                           #
          #################################################################################
          # WARNING 316 - Removed /d/ from list of first consonants.
          elsif ( $character[$i] =~ m/[$all_vowels]/
               && $character[ $i + 1 ] =~ m/[bfgkpt]/
               && $character[ $i + 2 ] eq "l" )
          {

               # Add syllable dot
               $character[ $i + 1 ] = (".$character[$i+1]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 30                             #
          #                                                                               #
          # AFFECTS: VOWEL  +  /ʧdmx/  +  /l/                                             #
          # CHANGES: Inserts a syllable break after 1ST CONSONANT.                        #
          # EXAMPLE: po.si.BLe, aD.Látero, aSH.Li, aSH.Ram (aCH.Ram)                      #
          #################################################################################
          elsif ( $character[$i] =~ m/[$all_vowels]/
               && $character[ $i + 1 ] =~ m/[ʧdmx]/
               && $character[ $i + 2 ] =~ m/[l]/ )
          {

               # Add syllable dot
               $character[ $i + 2 ] = (".$character[$i+2]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

          #################################################################################
          #                           SYLLABIFICATION RULE 31                             #
          #                                                                               #
          # AFFECTS: VOWEL  +  /w/  +  /lrɾ/                                              #
          # CHANGES: Inserts a syllable break after /w/                                   #
          # EXAMPLE: ew.ɾo, paw.la                                                        #
          #################################################################################
          elsif ( $character[$i] =~ m/[$all_vowels]/
               && $character[ $i + 1 ] eq "w"
               && $character[ $i + 2 ] =~ m/[lrɾ]/ )
          {

               # Add syllable dot
               $character[ $i + 2 ] = (".$character[$i+2]");

               # Increment $i so as not to repeatedly process this cluster
               $i = $i + 2;
          }

     }

     $current_item = join( "", @character );    # Might have to move this up inside the previous curly brace

     # Clean up dot added at beginning of word
     $current_item =~ s/^\.//;

     ############################################################################
     #                                                                          #
     #                     HACK: SYSTEMATIC AD HOC FIXES                        #
     #                                                                          #
     ############################################################################
     $current_item =~ s/s\.s/\.s/g;             # "es.sen.sja" > "e.sen.sja" (?)        #

     # TRYING TO FIX IN 390
     $current_item =~ s/ej\.s$/ejs/g;           # "seis": makes it one syllable                # FIXME!!!
     $current_item =~ s/(^|f)ʧ\.n/ʧn/g;         # "Schneider": makes it /ʧnei̯.ˈdeɾ/, NOT /ʧ.nei̯.ˈdeɾ/ #
                                                #  at BEGINNING OF WORD, or AFTER f ("Reifschneider")   #
     $current_item =~ s/ɾ\.ts/ɾts/g;            # "Schwartz": rt.s > rts                                #
     # NEW IN 101
     $current_item =~ s/ɾ\.tn/ɾt.n/g;            # "partner": par.tner > part.ner                       #
     $current_item =~ s/pan\.ks/panks/g;         # "punks": pan.ks > panks                              #


     ###############################################################################
     #              CLEAN UP WORDS IN THEIR SEMI-PHONEMIC REPRESENTATION           # zzzzz
     ###############################################################################
     # Here, words are in an intermediate representation:                          #
     #  · syllable division dots ARE present                                       #
     #  · stress accents are represented with TILDES, not apostrophes              #
     #  · multi-character symbols (e.g. "t̪", "t̠͡ʃ") have NOT been inserted.      #
     ###############################################################################
     if ( $preclean_semiphonemic == 1 ) {

          #print STDOUT "\t$current_item"; # DEBUG

          #################################################################################
          #                                                                               #
          # FIX SYSTEMATIC SYLLABIFICATION ERRORS                                         #
          #                                                                               #
          # The regular expressions here are semi-phonemic. To change incorrect Perkins   #
          # output to strings that can be processed here, remove the accent apostrophes   #
          # and put a tilde on the corresponding vowel.                                   #
          #                                                                               #
          # Note that many of these rules could probably be made unnecessary by fine-     #
          # tuning the main syllabification routine's regexes.                            #
          #################################################################################

          # [s.t#] > [st#] ("test" = tes.t > test)                                   #
          $current_item =~ s/s\.t$/st/g;

          # WARNING Killed in 309
          #               # [s.ts] > [st.s] ("bestseller")                                            #
          #               $current_item =~ s/s\.ts/st\.s/g;

          # WARNING Killed in 309
          #               # [n.ts#] > [nts#] (es.prin.ts > es.prints)                                #
          #               # WARNING WARNING Added in 3-0-8. Watch for regressions                    #
          #               $current_item =~ s/n\.ts$/nts/g;

          # WARNING Added in 309
          # Remove syllable break before word-final [ts]                             #
          # (ou.ts > outs, ko.pi.raj.ts > ko.pi.rajts)                               #
          $current_item =~ s/\.ts$/ts/g;

          # [.nt#] > [nt#]                                                           #
          $current_item =~ s/\.nt$/nt/g;

          # Fix single consonant being put in its own syllable at end of word        #
          # following /j/ (e.g. mei.l > meil, es.kai.p > es.kaip                     #
          $current_item =~ s/j\.($all_consonants)$/j$1/g;

          # Fix syllabification in C + C at end of word (e.g. fór.sep.s > fór.seps,  #
          # or.g > org)                                                              #
          # WARNING WARNING Watch for regressions. This could be a bomb! WARNING WARNING
          $current_item =~ s/$all_consonants\.$all_consonants$/$1$2/g;    # NOTE Added "g" in "/g;" in 2-9-1

          # [j.lt] > [jl.t] (e.g. "mailto": mai.ltu > meil.tu)                       #
          $current_item =~ s/j\.lt/jl.t/g;

          # Fix "-áis" and "-éis"                                                    #
          $current_item =~ s/([áé])\.is$/$1is/g;

          # Fix English-derived affix "-ter(s)"                                      #
          $current_item =~ s/é\.i\.teɾ/éj\.teɾ/g;

          # Change n.tx to nt.x (ro.en.txen > ro.ent.xen)                            #
          $current_item =~ s/ro\.én\.txen/ro.ént.xen/g;

          # Change é.i to éj (ne.i.si.ko > nej.si.ko)                                #
          # WARNING WARNING WARNING - NEW in 3-0-8 - COULD BE A BOMB ! DANGER DANGER #
          $current_item =~ s/é\.i/éj/g;    # DANGER DANGER DANGER DANGER

          # Change á.i to áj ("iceberg" > a.'is.berg > ajs.berg)                     #
          # WARNING WARNING WARNING - NEW in 3-0-8 - COULD BE A BOMB ! DANGER DANGER #
          $current_item =~ s/á\.i/áj/g;    # DANGER DANGER DANGER DANGER

          # Change á.u to áu ("táutoro" > ta.u.to.ro > táu.to.ro                     #
          # WARNING WARNING WARNING - NEW in 3-0-8 - COULD BE A BOMB ! DANGER DANGER #
          $current_item =~ s/á\.u/áw/g;    # DANGER DANGER DANGER DANGER

          # w.rs > wr.s                                                              #
          # ( awt.'sow.r.ses > awt.'sowr.ses )                                       #
          # WARNING Added in 309                                                     #
          $current_item =~ s/w\.ɾ\.s/wɾ\.s/g;

          # Remove syllable break in ɾ.[df]s at end of word                          #
          # skateboard: boɾ.ds > boɾds, sur.fs > surfs                               #
          # WARNING Added in 309                                                     #
          $current_item =~ s/ɾ\.(d|f)s$/ɾ$1s/g;

          # Remove syllable break in w.ɾs, j.ɾs                                      #
          # amateurs: tew.ɾs > tewɾs, hardwares:ˈxaɾ.dwej.ɾs > ˈxaɾ.dwejɾs           #
          # WARNING Added in 311                                                     #
          $current_item =~ s/([jw])\.ɾs$/$1ɾs/g;

          # st.j > s.tj                                                              #
          # (crist.jan > cris.tjan, best.ja > bes.tja                                #
          # WARNING Added in 312                                                     #
          $current_item =~ s/st\.j/s\.tj/g;

          # j.ds > jds                                                               #
          # (upgrades = 'ap.grejds, not 'ap.gred.ds                                  #
          # WARNING Added in 315                                                     #
          $current_item =~ s/j\.ds/jds/g;

          ############################################################################
          #                                                                          #
          #       FIX ACCENTUATION IN MISC WORDS (SEMI-PHONEMIC REPRESENTATION)      #
          #                                                                          #
          ############################################################################
          $current_item =~ s/ʂaj\.pód/ʂáj.pod/g;
          $current_item =~ s/ajs\.béɾg/ájs\.beɾg/g;
          $current_item =~ s/als\.xé\.i\.meɾ/als.xéj.meɾ/g;
          $current_item =~ s/a\.má\.tewɾs/a\.ma\.téwɾs/g;
          $current_item =~ s/ang\.sʂóm/ángs.ʂom/g;
          $current_item =~ s/a\.nó\.ɾaks/a\.no\.ɾáks/g;
          $current_item =~ s/á\.ut\.put/áwt.put/g;
          $current_item =~ s/á\.ut\.soɾ\.sin/áwt.soɾ.sin/g;
          $current_item =~ s/aw\.tós\.tops/áw\.tos.tops/g;
          $current_item =~ s/bís\.teks/bis\.téks/g;
          $current_item =~ s/blógs\.pot/blóg.spot/g;
          $current_item =~ s/bɾown\.já\.no/bɾow\.njá\.no/g;
          $current_item =~ s/bul\.do\.séɾ/búl\.do\.seɾ/g;
          $current_item =~ s/dí\.ʤejs/di\.ʤéjs/g;
          $current_item =~ s/e\.lek\.ʂó.ʧoks/e\.lek\.ʂo.ʧóks/g;
          $current_item =~ s/és\.pɾints/es.pɾínts/g;
          $current_item =~ s/és\.tafs/es.táfs/g;
          $current_item =~ s/és\.tans/es.táns/g;
          $current_item =~ s/fa\.jéɾ\.foks/fá\.jeɾ\.foks/g;
          $current_item =~ s/fejs\.búk/féjs.buk/g;
          $current_item =~ s/je\.me\.de\.bé/i.e.me.de.ˈbe/g;
          $current_item =~ s/kɾajg\.slíst/kɾéigs.list/g;
          $current_item =~ s/laj\.bʤóɾ\.nal/lajb\.ʤóɾ\.nal/g;
          $current_item =~ s/laj\.bxow\.ɾ\.nál/lajb.ʤóɾ.nal/g;
          $current_item =~ s/maj\.kɾo\.sóf/máj.kɾo.sof/g;
          $current_item =~ s/maj\.kɾó\.sofs/máj.kɾo.sofs/g;
          $current_item =~ s/májs\.pes/máj.spes/g;
          $current_item =~ s/of\.sét/óf.set/g;
          $current_item =~ s/pej\.pál/péj.pal/g;
          $current_item =~ s/poɾt\.lánd/póɾt.land/g;
          $current_item =~ s/ti\.két/tí.ket/g;
          $current_item =~ s/tung\.sté\.no/tungs.té.no/g;
          $current_item =~ s/we\.ɾe\.é\.le/u.e.re.é.le/g;

          # WARNING Added in 320
          $current_item =~ s/pɾoj\.b/pɾo.i.b/g;        # "prohíben", "prohibímos", etc. (accent NOT on 1st syl)
          $current_item =~ s/pɾój\.be/pɾo.í.be/g;    # "prohíben", "prohibímos", etc. (accent on 1st syl)
          $current_item =~ s/pɾój\.ba/pɾo.í.ba/g;    # "prohíban", "prohibamos", etc. (accent on 1st syl)

          # WARNING Added in 396
          $current_item =~ s/j\.l\.t/jl\.t/g;            # "mailto": mej.l.tu > mejl.tu

          #PLACEHOLDER 3

          if ( $debug_syllab_sub == 1 ) {
               print STDOUT "\tfinal in sub = $current_item";    # NOTE DEBUG
          }

          return ($current_item);

     }
}    # END OF SYLLABIFICATION SUBROUTINE

#################################################################################
#                                ==OPTIONAL==                                   #
# SUBROUTINE: CONVERT VOWELS WITH TILDES INTO NORMAL VOWELS WITH IPA STRESS     #
#             ACCENT APOSTROPHES AT THE BEGINNING OF THEIR SYLLABLE             #
#                             ( es.tá > es.'ta )                                #
#################################################################################
sub opt_tildes_to_ipa_apostrophes {

     my $current_item = $_[0];

     @syllable = split /\./, $current_item;

     $syl_count = @syllable;

     for ( $i = 0 ; $i < $syl_count ; $i++ ) {

          if ( $syllable[$i] =~ m/$stressed_vowels/ ) {
               $syllable[$i] =~ s/á/a/;
               $syllable[$i] =~ s/é/e/;
               $syllable[$i] =~ s/í/i/;
               $syllable[$i] =~ s/ó/o/;
               $syllable[$i] =~ s/ú/u/;
               $syllable[$i] = "ˈ$syllable[$i]";    # This is the IPA stress accent apostrophe!
          }
     }
     $current_item = join( ".", @syllable );
     return ($current_item);
}

#################################################################################
# SUBROUTINE: USE MULTI-CHARACTER PHONEME SYMBOLS                               #
#                        ( ʧ > t̠͡ʃ,   ʤ > d̠͡ʒ,  etc. )                        #
#################################################################################
#################################################################################
# SUBROUTINE: USE MULTI-CHARACTER PHONEME SYMBOLS                               #
#                                                                               #
# CHANGED IN 103: Now has options to let $use_one_char_ch_symbol and             #
#                 $use_one_char_ye_symbol override all other /ʧ/ and /ʤ/-related #
#                 options.
#                        ( ʧ > t̠͡ʃ,   ʤ > d̠͡ʒ,  etc. )                           #
#################################################################################
sub opt_use_multichars {

     my $current_item = $_[0];

     if ( $use_dental_diacr == 1 ) {
          $current_item =~ s/t/t̪/g;
          $current_item =~ s/d/d̪/g;
     }

     if ( $tr_is_group == 1 ) {

          # WARNING: Changed in 0431: Added dental diacritic to t
          #$current_item =~ s/ʂ/t͡ɾ/g;

          if ( $use_dental_diacr == 1 ) {
               $current_item =~ s/ʂ/t̪͡ɾ/g;
          }
          else {
               $current_item =~ s/ʂ/t͡ɾ/g;
          }
     }
     elsif ( $tr_is_group == 0 ) {

          # WARNING: Changed in 0431: Added dental diacritic to t
          #$current_item =~ s/ʂ/tɾ/g;

          if ( $use_dental_diacr == 1 ) {
               $current_item =~ s/ʂ/t̪ɾ/g;
          }
          else {
               $current_item =~ s/ʂ/tɾ/g;
          }
     }

	# WARNING: The following was changed in 103. All the "&&..." statements are new, as are a few others.

	# Process /ʧ/
     if ( $ch_dzh_retracted == 1 && $use_one_char_ch_symbol == 0 ) {
          if ( $use_ligatures == 1 ) {
               $current_item =~ s/ʧ/t̠͡ʃ/g;
               }
          else {
			if ( $use_one_char_ch_symbol == 0 ) {
               $current_item =~ s/ʧ/t̠ʃ/g;
               }
          }
     }
     else {
          if ( $use_ligatures == 1 && $use_one_char_ch_symbol == 0 ) {
               $current_item =~ s/ʧ/t͡ʃ/g;
          }
          else {
			if ( $use_one_char_ch_symbol == 0 ) {
               $current_item =~ s/ʧ/tʃ/g;
               }
          }
     }


	# Process /ʤ/
	if ( $ch_dzh_retracted == 1 && $use_one_char_ye_symbol == 0 ) {
          if ( $use_ligatures == 1 ) {
               $current_item =~ s/ʤ/d̠͡ʒ/g;
               }
          else {
			if ( $use_one_char_ye_symbol == 0 ) {
               $current_item =~ s/ʤ/d̠ʒ/g;
               }
          }
     }
     else {
          if ( $use_ligatures == 1 && $use_one_char_ye_symbol == 0 ) {
               $current_item =~ s/ʤ/d͡ʒ/g;
          }
          else {
			if ( $use_one_char_ye_symbol == 0 ) {
               $current_item =~ s/ʤ/dʒ/g;
               }
          }
     }

return ($current_item);

}

############################################################################
# SUBROUTINE: OPTIONAL PHONEME TRANSFORMATIONS                             #
############################################################################
sub opt_phoneme_transforms {

     my $current_item = $_[0];

     ############################################################################
     # CHANGE /ʂ/ TO /tɾ/ IF NO MULTI-CHARS AND TR IS NOT GROUP                 #
     # NOTE NEW IN 351                                                          #
     ############################################################################
     if ( ( $multichars == 0 ) && ( $tr_is_group == 0 ) ) {
          $current_item =~ s/ʂ/tɾ/g;
     }

     ############################################################################
     # REPRESENT NON-SYLLABIC U AS VOWEL+DIACRITIC /u̯/, NOT /w/                #
     ############################################################################
     if ( $non_syl_u_with_u_diacr == 1 ) {
          $current_item =~ s/($all_vowels)w/$1u̯/g;
          $current_item =~ s/w($all_vowels)/u̯$1/g;
     }

     ############################################################################
     # REPRESENT NON-SYLLABIC I AS VOWEL+DIACRITIC /i̯/, NOT /j/                #
     ############################################################################
     if ( $non_syl_i_with_i_diacr == 1 ) {
          $current_item =~ s/j($all_vowels)/i̯$1/g;
          $current_item =~ s/($all_vowels)j/$1i̯/g;
     }
     return ($current_item);

}

############################################################################
# SUBROUTINE: IF SELECTED, CONVERT PHONEMES TO C OR V                      #
############################################################################
sub opt_convert_phonemes_cv {

     my $current_item = $_[0];

     if ( $tr_is_group == 0 ) {
          $current_item =~ s/$tr/CC/g;
     }
     else {
          $current_item =~ s/$tr/C/g;
     }

     $current_item =~ s/$vowels_glides/V/g;
     $current_item =~ s/$all_consonants/C/g;
     $current_item =~ s/̪̠͡//g;
     return ($current_item);

}

############################################################################
# SUBROUTINE: IF SELECTED, CONVERT PHONEMES TO C, V OR G                   #
############################################################################
sub opt_convert_phonemes_cvg {

     my $current_item = $_[0];

     if ( $tr_is_group == 0 ) {
          $current_item =~ s/$tr/CC/g;
     }
     else {
          $current_item =~ s/$tr/C/g;
     }

     $current_item =~ s/$glides/G/g;
     $current_item =~ s/$all_vowels/V/g;
     $current_item =~ s/$all_consonants/C/g;
     $current_item =~ s/̪̠͡//g;

     return ($current_item);

}

############################################################################
# SUBROUTINE: IF SELECTED, CONVERT PHONEMES TO C, V, N, L, R OR G          #
############################################################################
sub opt_convert_phonemes_cvnlrg {

     my $current_item = $_[0];

     if ( $tr_is_group == 0 ) {
          $current_item =~ s/$tr/CR/g;
     }
     else {
          $current_item =~ s/$tr/C/g;
     }

     $current_item =~ s/$glides/G/g;
     $current_item =~ s/$nasals/N/g;
     $current_item =~ s/$liquids/L/g;
     $current_item =~ s/$rhotics/R/g;
     $current_item =~ s/$all_vowels/V/g;
     $current_item =~ s/$all_consonants/C/g;
     $current_item =~ s/̪̠͡//g;
     return ($current_item);

}

############################################################################
# SUBROUTINE: IF SELECTED, CONVERT PHONEMES TO MANNERS OF ARTICULATION     #
############################################################################
sub opt_convert_phonemes_manners {

     my $current_item = $_[0];

     if ( $tr_is_group == 0 ) {
          $current_item =~ s/$tr/PT/g;
     }
     else {
          $current_item =~ s/$tr/A/g;
     }

     $current_item =~ s/$plosives/P/g;
     $current_item =~ s/$nasals/N/g;
     $current_item =~ s/$trills/R/g;
     $current_item =~ s/$taps/T/g;
     $current_item =~ s/$fricatives/F/g;
     $current_item =~ s/$laterals/L/g;
     $current_item =~ s/$affricates/A/g;
     $current_item =~ s/$aproximants/X/g;
     $current_item =~ s/$all_vowels/V/g;
     $current_item =~ s/̪̠͡//g;
     return ($current_item);
}

############################################################################
# SUBROUTINE: IF SELECTED, CONVERT PHONEMES TO PLACES OF ARTICULATION      #
############################################################################
sub opt_convert_phonemes_places {

     my $current_item = $_[0];

     if ( $tr_is_group == 0 ) {
          $current_item =~ s/$tr/DA/g;
     }
     else {
          $current_item =~ s/$tr/A/g;
     }

     $current_item =~ s/$bilabials/B/g;
     $current_item =~ s/$labiodentals/L/g;
     $current_item =~ s/$dentals/D/g;
     $current_item =~ s/$alveolars/A/g;
     $current_item =~ s/$postalveolars/T/g;
     $current_item =~ s/$palatals/P/g;
     $current_item =~ s/$velars/V/g;
     $current_item =~ s/$labiovelars/W/g;
     $current_item =~ s/$all_vowels/-/g;
     $current_item =~ s/̪̠͡//g;

     return ($current_item);
}

############################################################################
# SUBROUTINE IF SELECTED, CONVERT PHONEMES TO VOICING                      #
############################################################################
sub opt_convert_phonemes_voicing {

     my $current_item = $_[0];

     if ( $tr_is_group == 0 ) {
          $current_item =~ s/$tr/AS/g;
     }
     else {
          $current_item =~ s/$tr/A/g;
     }

     $current_item =~ s/$voiced/S/g;
     $current_item =~ s/$unvoiced/A/g;
     $current_item =~ s/̪̠͡//g;
     return ($current_item);

}

############################################################################
# SUBROUTINE: IMPLEMENT PUNCTUATION > PAUSES (IPA PAUSE SYMBOLS)           #
############################################################################
sub punct_to_pauses_ipa {

     my $current_item = $_[0];

     # Insert INITIAL BRACKET pause (.) if appropriate

     if ( $add_bracket_pauses == 1 && $initial_bracket_pause == 1 ) {
          $current_item          = "| $current_item";
          $initial_bracket_pause = 0;
     }

     # Insert FINAL BRACKET pause (.) if appropriate

     if ( $add_bracket_pauses == 1 && $final_bracket_pause == 1 ) {
          $current_item        = "$current_item |";
          $final_bracket_pause = 0;
     }

     # Insert INITIAL PAREN pause (.) if appropriate

     if ( $add_paren_pauses == 1 && $initial_paren_pause == 1 ) {
          $current_item        = "| $current_item";
          $initial_paren_pause = 0;
     }

     # Insert FINAL PAREN pause (.) if appropriate

     if ( $add_paren_pauses == 1 && $final_paren_pause == 1 ) {
          $current_item      = "$current_item |";
          $final_paren_pause = 0;
     }

     # Insert ellipsis pause if appropriate
     if ( $add_ellipsis_pauses == 1 && $ellipsis_pause == 1 ) {
          $current_item   = "$current_item ‖";
          $ellipsis_pause = 0;
     }

     # Insert sentence end break if appropriate
     if ( $add_sentence_breaks == 1 && $sentence_break == 1 ) {
          $current_item   = "$current_item ‖";
          $sentence_break = 0;
     }

     # Insert comma pause (.) if appropriate
     if ( $add_comma_pauses == 1 && $comma_pause == 1 ) {
          $current_item = "$current_item |";
          $comma_pause  = 0;
     }

     # Insert semicolon pause (...) if appropriate
     if ( $add_semicolon_pauses == 1 && $semicolon_pause == 1 ) {
          $current_item    = "$current_item ‖";
          $semicolon_pause = 0;
     }

     # Insert colon pause (..) if appropriate
     if ( $add_colon_pauses == 1 && $colon_pause == 1 ) {
          $current_item = "$current_item |";
          $colon_pause  = 0;
     }

     return ($current_item);

}

############################################################################
# SUBROUTINE: IMPLEMENT PUNCTUATION > PAUSES (NON-IPA PAUSE SYMBOLS)       #
############################################################################
sub punct_to_pauses_non_ipa {

     my $current_item = $_[0];

     # Insert INITIAL BRACKET pause (.) if appropriate

     if ( $add_bracket_pauses == 1 && $initial_bracket_pause == 1 ) {
          $current_item          = "\(\.\) $current_item";
          $initial_bracket_pause = 0;
     }

     # Insert FINAL BRACKET pause (.) if appropriate

     if ( $add_bracket_pauses == 1 && $final_bracket_pause == 1 ) {
          $current_item        = "$current_item \(\.\)";
          $final_bracket_pause = 0;
     }

     # Insert  PAREN pause (.) if appropriate

     if ( $add_paren_pauses == 1 && $initial_paren_pause == 1 ) {
          $current_item        = "\(\.\) $current_item";
          $initial_paren_pause = 0;
     }

     # Insert FINAL PAREN pause (.) if appropriate

     if ( $add_paren_pauses == 1 && $final_paren_pause == 1 ) {
          $current_item      = "$current_item \(\.\)";
          $final_paren_pause = 0;
     }

     # Insert ellipsis pause if appropriate
     if ( $add_ellipsis_pauses == 1 && $ellipsis_pause == 1 ) {
          $current_item   = "$current_item \(\.\.\.\)";
          $ellipsis_pause = 0;
     }

     # Insert sentence end break if appropriate
     if ( $add_sentence_breaks == 1 && $sentence_break == 1 ) {
          $current_item   = "$current_item ##";
          $sentence_break = 0;
     }

     # Insert comma pause (.) if appropriate
     if ( $add_comma_pauses == 1 && $comma_pause == 1 ) {
          $current_item = "$current_item \(\.\)";
          $comma_pause  = 0;
     }

     # Insert semicolon pause (...) if appropriate
     if ( $add_semicolon_pauses == 1 && $semicolon_pause == 1 ) {
          $current_item    = "$current_item \(\.\.\.\)";
          $semicolon_pause = 0;
     }

     # Insert colon pause (..) if appropriate
     if ( $add_colon_pauses == 1 && $colon_pause == 1 ) {
          $current_item = "$current_item \(\.\.\)";
          $colon_pause  = 0;
     }

     return ($current_item);

}

############################################################################
# SUBROUTINE: SPLIT AT SYLLABLES: PUT A NEWLINE AT EACH SYLLABLE BOUNDARY  #
#             IF DESIRED                                                   #
############################################################################
sub opt_split_at_syllables {

     my $current_item = $_[0];

     # NEW in 373: Changed \n to \r\n in replace expression. Otherwise, the     #
     #             newline gets eaten (possibly by the clean-up routine)        #
     $current_item =~ s/\./\r\n/g;
     $current_item =~ s/ /\r\n/g;

     $current_item =~ s/#//g;
     $current_item =~ s/\(//g;
     $current_item =~ s/\)//g;

     # Remove double newlines
     $current_item =~ s/\n\n/\n/g;

     return ($current_item);

}

############################################################################
#                                                                          #
# SUBROUTINE: REPLACE .VRT PLACEHOLDERS                                    #
#                                                                          #
############################################################################
sub replace_vrt_placeholders {

     my $current_item = $_[0];

     $temp = Encode::encode_utf8($current_item);    # AD-HOC DEBUG
                                                    #print STDOUT "VRT-ELIMIN-PLCHLD-BEF:$current_item:\n";    # AD-HOC DEBUG

     # Placeholders to replace with other things
     # WARNING: Changed in 415: Mostly blanks are inserted now.
     $current_item =~ s/þ//g;                      # Period
     $current_item =~ s/¢//g;                      # Comma
     $current_item =~ s/ĸ//g;                      # Colon
     $current_item =~ s/ð//g;                      # Dash
     $current_item =~ s/ł//g;                      # Quotation mark
     $current_item =~ s/ŋ//g;                      # Opening question mark
     $current_item =~ s/µµ//g;                    # Paragraph marker
     $current_item =~ s/µ//g;                      # Sentence marker
     $current_item =~ s/ø/ /g;
     $current_item =~ s/½/ /g;

     # THESE WERE THE SETTINGS UNTIL 415
     #$current_item =~ s/þ/./g;                     # Period
     #$current_item =~ s/¢/,/g;                     # Comma
     #$current_item =~ s/ĸ/:/g;                     # Colon
     #$current_item =~ s/ð/-/g;                     # Dash
     #$current_item =~ s/ł/"/g;                     # Quotation mark
     #$current_item =~ s/ŋ/¿/g;                    # Opening question mark
     #$current_item =~ s/µµ/<p>/g;                 # Paragraph marker
     #$current_item =~ s/µ/<s>/g;                   # Sentence marker
     #$current_item =~ s/ø/ /g;
     #$current_item =~ s/½/ /g;

     # Placeholders to kill #NEW IN 402
     $current_item =~ s/ø$//g;
     $current_item =~ s/^ø//g;

     # Kill leading or trailing spaces that may crop up
     $current_item =~ s/^ //g;
     $current_item =~ s/ $//g;

     $temp = Encode::encode_utf8($current_item);    # AD-HOC DEBUG
                                                    #print STDOUT "VRT-ELIMIN-PLCHLD-AFT:$current_item:\n";    # AD-HOC DEBUG

     return ($current_item);
}    # END OF SUBROUTINE: REPLACE .VRT PLACEHOLDERS

#################################################################################
#                        SUBROUTINE: Clean up pauses                            #
#################################################################################
sub clean_up_pauses {

     my $current_item = $_[0];

     # Merge a period break followed by a paragraph break.                 #
     $current_item =~ s/## ###/###/g;

     # Merge a final bracket or comma break followed by a paragraph break. #
     $current_item =~ s/\(\.\) ###/###/g;

     # Merge a final bracket or comma break followed by a paragraph break. #
     $current_item =~ s/###$/\n/g;

     # Merge an IPA MINOR group and MAJOR group when the occur together,   #
     # leaving only the major group symbol.                                #
     $current_item =~ s/\| ‖/‖/g;

     # Merge an IPA MAJOR group and MINOR group when the occur together,   #
     # leaving only the major group symbol.                                #
     $current_item =~ s/‖ \|/‖/g;

     # Merge two IPA minor groups when the occur together.                 #
     $current_item =~ s/\| \|/\|/g;

     # Eliminate IPA major group symbol at end of line                     #
     $current_item =~ s/ ‖ $//g;

     # Eliminate IPA minor group symbol at end of line                     #
     $current_item =~ s/ \| $//g;

     # Eliminate whitespace at END of line.                                #
     # Note that at least one whitespace character must remain, or else    #
     # all lines are merged into one.                                      #
     $current_item =~ s/\s(\s)+$/$1/g;

     # Eliminate SPACES (but NOT other whitespace) at BEGINNING of line    #
     $current_item =~ s/^( )+//g;

     # print "\n>>>$input_line<<<";     # DEBUG


     # Replace IPA long pause double bar with two IPA short pause single bars
     # NEW in 0456
     if ( $ipa_long_pause_two_singles == 1 ) {
          $current_item =~ s/‖/||/g;
     }

     return ($current_item);

}    # END SUB: CLEAN UP PAUSES

#################################################################################
#    SUBROUTINE: PERFORM WORD-LEVEL SYLLABIFICATION ADJUSMENTS, IF DESIRED      #
#################################################################################
sub word_level_syllab_adjust {

     my $current_item = $_[0];

     $current_item =~ s/($all_consonants_diacr){1,1}( )(ˈ|'|)($all_vowels_diacr)/.$4$1$5/g;

     # Convert spaces to syllable dots                                #

     # NOTE: NEW IN 379 [DISABLED FOR TESTING]
     #$current_item =~ s/([^ˈ'|‖]) ([^|‖])/$1.$2/g;

     # NOTE: NEW IN 380 [TESTING] ñññññ
     $current_item =~ s/([^‖|]) ([^|‖])/$1.$2/g;
     $current_item =~ s/([^‖|]) ([^|‖])/$1.$2/g;

     #print STDOUT "\t > $input_line"; # AD HOC DEBUG

     return ($current_item);
}    # END SUBROUTINE: PERFORM WORD-LEVEL SYLLABIFICATION ADJUSTMENTS

###############################################################################
#                     SUBROUTINE: PRINT INFO HEADER                           #
###############################################################################
sub print_info_header {

     binmode STDOUT, ":utf8";

     if ( $lang eq "es" ) {

          print STDOUT "\n+-----------------------------------------------------------------------+";
          print STDOUT "\n|                          Perkins v$version                               |";
          print STDOUT "\n|            Tu suche para el trabajo sucio de la fonética...           |";
          print STDOUT "\n|                   Copyright (c) 2016 Scott Sadowsky                   |";
          print STDOUT "\n|           http://sadowsky.cl - ssadowsky arro ba gma il pu nto com    |";
          print STDOUT "\n|                                                                       |";
          print STDOUT "\n| Este programa se distribuye bajo la licencia GNU AGPL v3. Se          |";
          print STDOUT "\n| distribuye SIN GARANTÍA ALGUNA. Véase LICENSE.txt para más detalles.  |";
          print STDOUT "\n|                                                                       |";
          print STDOUT "\n| PROBLEMA CONOCIDO: En todos los modos menos el fonémico, la           |";
          print STDOUT "\n|                    silabización se realiza siempre a nivel de palabra.|";

          print STDOUT "\n|-----------------------------------------------------------------------|";
          print STDOUT "\n| PARA EJECUTARLO: $progname [OPCIONES] -i=input.txt [-o=output.txt] |";
          print STDOUT "\n| AYUDA:           $progname -h                                      |";
          print STDOUT "\n| INFO SOBRE USO:  $progname -u                                      |";
          print STDOUT "\n| USE IN ENGLISH:  $progname -en -i=input.txt [OPCIONES]             |";
          print STDOUT "\n|                                                                       |";
          print STDOUT "\n| (Si usas el binario de GNU/Linux, reemplaza \'.pl\' por \'.bin\').        |";
          print STDOUT "\n|                                                                       |";
          print STDOUT "\n| - El archivo a procesar DEBE ser texto plano codificado en ISO-8859-1 |";
          print STDOUT "\n| - El archivo de salida será texto en UTF-8 (Unicode)                  |";
          print STDOUT "\n| - Se puede configurar Perkins mediante las opciones de la línea de    |";
          print STDOUT "\n|   comandos, o bien editando el archivo de configuración (perkins.ini) |";
     }
     else {

          print STDOUT "\n+-----------------------------------------------------------------------+";
          print STDOUT "\n|                           Perkins v$version                              |";
          print STDOUT "\n|                      The Phonetician's Assistant...                   |";
          print STDOUT "\n|                   Copyright (c) 2016 Scott Sadowsky                   |";
          print STDOUT "\n|           http://sadowsky.cl - ssadowsky a t gma il d ot com          |";
          print STDOUT "\n|                                                                       |";
          print STDOUT "\n| This program is free software distributed under the GNU AGPL v3. It   |";
          print STDOUT "\n| comes with ABSOLUTELY NO WARRANTY. See LICENSE.txt for details.       |";
          print STDOUT "\n|                                                                       |";
          print STDOUT "\n| KNOWN ISSUE: In all modes but phonemic, syllabification is            |";
          print STDOUT "\n|              always performed at word level.                          |";

          print STDOUT "\n|-----------------------------------------------------------------------|";
          print STDOUT "\n| TO RUN PERKINS:  $progname [OPTIONS] -i=input.txt [-o=output.txt]  |";
          print STDOUT "\n| FOR HELP:        $progname -h                                      |";
          print STDOUT "\n| USAGE INFO:      $progname -u                                      |";
          print STDOUT "\n| USAR EN ESPAÑOL: $progname -es -i=input.txt [OPTIONS]              |";
          print STDOUT "\n|                                                                       |";
          print STDOUT "\n| (If you're using the GNU/Linux binary, replace \'.pl\' with \'.bin\').    |";
          print STDOUT "\n|                                                                       |";
          print STDOUT "\n| - The file to be processed MUST be plain text encoded in ISO-8859-1   |";
          print STDOUT "\n| - The output file will be encoded in UTF-8 (Unicode).                 |";
          print STDOUT "\n| - Perkins can be configured with command-line options, or by editing  |";
          print STDOUT "\n|   the configuration file (perkins.ini)                                |";

     }
     if ( $^O eq "MSWin32" ) {

          if ( $lang eq "es" ) {
               print STDOUT "\n|                                                                       |";
               print STDOUT "\n| NOTA: Debido a que el terminal de Windows (cmd.exe) no es capaz de    |";
               print STDOUT "\n|       mostrar caracteres Unicode, la ayuda y la información sobre el  |";
               print STDOUT "\n|       uso no se muestran correctamente. Sin embargo, LOS ARCHIVOS DE  |";
               print STDOUT "\n|       QUE PRODUCE PERKINS *NO* SE VEN AFECTADOS POR ESTA SITUACIÓN.   |";
          }
          else {

               print STDOUT "\n|                                                                       |";
               print STDOUT "\n| NOTE: Because the Windows command line (cmd.exe) cannot correctly     |";
               print STDOUT "\n|       show Unicode characters, help and usage information will not    |";
               print STDOUT "\n|       be shown correctly here. However, PERKINS' OUTPUT IS IN NO WAY  |";
               print STDOUT "\n|       AFFECTED BY THIS.                                               |";

          }
     }
     print STDOUT "\n+-----------------------------------------------------------------------+\n";
     print STDOUT "\n";
}

#################################################################################
# SUBROUTINE: Assign language strings                                           #
#################################################################################

sub assign_lang_str {

}

#################################################################################
#                                                                               #
#                                  CHANGELOG                                    #
#                                                                               #
# 0.411 (AKA 411)                                                               #
# *  "Print input line to debug log file, if desired": added if statement to    #
#    only do this if user actually wants to debug to log file.                  #
# *  Renumbered syllabification rules.                                          #
#                                                                               #
# 0.415 (AKA 415)                                                               #
# *  Changed "Process fractions (numbers to right of decimal point)" in both    #
#    the VRT and non-VRT sections, removing the ">" from "(>,)(\d+)". This was  #
#    keeping numbers following commas at the start of a line (e.g. ",001") from #
#    being processed. This might cause regressions, though!                     #
#                                                                               #
# 0.416 (AKA 416)                                                               #
# *  Now processes negative numbers (ONLY in VRT format).                       #
#                                                                               #
# 0.418 (AKA 418)                                                               #
# *  Now processes date ranges (e.g. 1990-2000) as such, rather than as         #
#    equations.                                                                 #
#                                                                               #
# 0.434                                                                         #
# *  Begin adding multi-language support for all program messages               #
#                                                                               #
# 0.435                                                                         #
# *  Localized help and most messages into English.                             #
#                                                                               #
# 0.451                                                                         #
# *  Added Coscach meta-configuration                                           #
# *  Added "marketing" and a few other words to exceptions list.                #
#                                                                               #
# 0.452                                                                         #
# *  Added -lig and -dent switches, and corresponding transcription code.       #
#                                                                               #
# 0.456                                                                         #
# *  Added option to transcribe IPA long pauses as two short bars rather        #
#    than one long (double) bar, as the double bar doesn't display in Praat.    #
#                                                                               #
# 0.459                                                                         #
# *  Added exception for "Evelyn"                                               #
#                                                                               #
# 0.462                                                                         #
# *  Added option to NOT add epenthetic [g] in words like "huevo" [gwebo].      #
#    -aeg|-age add the [g]; -noaeg|-noage do not add it.                        #
#                                                                               #
# 1.0.0                                                                         #
# *  First public release of source code. Now under GNU License                 #
#
# 1.0.1 to 1.0.3
# *  Sadly, didn't document the changes.
#
# 1.0.4
# *  Multiple identical unaccented vowels (e.g. "aa", "aaa", "aaaa" are now     #
#    reduced to a single vowel. Need to watch for regressions on this in two    #
#    areas, at least: (1) Handling of diphthongs, and (2) handling of special   #
#    case words (typically foreign ones, such as "Wood").                       #
# *  Added the "-och" and "-oye" options, which allow you to force the use of   #
#    the single character /ʧ/ and /ʤ/ symbols no matter what other options are  #
#    chosen. Previously, these were linked to the -nomc (no multiple characters)#
#    option, which would not let you have /ʧ/ plus dentals with diacritics.     #
# *  Added a series of additional lexical exceptions to deal with specific items#
#    such as "sd", "xd", "tour", etc.                                           #
# *  Updated the online help to reflect the above options, as well as to high-  #
#    light the -nosd (no syllable dots) option, which even *I* couldn't find!   #
#                                                                               #
# 1.0.5                                                                         #
# * Fixed a long-standing bug that was probably implemented as a way            #
#   to properly process incorrectly written but unambiguous words, such as      #
#   "samurai" (which SHOULD be transcribed as /sa.'mu.ray/, or written as       #
#   "samurái"). This affects maybe 0.00001% of non-Chilean Spanish words, but   #
#   lays waste to many Chilean voseo conjugations -- any that end in ortho "i"! #
#   (e.g. "estabai" becomes /es.ta.'baj/, "hubierai" is /u.bje.'raj/, etc.      #
# * Changed license to the GNU Affero GPL v3.                                   #
#                                                                               #
#################################################################################

#################################################################################
#                                                                               #
#                                  TODO LIST                                    #
#                                                                               #
# TODO: Seems all the cover term transformations (>CV, CVG, etc.) are not       #
#       affected by the option to syllabify at sentence level!! Thus, while     #
#       "los hombres" is phonemically transcribed as "lo.som.bres", the same    #
#       phrase as CV is incorrectly given as "CVC.VC.CCVC"!!!.   MUST FIX!!!    #
#                                                                               #
# TODO: Add the ability to chunk utterances (thus producing one utterance per   #
#       line). The easiest way to go about this may be to open the input file,  #
#       chunk it, close it, and then sic Perkins on it as before. For           #
#       CC-Unified IMS-based corpus.                                            #
#                                                                               #
# TODO: Give Perkins the ability to perform multiple types (formats) of         #
#       transcriptions in a single pass. For purposes of the CC-Unified IMS-    #
#       based corpus, the first implementation should tack each successive      #
#       transcription format on to the end of the previous one, using \t as a   #
#       separator. In the future, multiple output files may also be an option.  #
#                                                                               #
# TODO: Review and update usage section examples. Change most of them to        #
#       phrase-level transcriptions, rather than word-level ones.               #
#                                                                               #
# TODO: Figure out why "tr" is transcribed WITHOUT the dental diacritic. Was    #
#       this intentional?                                                       #
#       0433: I think I fixed this.                                             #
#################################################################################
