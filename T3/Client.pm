#! /usr/local/bin/perl

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# Barefoot::T3::Client
#
###########################################################################
#
# Routines necessary for any client program to communicate with the T3
# server.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2000 Barefoot Software.
#
###########################################################################

package T3::Client;

### Private ###############################################################

use strict;

use Barefoot::exception;
use Barefoot::T3::common;


our %output_pipes;

# make sure output pipes get cleaned up at end of program
END
{
	foreach my $pipe_file (keys %output_pipes)
	{
		unlink $pipe_file if -e $pipe_file;
	}
}


1;


#
# Subroutines:
#


# helper subs

sub _request_to_pipe
{
	T3::debug(2, "about to open pipe");
	open(PIPE, ">" . T3::REQUEST_FILE)
			or die("can't open request pipe for writing");
	T3::debug(2, "opened pipe");

	if (DEBUG)
	{
		T3::debug(1, "request lines may not contain newlines")
				if grep { /\n/ } @_;
	}
	print PIPE "$_\n" foreach @_;
	T3::debug(2, "printed to pipe");

	close(PIPE);
	T3::debug(2, "closed pipe");
}


sub send_request
{
	my $module = shift;
	my $output_id = shift;
	my $request_string = "module=$module output=$output_id";

	if (ref($_[0]) eq 'HASH')
	{
		my $options = shift;
		foreach my $key (%$options)
		{
			$request_string .= " $key=$options->{$key}";
		}
	}

	$request_string .= " lines=" . scalar(@_) if @_;
	T3::debug("request string is $request_string\n");

	_request_to_pipe($request_string, @_);
}

sub request_shutdown
{
	_request_to_pipe("SHUTDOWN");
}


sub retrieve_output
{
	my ($id) = @_;

	my $pipe_file = T3::OUTPUT_FILE . $id;
	my $pipe_is_there = timeout
	{
		until (-p $pipe_file)
		{
			die("output file $pipe_file isn't a pipe") if -e _;
			sleep 1;
		}
	} 20;
	die("server never created output pipe $pipe_file") unless $pipe_is_there;

	# make sure this pipe will get cleaned up when we exit
	$output_pipes{$pipe_file} = "";		# value isn't used

	my ($success, @output);
	T3::debug(2, "began trying to get output");
	for (1..10)							# give it a few tries ...
	{
		$success = timeout
		{
			open(PIPE, $pipe_file)
					or die("can't open output pipe for reading ($pipe_file)");
			@output = <PIPE>;
		} 3;
		T3::debug(2, "read output") if $success;
		die("never got EOF from output pipe") if @output and not $success;
		last if $success and @output;
	}
	T3::debug(2, "gave up trying to get output");
	die("can't seem to get any output from $pipe_file")
			unless $success and @output;
	close(PIPE);
	# unlink($pipe_file);
	# print STDERR "got ", scalar(@output), " lines of output\n";
	return @output;
}
