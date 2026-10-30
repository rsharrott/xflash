# encoding: utf-8
############################################
#  CTEDI (CEDICT Importer)
#         --- Options file ---
############################################

# Options/Defaults
$options = {}
$options[:default_break_point] = 0
$options[:verbose] = true
$options[:force_utf8] = false
$options[:cache_fu_on] = false
$options[:maximum_cards_per_tag] = 10000

# mysql DB Options
$options[:mysql_name] = "cflash_import"
$options[:mysql_port] = 3306
$options[:mysql_host] = "localhost"
$options[:mysql_username] ="root"
$options[:mysql_password] = ""

# sqlite DB Options
$options[:sqlite_bin] = "/usr/local/bin/sqlite3"
$options[:sqlite_name] = "cflash"
$options[:sqlite_username] ="root"
$options[:sqlite_password] = ""
$options[:sqlite_file_path] = {}
# Historical 2011 importer output names. The app ships the 2.0 databases
# written by tools/dictbuild_zh; these paths are only for this old script.
$options[:sqlite_file_path][:jflash_user]  = "./cFlash.db"
$options[:sqlite_file_path][:jflash_cards] = "./cFlash-CARD-1.0.db"
$options[:sqlite_file_path][:jflash_ex]    = "./cFlash-EX-1.0.db"
$options[:sqlite_file_path][:jflash_fts]   = "./cFlash-FTS-1.0.db"
$options[:sqlite_file_path][:jflash_rikai] = "./cFlash-rikai-1.0.db"
$options[:data_file_rel_path] = "./data/cedict"

# $options[:card_types] = {
#   'WORD' => 0,
#   'KANA' => 1,
#   'KANJI' => 2,
#   'DICTIONARY' => 3,
#   'SENTENCE' => 4
# }

# $options[:tanc_keyword_idx_types] = {
#   'INDEX_WORD' => 0,
#   'SENTENCE_WORD' => 1,
#   'READING' => 2
# }
# 
# # System Tag IDs
# $options[:system_tags] = { 
#   'LWE_FAVORITES' => 124
# }

$options[:likeness_level] = {
  :exact_match => 1,
  :partial_match => 2,
  :one_likeness_match => 3
}

# Global shared object cache (e.g. for pos tag data or similar 'get once' data)
$shared_cache = {}
$cards_entries = {}

# Global Registers (Instance Vars)
$options[:mysql_time_format] = "'%Y-%m-%d %H:%M:%S'"

# This array is for Chinese-specific-tones 
# Reading Chatacter - Diacritic
$chinese_reading_unicode = {}
# a tones - variant
$chinese_reading_unicode[:a1] = 257
$chinese_reading_unicode[:a2] = 225
$chinese_reading_unicode[:a3] = 462
$chinese_reading_unicode[:a3_angle] = 462
$chinese_reading_unicode[:a3_round] = 259
$chinese_reading_unicode[:a4] = 224
$chinese_reading_unicode[:a5] = 97
# i tones - variant
$chinese_reading_unicode[:i1] = 299
$chinese_reading_unicode[:i2] = 237
$chinese_reading_unicode[:i3] = 464
$chinese_reading_unicode[:i3_angle] = 464
$chinese_reading_unicode[:i3_round] = 301
$chinese_reading_unicode[:i4] = 236
$chinese_reading_unicode[:i5] = 105
# u tones - variant
$chinese_reading_unicode[:u1] = 363
$chinese_reading_unicode[:u2] = 250
$chinese_reading_unicode[:u3] = 468
$chinese_reading_unicode[:u3_angle] = 468
$chinese_reading_unicode[:u3_round] = 365
$chinese_reading_unicode[:u4] = 249
$chinese_reading_unicode[:u5] = 117
# e tones - variant
$chinese_reading_unicode[:e1] = 275
$chinese_reading_unicode[:e2] = 233
$chinese_reading_unicode[:e3] = 283
$chinese_reading_unicode[:e3_angle] = 283
$chinese_reading_unicode[:e3_round] = 277
$chinese_reading_unicode[:e4] = 232
$chinese_reading_unicode[:e5] = 101
# o tones - variant
$chinese_reading_unicode[:o1] = 333
$chinese_reading_unicode[:o2] = 243
$chinese_reading_unicode[:o3] = 466
$chinese_reading_unicode[:o3_angle] = 466
$chinese_reading_unicode[:o3_round] = 335
$chinese_reading_unicode[:o4] = 242
$chinese_reading_unicode[:o5] = 111
# ü tones - variant
$chinese_reading_unicode[:v1] = 470
$chinese_reading_unicode[:v2] = 472
$chinese_reading_unicode[:v3] = 474
$chinese_reading_unicode[:v3_angle] = 474
#TODO: How about the ü character with the rounded-3-point-tone?
$chinese_reading_unicode[:v3_round] = 474
$chinese_reading_unicode[:v4] = 476
$chinese_reading_unicode[:v5] = 252

# Regex Definitions
$regexes = {}

# CFLASH REGEXES
$regexes[:vocal] = /[aiueoü]/
$regexes[:diacritic_vowel1] = /[ae]/
$regexes[:diacritic_vowel2] = /ou/
$regexes[:diacritic_vowel3] = /[aiueoü]/
$regexes[:chinese_reading] = /[A-Za-zü:]*[1-5]{1}/

$regexes[:pinyin_tone] = /^[0-5]{1}/
$regexes[:pinyin_tone_without_normal] = /^[0-4]{1,}/
$regexes[:pinyin_separator] = /^[,·]/
$regexes[:single_letter] = /^[A-Za-z]{1}/
$regexes[:inlined_tags] = /\(([^\)]*)\)$/

$regexes[:diff_info] = /^\d+(,{1}\d+)?[a|c|d]\d+(,{1}\d+)?$/


# OLD JFLASH REGEXES
# $regexes[:number_marker] = /\(\d?\d?\)\s{1}/
# $regexes[:inside_hard_brackets] = /\[(\S+)\]/
# $regexes[:inside_parens] = /\((\S+)\)/
# $regexes[:inside_braces] = /\{(\S+)\}/
# $regexes[:headwords] = /^(.+)\s+\[/
# $regexes[:usages] = /\/(?:[^\z].*)\/\z/
# $regexes[:usages_multiple] = /\(\d?\d?\)\s+(.*?)(?=[\/|\) ](?:\(\d+\)|\z))/
# $regexes[:tag_like_text] = /[(|{]([^\)]*)[)|}]/
# $regexes[:first_tag_like_block] = /\] \/\(([^\)]*)\)/
# $regexes[:global_definition_tags] = /\] \/\(([^\)]*)\)/
# $regexes[:compdic_style_global_tags] = /\{([^\})]*)\}/
# $regexes[:lang_tag] = /(.+)\:(.*)/
# $regexes[:lang_tag_origin_word] = /.+\:([^\)]*)/
# $regexes[:bad_lang] = /^((.){0,4}): /
# $regexes[:p_tag] = /\(P\)/
# $regexes[:xreference] = /See ([^\)]*)/
# $regexes[:antonym] = /ant: ([^\)]*)/
# $regexes[:meaning_specifier] = /([^\)]*) only/
# $regexes[:alternative_annotations] = /(\(([ァ-ヶ]+|[ぁ-ゞ]+|[一-熙]+|pron.|i.e.|e.g.|col.|with|usually|usu.|sometimes|orig.|from|in|often|in|from|esp.|abbr.|after|also|as) [^\)]*\))/
# $regexes[:leading_spaces] = /^\s+/
# $regexes[:trailing_spaces] = /\s+$/
# $regexes[:duplicate_spaces] = /\s{2,}/
# $regexes[:leading_trailing_slashes] = /^\/|\/$/
# $regexes[:leading_trailing_slashes_greedy] = /^\s*\/|\/\s*$/ # Takes whitespace at the beginning or end with it!
# $regexes[:slash_at_end_of_line] = /\/$/
# $regexes[:first_english_token] = /([^\/|^\;]+)/
# $regexes[:all_common_kanji] = /([一-熙]+)/
# $regexes[:kana_or_basic_punctuation] = /[ぁ-んァ-ン\s\w、。;,~ー']/
# $regexes[:not_kana_nor_basic_punctuation] = /[^ぁ-んァ-ン\s\w、。;,~ー']/
# $regexes[:all_common_kanji_and_kana] = /([一-熙|ぁ-んァ-ン]+)/
# $regexes[:comma_delimited] = /([^\,]+),*/
# $regexes[:leading_space_slash] = /^\/\s{1}/
# $regexes[:parenthetical] = /(\([^\)]*\))/
# $regexes[:leading_parenthetical] = /^(\([^\)]*\))/
# $regexes[:edict_entry_id] = /\/EntL(.+)\/$/
# $regexes[:inlined_tags] = /\(([^\)]*)\)$/
# $regexes[:whitespace_padded_slashes] = /\s*\/\s*/
# $regexes[:any_whitespace] = /\s+/
# $regexes[:origin_language_tag] = /[(](cf. [^\)]*)[)]/  # gets 'cf.' annotations in parens
# $regexes[:alphanumeric] = /[A-Z|a-z|0-9]/
# $regexes[:non_alphanumeric] = /[^A-Z|a-z|0-9]/

# Delimiters
$delimiters = {}
$delimiters[:jflash_meanings]         = "; "
$delimiters[:jflash_tag_coldata]      = ","

# CFlash Delimiters
#$delimiters[:cflash_readings]         = " "

# JFlash Delimiters
# $delimiters[:jflash_readings]         = "; "
# $delimiters[:jflash_meanings]         = "; "
# $delimiters[:jflash_glosses]          = " / "
# $delimiters[:jflash_headwords]        = "; "
# $delimiters[:jflash_inlined_tags]     = ", "
# $delimiters[:jflash_jmdict_refs]      = ","
# $delimiters[:jflash_tag_sourcenames]  = ","
# $delimiters[:jflash_alt_headwords]    = ";"

# $delimiters[:edict_headwords]        = ";"
# $delimiters[:edict2_readings]         = ";"
# $delimiters[:edict2_readings_alt]     = ","
# $delimiters[:edict2_senses]           = ";"
# $delimiters[:edict2_inlined_tags]     = ","
# $delimiters[:edict2_inlined_lang_tags]= ", "

# Tanaka Corpus Specific
# $regexes[:tanc_tag_numeric] = /\[(\d+)\]/
# $regexes[:tanc_tag_non_numeric] = /\[([^\d+])\]/
# $regexes[:tanc_id_block] = /\#ID\=(.+)/
# $regexes[:tanc_b_line_reference_block] = /[^ ]+\[\d+\]/
# 
# $delimiters[:tanc_refs_array]           = " "
# $delimiters[:tanc_translated_pair]      = "\t"
# $delimiters[:tanc_tagret_language_pair] = "#"
# $delimiters[:tanc_id_pair]              = '_'
