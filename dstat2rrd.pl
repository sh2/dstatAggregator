#!/usr/bin/perl

use strict;
use warnings;

use DBI qw/:sql_types/;
use File::Basename;
use File::Copy;
use File::Path;
use Time::Local;
use Text::ParseWords;
use RRDs;

if ($#ARGV != 1) {
    die 'Usage: perl dstat2rrd.pl csv_file rrd_name';
}

my $csv_file   = $ARGV[0];
my $rrd_name   = $ARGV[1];
my $report_dir = 'rrds';

my $epoch = 978274800; # 2001/01/01 00:00:00
my $rrd_file = '/dev/shm/dstat2rrd/' . &random_str() . '.rrd';

my ($hostname, $year, @data, %index_disk, %index_cpu, %index_net, $rrd_id);
my ($start_time, $end_time) = (0, 0);
my ($procs_max, $procs_new_max, $memory_max, $paging_max) = (0, 0, 0, 0);
my ($disk_max, $interrupts_max, $cswitches_max, $net_max) = (0, 0, 0, 0);

&load_csv();
&create_rrd();
&update_rrd();
&create_dir();
&insert_db();
&move_rrd();

sub load_csv {
    open(my $fh, '<', "${csv_file}") or die $!;
    
    while (my $line = <$fh>) {
        chomp($line);
        
        if ($line eq '') {
            # Empty
        } elsif ($line =~ /^"?[a-zA-Z]/) {
            # Header
            my @cols = parse_line(',', 0, $line);
            
            if ($cols[0] eq 'Host:') {
                # Host, User
                $hostname = $cols[1];
            } elsif ($cols[0] eq 'Cmdline:') {
                # Cmdline, Date
                if ($cols[6] =~ /^\d+ \w+ (\d+)/) {
                    $year = $1;
                }
            # RHEL5:time, RHEL6:system
            } elsif (($cols[0] eq 'time') or ($cols[0] eq 'system')) {
                # Column name main
                my $index = -1;
                
                foreach my $col (@cols) {
                    $index++;
                    
                    if (!defined($col)) {
                        # Empty
                    } elsif (($col =~ /^dsk\/(\w+[a-z])$/)
                             or ($col =~ /^dsk\/cciss\/(c\d+d\d+)$/)) {
                        # Disk
                        my $disk = $1;
                        $disk =~ tr/\//_/;
                        $index_disk{$disk} = $index;
                    } elsif ($col =~ /^cpu(\d+)/) {
                        # CPU
                        $index_cpu{$1} = $index;
                    } elsif ($col =~ /^net\/(\w+)/) {
                        # Network
                        my $net = $1;
                        $net =~ tr/\//_/;
                        $index_net{$net} = $index;
                    }
                }
            } elsif ($cols[0] eq 'date/time') {
                # Column name sub
            } else {
                die 'It is not a dstat CSV file.';
            }
        } else {
            # Body
            my ($disk_read, $disk_writ, $net_recv, $net_send) = (0, 0, 0, 0);
            my @cols = parse_line(',', 0, $line);
            
            if ($start_time == 0) {
                if (!defined($hostname)) {
                    die 'It is not a dstat CSV file. No \'Host:\' column found.';
                }
                
                if (!defined($year)) {
                    die 'It is not a dstat CSV file. No \'Date:\' column found.';
                }
                
                if (!%index_disk) {
                    die 'It is not a dstat CSV file. No \'dsk/*:\' columns found.';
                }
                
                if (!%index_cpu) {
                    die 'It is not a dstat CSV file. No \'cpu*:\' columns found.';
                }
                
                if (!%index_net) {
                    die 'It is not a dstat CSV file. No \'net/*\' columns found.';
                }
                
                $start_time = &get_unixtime($year, $cols[0]);
            }
            
            my $unixtime = &get_unixtime($year, $cols[0]);
            
            if ($unixtime <= $end_time) {
                next;
            }
            
            $end_time = $unixtime;
            
            push @data, $line;
            
            # Find maximum values
            # Processes
            if ($procs_max < $cols[1]) {
                $procs_max = $cols[1];
            }
            
            if ($procs_max < $cols[2]) {
                $procs_max = $cols[2];
            }
            
            if ($procs_new_max < $cols[3]) {
                $procs_new_max = $cols[3];
            }
            
            # Memory
            if ($memory_max < $cols[4] + $cols[5] + $cols[6] + $cols[7]) {
                $memory_max = $cols[4] + $cols[5] + $cols[6] + $cols[7];
            }
            
            # Paging
            if ($paging_max < $cols[8]) {
                $paging_max = $cols[8];
            }
            
            if ($paging_max < $cols[9]) {
                $paging_max = $cols[9];
            }
            
            # Disk
            foreach my $disk (keys %index_disk) {
                $disk_read += $cols[$index_disk{$disk}];
                $disk_writ += $cols[$index_disk{$disk} + 1];
            }
            
            if ($disk_max < $disk_read) {
                $disk_max = $disk_read;
            }
            
            if ($disk_max < $disk_writ) {
                $disk_max = $disk_writ;
            }
            
            # Interrupts
            if ($interrupts_max < $cols[$index_cpu{'0'} - 2]) {
                $interrupts_max = $cols[$index_cpu{'0'} - 2];
            }
            
            # Context Switches
            if ($cswitches_max < $cols[$index_cpu{'0'} - 1]) {
                $cswitches_max = $cols[$index_cpu{'0'} - 1];
            }
            
            foreach my $net (keys %index_net) {
                $net_recv += $cols[$index_net{$net}];
                $net_send += $cols[$index_net{$net} + 1];
            }
            
            # Network
            if ($net_max < $net_recv) {
                $net_max = $net_recv;
            }
            
            if ($net_max < $net_send) {
                $net_max = $net_send;
            }
        }
    }
    close($fh);
}

sub create_rrd {
    my @options;
    my $count = $end_time - $start_time + 1;
    
    # --start
    push @options, '--start';
    push @options, $epoch - 1;
    
    # --step
    push @options, '--step';
    push @options, 1;
    
    # Processes
    push @options, 'DS:PROCS_RUN:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    push @options, 'DS:PROCS_BLK:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    push @options, 'DS:PROCS_NEW:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    # Memory
    push @options, 'DS:MEMORY_USED:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    push @options, 'DS:MEMORY_BUFF:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    push @options, 'DS:MEMORY_CACH:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    # Paging
    push @options, 'DS:PAGE_IN:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    push @options, 'DS:PAGE_OUT:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    # Disk total
    push @options, 'DS:DISK_READ:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    push @options, 'DS:DISK_WRIT:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    # Disk individual
    foreach my $disk (sort keys %index_disk) {
        push @options, "DS:DISK_${disk}_READ:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:1:${count}";
        
        push @options, "DS:DISK_${disk}_WRIT:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:1:${count}";
    }
    
    # Interrupts
    push @options, 'DS:INTERRUPTS:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    # Context Switches
    push @options, 'DS:CSWITCHES:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    # CPU total
    push @options, 'DS:CPU_USR:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    push @options, 'DS:CPU_SYS:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    push @options, 'DS:CPU_HIQ:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    push @options, 'DS:CPU_SIQ:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    push @options, 'DS:CPU_WAI:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    # CPU individual
    foreach my $cpu (sort { $a <=> $b } keys %index_cpu) {
        push @options, "DS:CPU${cpu}_USR:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:1:${count}";
        
        push @options, "DS:CPU${cpu}_SYS:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:1:${count}";
        
        push @options, "DS:CPU${cpu}_HIQ:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:1:${count}";
        
        push @options, "DS:CPU${cpu}_SIQ:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:1:${count}";
        
        push @options, "DS:CPU${cpu}_WAI:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:1:${count}";
    }
    
    # Network total
    push @options, 'DS:NET_RECV:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    push @options, 'DS:NET_SEND:GAUGE:5:U:U';
    push @options, "RRA:AVERAGE:0.5:1:${count}";
    
    # Network individual
    foreach my $net (sort keys %index_net) {
        push @options, "DS:NET_${net}_RECV:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:1:${count}";
        
        push @options, "DS:NET_${net}_SEND:GAUGE:5:U:U";
        push @options, "RRA:AVERAGE:0.5:1:${count}";
    }
    
    RRDs::create($rrd_file, @options);
    
    if (my $error = RRDs::error) {
        die $error;
    }
}

sub update_rrd {
    my @entries;
    
    foreach my $row (@data) {
        my $entry = '';
        my @cols = parse_line(',', 0, $row);
        
        $entry .= $epoch + &get_unixtime($year, $cols[0]) - $start_time;
        
        # Processes
        $entry .= ":${cols[1]}:${cols[2]}:${cols[3]}";
        
        # Memory
        $entry .= ":${cols[4]}:${cols[5]}:${cols[6]}";
        
        # Paging
        $entry .= ":${cols[8]}:${cols[9]}";
        
        # Disk total
        my ($disk_read, $disk_writ) = (0, 0);
        
        foreach my $disk (keys %index_disk) {
            $disk_read += $cols[$index_disk{$disk}];
            $disk_writ += $cols[$index_disk{$disk} + 1];
        }
        
        $entry .= ":${disk_read}:${disk_writ}";
        
        # Disk individual
        foreach my $disk (sort keys %index_disk) {
            $disk_read = $cols[$index_disk{$disk}];
            $disk_writ = $cols[$index_disk{$disk} + 1];
            
            $entry .= ":${disk_read}:${disk_writ}";
        }
        
        # Interrupts
        $entry .= ":${cols[${index_cpu{'0'}} - 2]}";
        
        # Context Switches
        $entry .= ":${cols[${index_cpu{'0'}} - 1]}";
        
        # CPU total
        my ($cpu_usr, $cpu_sys, $cpu_hiq, $cpu_siq, $cpu_wai) = (0, 0, 0, 0, 0);
        
        foreach my $cpu (keys %index_cpu) {
            $cpu_usr += $cols[$index_cpu{$cpu}];
            $cpu_sys += $cols[$index_cpu{$cpu} + 1];
            $cpu_hiq += $cols[$index_cpu{$cpu} + 4];
            $cpu_siq += $cols[$index_cpu{$cpu} + 5];
            $cpu_wai += $cols[$index_cpu{$cpu} + 3];
        }
        
        $cpu_usr /= scalar(keys %index_cpu);
        $cpu_sys /= scalar(keys %index_cpu);
        $cpu_hiq /= scalar(keys %index_cpu);
        $cpu_siq /= scalar(keys %index_cpu);
        $cpu_wai /= scalar(keys %index_cpu);
        
        $entry .= ":${cpu_usr}:${cpu_sys}:${cpu_hiq}:${cpu_siq}:${cpu_wai}";
        
        # CPU individual
        foreach my $cpu (sort { $a <=> $b } keys %index_cpu) {
            $cpu_usr = $cols[$index_cpu{$cpu}];
            $cpu_sys = $cols[$index_cpu{$cpu} + 1];
            $cpu_hiq = $cols[$index_cpu{$cpu} + 4];
            $cpu_siq = $cols[$index_cpu{$cpu} + 5];
            $cpu_wai = $cols[$index_cpu{$cpu} + 3];
            $entry .= ":${cpu_usr}:${cpu_sys}:${cpu_hiq}:${cpu_siq}:${cpu_wai}";
        }
        
        # Network total
        my ($net_recv, $net_send) = (0, 0);
        
        foreach my $net (keys %index_net) {
            $net_recv += $cols[$index_net{$net}];
            $net_send += $cols[$index_net{$net} + 1];
        }
        
        $entry .= ":${net_recv}:${net_send}";
        
        # Network individual
        foreach my $net (sort keys %index_net) {
            $net_recv = $cols[$index_net{$net}];
            $net_send = $cols[$index_net{$net} + 1];
            
            $entry .= ":${net_recv}:${net_send}";
        }
        
        push @entries, $entry;
    }
    
    RRDs::update($rrd_file, @entries);
    
    if (my $error = RRDs::error) {
        &delete_rrd();
        die $error;
    }
}

sub create_dir {
    eval {
        mkpath($report_dir);
    };
    
    if ($@) {
        &delete_rrd();
        die $@;
    }
}

sub insert_db {
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime($start_time);
    
    my $start_time_str = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
        $year + 1900, $mon + 1, $mday, $hour, $min, $sec); 
    
    my $devices_disk = join(',', sort keys %index_disk);
    my $devices_net = join(',', sort keys %index_net);
    
    my $dbh;
    
    eval {
        $dbh = DBI->connect('DBI:mysql:rstat;mysql_server_prepare=1', 'rstat', 'rstat', { RaiseError => 1, PrintError => 0, AutoCommit => 0 });
        my $sth = $dbh->prepare_cached(q{INSERT INTO rrd (rrd_name, hostname, start_time, duration, devices_disk, devices_net, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())});
        
        $sth->bind_param(1, $rrd_name, SQL_VARCHAR);
        $sth->bind_param(2, $hostname, SQL_VARCHAR);
        $sth->bind_param(3, $start_time_str, SQL_DATETIME);
        $sth->bind_param(4, $end_time - $start_time, SQL_INTEGER);
        $sth->bind_param(5, $devices_disk, SQL_VARCHAR);
        $sth->bind_param(6, $devices_net, SQL_VARCHAR);
        
        $sth->execute();
        $rrd_id = $sth->{'mysql_insertid'};
        $sth->finish();
        $dbh->commit();
        $dbh->disconnect();
    };
    
    if ($@) {
        my $message = $@;
        
        if ($dbh) {
            eval {
                $dbh->rollback();
            };
            eval {
                $dbh->disconnect();
            };
        }
        
        &delete_rrd();
        die $message;
    }
}

sub move_rrd {
    if (!move($rrd_file, sprintf("${report_dir}/%05d_${rrd_name}.rrd", $rrd_id))) {
        &delete_rrd();
        die $!;
    }
}

sub delete_rrd {
    unlink $rrd_file;
}

sub random_str {
    my $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    my $length = length($chars);
    my $str = '';
    
    for (my $i = 0; $i < 16; $i++) {
        $str .= substr($chars, int(rand($length)), 1);
    }
    
    return $str;
}

sub get_unixtime {
    my ($year, $datetime) = @_;
    my $unixtime = 0;
    
    if ($datetime =~ /^(\d+)-(\d+) (\d+):(\d+):(\d+)/) {
        $unixtime = timelocal($5, $4, $3, $1, $2 -1, $year);
    }
    
    return $unixtime;
}
