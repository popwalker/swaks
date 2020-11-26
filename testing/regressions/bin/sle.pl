#!/usr/bin/env perl

use strict;
use open "IN" => ":raw", "OUT" => ":raw";

while (<>) {
	s|\r|\\r|g;
	s|\n|\\n\n|g;
	print;
}
