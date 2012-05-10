#!/usr/bin/perl

use strict;
use warnings;

use File::Path;
use RRDs;

if ($#ARGV < 5) {
    die 'Usage: perl rrds2graph.pl report_dir width height disk_limit net_limit rrd_file1:hostname:disk:net rrd_file2:hostname:disk:net ...';
}

my $report_dir = $ARGV[0];
my $width      = $ARGV[1];
my $height     = $ARGV[2];
my $disk_limit = $ARGV[3];
my $net_limit  = $ARGV[4];
my @entries;

foreach my $arg (@ARGV[5..$#ARGV]) {
    my @p = split(/:/, $arg);
    push @entries, { 'file' => $p[0], 'host' => $p[1], 'disk' => $p[2], 'net' => $p[3] };
}

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
my $top_dir = '..';

&create_dir();
&create_graph();
&create_html();

sub create_dir {
    eval {
        mkpath($report_dir);
    };
    
    if ($@) {
        die $@;
    }
}

sub create_graph {
    my (@template, @options);
    my $color;
    
    # Template
    push @template, '--start';
    push @template, $epoch;
    
    push @template, '--end';
    push @template, &get_lastupdate();
    
    push @template, '--width';
    push @template, $width;
    
    push @template, '--height';
    push @template, $height;
    
    push @template, '--lower-limit';
    push @template, 0;
    
    push @template, '--rigid';    
    
    # CPU user
    @options = @template;
    $color = 0;
    
    push @options, '--upper-limit';
    push @options, 100;
    
    push @options, '--title';
    push @options, 'CPU Usage user (%)';
    
    foreach my $entry (@entries) {
        push @options, "DEF:USR_$entry->{'host'}=$entry->{'file'}:CPU_USR:AVERAGE";
        push @options, "LINE1:USR_$entry->{'host'}#${colors[${color}]}:$entry->{'host'}";
        $color++;
    }
    
    RRDs::graph("${report_dir}/cpu_u.png", @options);
    
    if (my $error = RRDs::error) {
        die $error;
    }
    
    # CPU user+system
    @options = @template;
    $color = 0;
    
    push @options, '--upper-limit';
    push @options, 100;
    
    push @options, '--title';
    push @options, 'CPU Usage user+system (%)';
    
    foreach my $entry (@entries) {
        push @options, "DEF:USR_$entry->{'host'}=$entry->{'file'}:CPU_USR:AVERAGE";
        push @options, "DEF:SYS_$entry->{'host'}=$entry->{'file'}:CPU_SYS:AVERAGE";
        push @options, "CDEF:US_$entry->{'host'}=USR_$entry->{'host'},SYS_$entry->{'host'},+";
        push @options, "LINE1:US_$entry->{'host'}#${colors[${color}]}:$entry->{'host'}";
        $color++;
    }
    
    RRDs::graph("${report_dir}/cpu_us.png", @options);
    
    if (my $error = RRDs::error) {
        die $error;
    }
    
    # CPU user+system+hardirq+softirq
    @options = @template;
    $color = 0;
    
    push @options, '--upper-limit';
    push @options, 100;
    
    push @options, '--title';
    push @options, 'CPU Usage user+system+hardirq+softirq (%)';
    
    foreach my $entry (@entries) {
        push @options, "DEF:USR_$entry->{'host'}=$entry->{'file'}:CPU_USR:AVERAGE";
        push @options, "DEF:SYS_$entry->{'host'}=$entry->{'file'}:CPU_SYS:AVERAGE";
        push @options, "DEF:HIQ_$entry->{'host'}=$entry->{'file'}:CPU_HIQ:AVERAGE";
        push @options, "DEF:SIQ_$entry->{'host'}=$entry->{'file'}:CPU_SIQ:AVERAGE";
        push @options, "CDEF:USHS_$entry->{'host'}=USR_$entry->{'host'},SYS_$entry->{'host'},+,HIQ_$entry->{'host'},+,SIQ_$entry->{'host'},+";
        push @options, "LINE1:USHS_$entry->{'host'}#${colors[${color}]}:$entry->{'host'}";
        $color++;
    }
    
    RRDs::graph("${report_dir}/cpu_ushs.png", @options);
    
    if (my $error = RRDs::error) {
        die $error;
    }
    
    # CPU user+system+hardirq+softirq+wait
    @options = @template;
    $color = 0;
    
    push @options, '--upper-limit';
    push @options, 100;
    
    push @options, '--title';
    push @options, 'CPU Usage user+system+hardirq+softirq+wait (%)';
    
    foreach my $entry (@entries) {
        push @options, "DEF:USR_$entry->{'host'}=$entry->{'file'}:CPU_USR:AVERAGE";
        push @options, "DEF:SYS_$entry->{'host'}=$entry->{'file'}:CPU_SYS:AVERAGE";
        push @options, "DEF:HIQ_$entry->{'host'}=$entry->{'file'}:CPU_HIQ:AVERAGE";
        push @options, "DEF:SIQ_$entry->{'host'}=$entry->{'file'}:CPU_SIQ:AVERAGE";
        push @options, "DEF:WAI_$entry->{'host'}=$entry->{'file'}:CPU_WAI:AVERAGE";
        push @options, "CDEF:USHSW_$entry->{'host'}=USR_$entry->{'host'},SYS_$entry->{'host'},+,HIQ_$entry->{'host'},+,SIQ_$entry->{'host'},+,WAI_$entry->{'host'},+";
        push @options, "LINE1:USHSW_$entry->{'host'}#${colors[${color}]}:$entry->{'host'}";
        $color++;
    }
    
    RRDs::graph("${report_dir}/cpu_ushsw.png", @options);
    
    if (my $error = RRDs::error) {
        die $error;
    }
    
    # Disk read
    @options = @template;
    $color = 0;
    
    if ($disk_limit != 0) {
        push @options, '--upper-limit';
        push @options, $disk_limit;
    }
    
    push @options, '--base';
    push @options, 1024;
    
    push @options, '--title';
    push @options, 'Disk read (Bytes/sec)';
    
    foreach my $entry (@entries) {
        if ($entry->{'disk'} eq 'total') {
            push @options, "DEF:READ_$entry->{'host'}=$entry->{'file'}:DISK_READ:AVERAGE";
        } else {
            push @options, "DEF:READ_$entry->{'host'}=$entry->{'file'}:DISK_$entry->{'disk'}_READ:AVERAGE";
        }
        
        push @options, "LINE1:READ_$entry->{'host'}#${colors[${color}]}:$entry->{'host'}_$entry->{'disk'}";
        $color++;
    }
    
    RRDs::graph("${report_dir}/disk_read.png", @options);
    
    if (my $error = RRDs::error) {
        die $error;
    }
    
    # Disk write
    @options = @template;
    $color = 0;
    
    if ($disk_limit != 0) {
        push @options, '--upper-limit';
        push @options, $disk_limit;
    }
    
    push @options, '--base';
    push @options, 1024;
    
    push @options, '--title';
    push @options, 'Disk write (Bytes/sec)';
    
    foreach my $entry (@entries) {
        if ($entry->{'disk'} eq 'total') {
            push @options, "DEF:WRIT_$entry->{'host'}=$entry->{'file'}:DISK_WRIT:AVERAGE";
        } else {
            push @options, "DEF:WRIT_$entry->{'host'}=$entry->{'file'}:DISK_$entry->{'disk'}_WRIT:AVERAGE";
        }
        
        push @options, "LINE1:WRIT_$entry->{'host'}#${colors[${color}]}:$entry->{'host'}_$entry->{'disk'}";
        $color++;
    }
    
    RRDs::graph("${report_dir}/disk_write.png", @options);
    
    if (my $error = RRDs::error) {
        die $error;
    }
    
    # Network recieve
    @options = @template;
    $color = 0;
    
    if ($net_limit != 0) {
        push @options, '--upper-limit';
        push @options, $net_limit;
    }
    
    push @options, '--base';
    push @options, 1024;
    
    push @options, '--title';
    push @options, 'Network recieve (Bytes/sec)';
    
    foreach my $entry (@entries) {
        if ($entry->{'net'} eq 'total') {
            push @options, "DEF:RECV_$entry->{'host'}=$entry->{'file'}:NET_RECV:AVERAGE";
        } else {
            push @options, "DEF:RECV_$entry->{'host'}=$entry->{'file'}:NET_$entry->{'net'}_RECV:AVERAGE";
        }
        
        push @options, "LINE1:RECV_$entry->{'host'}#${colors[${color}]}:$entry->{'host'}_$entry->{'net'}";
        $color++;
    }
    
    RRDs::graph("${report_dir}/net_recieve.png", @options);
    
    if (my $error = RRDs::error) {
        die $error;
    }
    
    # Network send
    @options = @template;
    $color = 0;
    
    if ($net_limit != 0) {
        push @options, '--upper-limit';
        push @options, $net_limit;
    }
    
    push @options, '--base';
    push @options, 1024;
    
    push @options, '--title';
    push @options, 'Network send (Bytes/sec)';
    
    foreach my $entry (@entries) {
        if ($entry->{'net'} eq 'total') {
            push @options, "DEF:SEND_$entry->{'host'}=$entry->{'file'}:NET_SEND:AVERAGE";
        } else {
            push @options, "DEF:SEND_$entry->{'host'}=$entry->{'file'}:NET_$entry->{'net'}_SEND:AVERAGE";
        }
        
        push @options, "LINE1:SEND_$entry->{'host'}#${colors[${color}]}:$entry->{'host'}_$entry->{'net'}";
        $color++;
    }
    
    RRDs::graph("${report_dir}/net_send.png", @options);
    
    if (my $error = RRDs::error) {
        die $error;
    }
}

sub create_html {
    open(my $fh, '>', "${report_dir}/index.html") or die $!;
    
    print $fh <<_EOF_;
<!DOCTYPE html>
<html>
  <head>
    <title>dstatAggregator</title>
    <link href="${top_dir}/css/bootstrap.min.css" rel="stylesheet" />
    <style type="text/css">
      body {
        padding-top: 20px;
        padding-bottom: 20px;
      }
      .sidebar-nav {
        padding: 12px 4px;
      }
      .hero-unit {
        padding: 24px;
      }
    </style>
  </head>
  <body>
    <div class="container-fluid">
      <div class="row-fluid">
        <div class="span3">
          <div class="well sidebar-nav">
            <ul class="nav nav-list">
              <li class="nav-header">CPU Usage</li>
              <li><a href="#cpu_u">CPU Usage user</a></li>
              <li><a href="#cpu_us">CPU Usage +system</a></li>
              <li><a href="#cpu_ushs">CPU Usage +hardirq+softirq</a></li>
              <li><a href="#cpu_ushsw">CPU Usage +wait</a></li>
              <li class="nav-header">Disk I/O</li>
              <li><a href="#disk_read">Disk read</a></li>
              <li><a href="#disk_write">Disk write</a></li>
              <li class="nav-header">Network I/O</li>
              <li><a href="#net_recieve">Network recieve</a></li>
              <li><a href="#net_send">Network send</a></li>
            </ul>
          </div>
        </div>
        <div class="span9">
          <div class="hero-unit">
            <h1>dstatAggregator</h1>
            <ul>
          </div>
          <h2>CPU Usage</h2>
          <h3 id="cpu_u">CPU Usage user</h3>
          <p><img src="cpu_u.png" alt="CPU Usage user" /></p>
          <h3 id="cpu_us">CPU Usage user+system</h3>
          <p><img src="cpu_us.png" alt="CPU Usage user+system" /></p>
          <h3 id="cpu_ushs">CPU Usage user+system+hardirq+softirq</h3>
          <p><img src="cpu_ushs.png" alt="CPU Usage user+system+hardirq+softirq" /></p>
          <h3 id="cpu_ushsw">CPU Usage user+system+hardirq+softirq+wait</h3>
          <p><img src="cpu_ushsw.png" alt="CPU Usage user+system+hardirq+softirq+wait" /></p>
          <hr />
          <h2>Disk I/O</h2>
          <h3 id="disk_read">Disk read</h3>
          <p><img src="disk_read.png" alt="Disk read" /></p>
          <h3 id="disk_write">Disk write</h3>
          <p><img src="disk_write.png" alt="Disk write" /></p>
          <hr />
          <h2>Network I/O</h2>
          <h3 id="net_recieve">Network recieve</h3>
          <p><img src="net_recieve.png" alt="Network recieve" /></p>
          <h3 id="net_send">Network send</h3>
          <p><img src="net_send.png" alt="Network send" /></p>
        </div>
      </div>
      <hr />
      <div class="footer">
        (c) 2012, Sadao Hiratsuka.
      </div>
    </div>
    <script src="${top_dir}/js/jquery-1.7.2.min.js"></script>
    <script src="${top_dir}/js/bootstrap.min.js"></script>
  </body>
</html>
_EOF_
    
    close($fh);
}

sub get_lastupdate {
    my $lastupdate_max = 0;
    my $lastupdate;
    
    foreach my $entry (@entries) {
        $lastupdate = RRDs::last($entry->{'file'});
        
        if (my $error = RRDs::error) {
            die $error;
        }
        
        if ($lastupdate > $lastupdate_max) {
            $lastupdate_max = $lastupdate;
        }
    }
    
    return $lastupdate_max;
}

