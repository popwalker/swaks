#!/usr/bin/env perl

while (<>) {
	s|\r|\\r|g;
	s|\n|\\n\n|g;
	print;
}
