#!/usr/bin/perl

#use strict;
#use warnings;
use Net::Netmask;
use Net::IP;
use File::Basename;
use Data::Dumper;
use FindBin;
use Text::ParseWords;

$| = 1;

my $dirname = $FindBin::Bin;
print "$dirname\n";
my $run_mode = $ARGV[0];

### for JP list
my $geoip_zipfile = 'GeoLite2-Country-CSV.zip';
my $geoip_blockfile = 'GeoLite2-Country-Blocks-IPv4.csv';
my $geoname_idfile = 'GeoLite2-Country-Locations-en.csv';
my $geolite_dir = "$dirname/GeoLite2";

my $config;
my $conf_file = "$dirname/config.ini";
if (-f "$conf_file") {
    print "read $conf_file\n";
    $config = do $conf_file or die "$!$@";
} else {
    print "Can't read $conf_file\n";
    exit(1);
}

$iptables = $config->{iptables};
$limit = '-m multiport --dport ' . $config->{limit_port};
$allow_list = $config->{allow_country};
$ipset = $config->{ipset};
$unzip = $config->{unzip};
$curl = $config->{curl};

my $geoip_uri = 'https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=' . $config->{geolite2_license} . '&suffix=zip';

if (!-x $unzip) {
    print "unzip not found\n";
    exit(1);
}

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

### process geolite2
print "*** download geoip database\n";

if (-d "$geolite_dir") {
    `rm -rf $geolite_dir`;
}

my $flag = 0;
my $count = 0;
while ($flag == 0) {
    $count++;
    `cd $dirname ; ${curl} -s -L -o $geoip_zipfile "$geoip_uri" && ${unzip} -j -d $geolite_dir $dirname/$geoip_zipfile`;
    my $exit_value = $? >> 8;
    if ($exit_value == 0) {
        $flag = 1;
    }
    if ($count > 10) {
        print "geolite2 file download failed\n";
        exit(1);
    }
}

### get geoname_id
# geoname_id,locale_code,continent_code,continent_name,country_iso_code,country_name,is_in_european_union
# 49518,en,AF,Africa,RW,Rwanda,0
# 6255147,en,AS,Asia,,,0
# 6255148,en,EU,Europe,,,0

open my $fh, '<', "$geolite_dir/$geoname_idfile";
@all_geoname_data = <$fh>;
close $fh;
# remove header
shift(@all_geoname_data);

print @all_geoname_data;

my @list_country = ();
my %geoname_id_cc = {};
foreach my $line (@all_geoname_data) {
  my @parsed_csv = &parse_line(',', undef, $line);
  my ($geoname_id, $locale_code, $continent_code, $continent_name, $country_iso_code, $country_name, $is_in_european_union) = @parsed_csv;
  if ($country_iso_code eq '' and $country_name eq '') {
    $country_iso_code = $continent_name;
    $country_name = $continent_name;
  }
  push(@list_country, "$geoname_id\t$country_iso_code\t$country_name");
  $geoname_id_cc{$geoname_id} = $country_iso_code;

}
push(@list_country, "UNKNOWN\tUNKNOWN\tUNKOWN");
$geoname_id_cc{"UNKNOWN"} = "UNKNOWN";

foreach my $line (@list_country) {
  print "$line\n";
}

open my $fh, '<', "$geolite_dir/$geoip_blockfile";
my @ipv4_blocklist = <$fh>;
close $fh;
shift(@ipv4_blocklist);
print "GeoLite2 all records: " . scalar(@ipv4_blocklist) . "\n";

$year = `date +'%Y'`;
chomp($year);
$date = `date +'%Y%m%d'`;
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

foreach my $list (@list_country) {
    chomp($list);
    my ($geoname_id, $code, $country) = split(/\t/, $list);
    my $allow = 0;
    foreach my $check (@$allow_list) {
        chomp($check);
        if ($check eq $code) {
            $allow = 1;
        }
    }
    if ($allow == 0) {
        push(@deny_country, $geoname_id);
    } else {
        push(@allow_country, $geoname_id);
    }
    push(@all_country, $geoname_id);
    $codehash{$code} = $country;
}

foreach $line (@allow_country) {
	print "*** ALLOW Country: $line\n";
}
foreach $line (@deny_country) {
	print "*** DENY Country: $line\n";
}

### アドレスブロックを整理
print "*** リストからアドレスを変換\n";

#network,geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider
#1.0.0.0/24,2077456,2077456,,0,0
#80.231.5.0/24,,,,0,1
#193.200.150.0/24,,,,1,0

my $counter = 0;
foreach $line (@ipv4_blocklist) {
    chomp($line);
    $line =~ s/\"//g;
    $counter++;
    #($start, $end, $count1, $count2, $cc, $cc_desc) = split(/,/, $line);
    ($network, $geoname_id, $registered_country_geoname_id, $represented_country_geoname_id, $is_anonymous_proxy, $is_satellite_provider) = split(/,/, $line);
    if ($geoname_id eq '') {
      $geoname_id = $registered_country_geoname_id;
    }
    if ($geoname_id eq '' and $registered_country_geoname_id eq '' and $represented_country_geoname_id eq '') {
      $geoname_id = 'UNKNOWN';
    }
    #print "$counter: $geoname_id_cc{$geoname_id}, $network\n";

    my $ip = new Net::IP($network);
    foreach $temp ($ip->find_prefixes()) {
        push @{$addresses->{$geoname_id_cc{$geoname_id}}}, Net::Netmask->new("$temp");
		$countries{$geoname_id_cc{$geoname_id}} = 1;
    }
}

if (!-d "$dirname/data") {
    mkdir "$dirname/data", 0755;
}

### 国ごとのログを取れるように
open my $fh, '>', "$dirname/data/$year/$date-iptables";
print "#!/bin/sh\n\n";
### FILTER初期化
#print "*** DENY_FILTERをFlush(iptables -F DENY_FILTER)\n";
print $fh "$iptables -D INPUT -m conntrack --ctstate NEW -j DENY_FILTER\n";
print $fh "$iptables -F DENY_FILTER\n";
print $fh "$iptables -X DENY_FILTER\n";
print $fh "$iptables -N DENY_FILTER\n";
print $fh "$iptables -A INPUT -m conntrack --ctstate NEW -j DENY_FILTER\n";

foreach $country (@deny_country) {
    chomp($country);
    $filter_header = $geoname_id_cc{$country} . '_DENY';
    print $fh "echo \"*** FILTER初期化中: $codehash{$geoname_id_cc{$country}}\"\n";
    print $fh "$iptables -F $filter_header\n";
    print $fh "$iptables -X $filter_header\n";
    print $fh "$iptables -N $filter_header\n";
    print $fh "$iptables -A $filter_header -j NFLOG --nflog-prefix=\"[DROP $codehash{$geoname_id_cc{$country}}] \" --nflog-group 2\n";
    print $fh "$iptables -A $filter_header -j DROP\n";
    print $fh "$iptables -A DENY_FILTER -p tcp -m set --match-set $geoname_id_cc{$country} src $limit -j $filter_header\n";
}
foreach $country (@allow_country) {
    chomp($country);
    $filter_header = $geoname_id_cc{$country} . '_ALLOW';
    print $fh "echo \"*** FILTER初期化中: $codehash{$geoname_id_cc{$country}}\"\n";
    print $fh "$iptables -F $filter_header\n";
    print $fh "$iptables -X $filter_header\n";
    print $fh "$iptables -N $filter_header\n";
    print $fh "$iptables -A $filter_header -j NFLOG --nflog-prefix=\"[ACCEPT $codehash{$geoname_id_cc{$country}}] \" --nflog-group 2\n";
    print $fh "$iptables -A $filter_header -j ACCEPT\n";
    print $fh "$iptables -A DENY_FILTER -p tcp -m set --match-set $geoname_id_cc{$country} src $limit -j $filter_header\n";
}
print $fh "echo \"*** FILTER初期化中: OTHER\"\n";
print $fh "$iptables -F OTHER_DENY\n";
print $fh "$iptables -X OTHER_DENY\n";
print $fh "$iptables -N OTHER_DENY\n";
print $fh "$iptables -A OTHER_DENY -j NFLOG --nflog-prefix='[DROP OTHER] ' --nflog-group 2\n";
print $fh "$iptables -A OTHER_DENY -j DROP\n";
print "*** other IP DENY ***\n";
print $fh "$iptables -A DENY_FILTER -p tcp -s 0.0.0.0/0 $limit -j OTHER_DENY\n";
close $fh;


### aggregate
print "*** aggregate中 ***\n";
open my $fh, '>', "$dirname/data/$year/$date-update-ipset";
print $fh "#!/bin/sh\n\n";
close $fh;

foreach $country (keys %countries) {
    chomp($country);
    print "$country($codehash{$country})\t";
    @aggregated = ();
    @aggregated = cidrs2cidrs(@{$addresses->{$country}});
    open my $fh, '>>', "$dirname/data/$year/$date-update-ipset";
    $filter_header = $country . '_DENY';
    $count = scalar(@aggregated);
    $count2 = 0;
    print $fh "echo \"*** ipset 登録中: $country($codehash{$country}) $count address\"\n";
    print $fh "printf \"%6d/%6d\" 0 $count\n";
    print $fh "echo -ne '\b\b\b\b\b\b\b\b\b\b\b\b\b'\n";

    print $fh "$ipset create -exist $country-temp hash:net maxelem $count\n";
    print $fh "$ipset flush $country-temp\n";

    foreach $line (@aggregated) {
        chomp($line);
        $count2++;
        #print $fh "$iptables -w -A DENY_FILTER -p tcp -s $line $limit -j $filter_header\n";
        #print $fh "$iptables -A DENY_FILTER -p tcp -s $line $limit -j $filter_header\n";
        print $fh "$ipset add $country-temp $line\n";
        print $fh "printf \"%6d/%6d\" $count2 $count\n";
        print $fh "echo -ne '\b\b\b\b\b\b\b\b\b\b\b\b\b'\n";
    }
    print $fh "$ipset list $country > /dev/null 2>&1\n";
    print $fh 'if [ $? -eq 0 ]; then' . "\n";
    print $fh "  $ipset swap $country-temp $country\n";
    print $fh "  $ipset destroy $country-temp\n";
    print $fh "else\n";
    print $fh "  $ipset rename $country-temp $country\n";
    print $fh "fi\n";
    close $fh;
}

### allow execute
`chmod +x $dirname/data/$year/$date-iptables`;
`chmod +x $dirname/data/$year/$date-update-ipset`;

### update current link
`ln -sf $dirname/data/$year/$date-iptables $dirname/current-iptables`;
`ln -sf $dirname/data/$year/$date-update-ipset $dirname/current-update-ipset`;

if ($run_mode eq "update-ipset") {
    system("sudo /bin/sh -c \"$dirname/data/$year/$date-update-ipset && $ipset save > /etc/ipset.conf\"");
    exit(0);
}

### FILTER更新
print "*** 新しいKRFILTERを登録\n";
#system("sudo /bin/sh $dirname/data/$date");
print "# for initial\n";
print "please run 'sudo /bin/sh $dirname/data/$year/$date-iptables'\n";
print "# for iplist update only\n";
print "please run 'sudo /bin/sh -c \"$dirname/data/$year/$date-update-ipset && $ipset save > /etc/ipset.conf\"'\n";
print "*** 完了\n";
