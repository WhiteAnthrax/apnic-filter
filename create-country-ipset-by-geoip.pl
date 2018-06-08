#!/usr/bin/perl

use strict;
use warnings;
use Net::Netmask;
use Net::IP;
use File::Basename;
$| = 1;

my $download_skip_flag = 1;

my $dirname = dirname(__FILE__);

# http://dev.maxmind.com/geoip/legacy/geolite/
my $geoip_uri = 'http://geolite.maxmind.com/download/geoip/database/GeoIPCountryCSV.zip';

my $year = `date +'%Y'`;
chomp($year);
my $date = `date +'%Y%m%d'`;
chomp($date);
if (!-d "$dirname/data") {
    mkdir "$dirname/data", 0755;
}
if (!-d "$dirname/data/$year") {
    mkdir "$dirname/data/$year", 0755;
}
if (-f "$dirname/data/$year/$date") {
    unlink("$dirname/data/$year/$date");
}

if (!defined $download_skip_flag) {
    print "*** download geoip database\n";
    if (-f "$dirname/GeoIPCountryWhois.csv") {
        unlink("$dirname/GeoIPCountryWhois.csv");
    }
    my $flag = 0;
    my $count = 0;
    while($flag == 0) {
        $count++;
        `cd $dirname ; /usr/bin/curl -L -O $geoip_uri && /usr/bin/unzip $dirname/GeoIPCountryCSV.zip`;
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



#@all_list = `cat $dirname/GeoIPCountryWhois.csv`;
open my $fh, "< $dirname/GeoIPCountryWhois.csv";
my @geoip_list = <$fh>;
close $fh;

my $total_count = scalar(@geoip_list);
print "*** get ip list and diveide by country code ($total_count lines) ***\n";
### divide ip address by country_code
# "1.10.10.0","1.10.10.255","17435136","17435391","AU","Australia"
my %countries = ();
my $addresses;
my $count = 0;
foreach my $line (@geoip_list) {
    chomp($line);
    $count++;
    printf("%6d/%6d", $count ,$total_count);
    print "\b\b\b\b\b\b\b\b\b\b\b\b\b";

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
    }
    if ($orig_end_ip ne $end_ip) {
        print "BAD: end_ip in \"$line\"\n";
    }
    if ($orig_country_code ne $country_code) {
        print "BAD: country_code in \"$line\"\n";
    }
    if ($orig_country_longname ne $country_longname) {
        print "BAD: country_longname in \"$line\"\n";
    }
    if (!defined $countries{$country_code}) {
        $countries{$country_code} = $country_longname;
        #print "$country_code: $countries{$country_code}\n";
    }
    my $ip = new Net::IP("$start_ip - $end_ip");
    foreach my $network ($ip->find_prefixes()) {
        push @{$addresses->{$country_code}}, Net::Netmask->new("$network");
    }
}

### aggregate
my $total_countries = scalar(%countries);
print "*** aggregate and ipset start ($total_countries countries) ***\n";
my $country_count = 0;
foreach my $country_code (keys %countries) {
    chomp($country_code);
    $country_count++;
    #print "$country_code($countries{$country_code})\t";
    my @aggregated = ();
    @aggregated = cidrs2cidrs(@{$addresses->{$country_code}});
    my $count = scalar(@aggregated);
    my $count2 = 0;
    print "*** ipset 登録中: $country_code($countries{$country_code}) $count addresses ($country_count/$total_countries)\n";
    printf("%6d/%6d", $count2 ,$count);
    print "\b\b\b\b\b\b\b\b\b\b\b\b\b";

    `ipset create -exist $country_code-temp hash:net`;
    `ipset flush $country_code-temp`;
    foreach my $line (@aggregated) {
        chomp($line);
        $count2++;
        `ipset add $country_code-temp $line`;
        printf("%6d/%6d", $count2, $count);
        print "\b\b\b\b\b\b\b\b\b\b\b\b\b";
    }
    `ipset list $country_code > /dev/null 2>&1`;
    my $exit_value = $? >> 8;
    if ($exit_value == 0) {
        `ipset swap $country_code-temp $country_code`;
        `ipset destroy $country_code-temp`;
    } else {
        `ipset rename $country_code-temp $country_code`;
    }
}
