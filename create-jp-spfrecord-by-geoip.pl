#!/usr/bin/perl

use strict;
use warnings;
use Net::Netmask;
use Net::IP;
use File::Basename;
$| = 1;

#my $download_skip_flag = 0;

my $dirname = dirname(__FILE__);

# http://dev.maxmind.com/geoip/legacy/geolite/
my $geoip_uri = 'http://geolite.maxmind.com/download/geoip/database/GeoIPCountryCSV.zip';

if (!defined my $download_skip_flag) {
    print "*** download geoip database\n";
    ### role old csv
    if (-f "$dirname/Japanlist-by-geoip.csv.old") {
        unlink("$dirname/Japanlist-by-geoip.csv.old");
    }
    if (-f "$dirname/Japanlist-by-geoip.csv") {
        rename("$dirname/Japanlist-by-geoip.csv", "$dirname/Japanlist-by-geoip.csv.old");
    }
    my $flag = 0;
    my $count = 0;
    while($flag == 0) {
        $count++;
        `cd $dirname ; /usr/bin/curl -s -L -O $geoip_uri && /usr/bin/unzip -o $dirname/GeoIPCountryCSV.zip && grep -i japan $dirname/GeoIPCountryWhois.csv > $dirname/Japanlist-by-geoip.csv`;
        my $exit_value = $? >> 8;
        if ($exit_value == 0) {
            $flag = 1;
        }
        if ($count > 10) {
            print "geoip download failed, exit\n";
            exit(1);
        }
    }
}

open my $fh, "< $dirname/Japanlist-by-geoip.csv";
my @geoip_list = <$fh>;
close $fh;

my $total_count = scalar(@geoip_list);
print "*** get ip list and diveide by country code ($total_count lines) ***\n";
### divide ip address by country_code
# "1.10.10.0","1.10.10.255","17435136","17435391","AU","Australia"
my %countries = ();
my @addresses;
foreach my $line (@geoip_list) {
    chomp($line);
    my ($start_ip, $end_ip, $start_decimal, $end_decimal, $country_code, $country_longname) = split(/\",\"/, $line);
    $start_ip =~ s/\"//g;
    $country_longname =~ s/\"//g;

    # validation
    my $orig_start_ip = $start_ip;
    my $orig_end_ip = $end_ip;
    my $orig_country_code = $country_code;
    my $orig_country_longname = $country_longname;
    $start_ip =~ s/[^0-9\.]//g;
    $end_ip =~ s/[^0-9\.]//g;
    $country_code =~ s/[^a-zA-Z0-9]//g;
    $country_longname =~ s/[^a-zA-Z0-9\)\('\s\,\.\/\-]//g;
    if ($orig_start_ip ne $start_ip) {
        print "BAD: start_ip in \"$line\"\n";
        next;
    }
    if ($orig_end_ip ne $end_ip) {
        print "BAD: end_ip in \"$line\"\n";
        next;
    }
    if ($orig_country_code ne $country_code) {
        print "BAD: country_code in \"$line\"\n";
        next;
    }
    if ($orig_country_longname ne $country_longname) {
        print "BAD: country_longname in \"$line\"\n";
        next;
    }
    my $ip = new Net::IP("$start_ip - $end_ip");
    foreach my $network ($ip->find_prefixes()) {
        push @addresses, Net::Netmask->new("$network");
    }
}

### aggregate
my @aggregated = ();
@aggregated = cidrs2cidrs(@addresses);
foreach my $line (@aggregated) {
    chomp($line);
    print "$line\n";
}
