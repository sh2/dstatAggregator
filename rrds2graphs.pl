#!/usr/bin/perl

use strict;
use warnings;

use RRDs;

if ($#ARGV < 0) {
    die 'Usage: perl rrds2graph.pl rrd_file1 rrd_file2 ...';
}

my $width     = 512;
my $height    = 192;
my @rrd_files = @ARGV;

my @colors = (
    '008FFF', 'FF00BF', 'BFBF00', 'BF00FF',
    'FF8F00', '00BFBF', '7F5FBF', 'BF5F7F',
    '7F8F7F', '005FFF', 'FF007F', '7FBF00',
    '7F00FF', 'FF5F00', '00BF7F', '008FBF',
    'BF00BF', 'BF8F00', '7F5F7F', '005FBF',
    'BF007F', '7F8F00', '7F00BF', 'BF5F00',
    '008F7F', '0000FF', 'FF0000', '00BF00',
    '005F7F', '7F007F', '7F5F00', '0000BF',
    'BF0000', '008F00'
    );

my $epoch = 978274800; # 2001/01/01 00:00:00
my $lastupdate = &get_lastupdate();

&create_graph();

sub get_lastupdate {
    my $lastupdate_max = 0;
    my $lastupdate;
    
    foreach my $rrd_file (@rrd_files) {
        $lastupdate = RRDs::last($rrd_file);
        
        if ($lastupdate > $lastupdate_max) {
            $lastupdate_max = $lastupdate;
        }
    }
    
    return $lastupdate_max;
}

sub create_graph {
    my (@template, @options);
    
    # Template
    push @template, '--start';
    push @template, $epoch;
    
    push @template, '--end';
    push @template, $lastupdate;
    
    push @template, '--width';
    push @template, $width;
    
    push @template, '--height';
    push @template, $height;
    
    push @template, '--lower-limit';
    push @template, 0;
    
    push @template, '--upper-limit';
    push @template, 100;
    
    push @template, '--rigid';    
    
    # CPU user
    @options = @template;
    
    push @options, '--title';
    push @options, 'CPU Usage user (%)';
    
    my $a = -1;
    
    foreach my $rrd_file (@rrd_files) {
        $a++;
        push @options, "DEF:USR_${a}=${rrd_file}:CPU_USR:AVERAGE";
        push @options, "LINE1:USR_${a}#${colors[${a}]}:host_${a}";
    }
    
    RRDs::graph('reports/cpu_usage_u.png', @options);
    
    if (my $error = RRDs::error) {
        die $error;
    }
    
    # CPU user+system
    # CPU user+system+hardirq+softirq
    # CPU user+system+hardirq+softirq+wait
}

