#!/usr/bin/perl

#use strict;
#use warnings;
use Net::Netmask;
use File::Basename;

$| = 1;

my $dirname = dirname(__FILE__);
my $iptables = '/usr/sbin/iptables';
my $limit = '-m multiport --dport 22,25,53,80,110,139,143,587,901,993,995,3128,4949';

### filterしない国コード
my @allow_list = (
    'JP',
    'AP',
    );

my @list_country = (
    "AF\tAfghanistan", 	#アフガニスタン
    "AP\tAsia Pacific region", 	#アジア太平洋地域に複数箇所にまたがる物
    "AS\tAmerican Samoa", 	#サモア
    "AU\tAustralia", 	#オーストラリア
    "BD\tBangladesh", 	#バングラディシュ人民共和国
    "BN\tBrunei Darussalam", 	#ブルネイ・ダルサラーム
    "BT\tBhutan", 	#ブータン大国
    "CH\tSwitzland", 	#スイス連邦
    "CK\tCook Islans", 	#クック諸島
    "CN\tChina", 	#中華人民共和国
    "FJ\tFiji", 	#フィージー
    "FM\tMicronesia", 	#ミクロネシア連邦
    "GB\tGreat Britain", 	#北部イギリス及び北アイルランド
    "GU\tGuam", 	#グァム
    "HK\tHong Kong", 	#香港
    "ID\tIndonesia", 	#インドネシア共和国
    "IN\tIndia", 	#インド
    "IO\tBritish Indian O.Terr.", 	#旧英国領インド
    "JP\tJapan", 	#日本
    "KH\tCambodia", 	#カンボジア
    "KI\tKiribati", 	#キルバス共和国
    "KR\tSouth Korea", 	#大韓民国(韓国)
    "LA\tLaos", 	#ラオス人民民主共和国
    "LK\tSri Lanka", 	#スリランカ民主社会主義共和国
    "MH\tMarshall Islands", 	#マーシャル諸島共和国
    "MM\tMyanmar", 	#ミャンマー連邦
    "MN\tMongolia", 	#モンゴル
    "MO\tMacau", 	#マカオ
    "MP\tNorthern Mariana Island", 	#北マリアナ諸島
    "MU\tMauritius", 	#モーリシャス共和国
    "MV\tMaldives", 	#モルジブ共和国
    "MY\tMalaysia", 	#マレーシア
    "NC\tNew Caledonia", 	#ニューカレドニア
    "NF\tNorfolk Island", 	#ノーフォーク島
    "NL\tNetherlands", 	#オランダ王国
    "NP\tNepal", 	#ネパール王国
    "NR\tNauru", 	#ナウル共和国
    "NU\tNiue", 	#ニウーエイ島
    "NZ\tNew Zealand", 	#ニュージーランド
    "PF\tPolynesia", 	#ポリナシア
    "PG\tPapua New Guinea", 	#パプアニューギニア
    "PH\tPhilippines", 	#フィリピン共和国
    "PK\tPakistan", 	#パキスタン・イスラム共和国
    "PW\tPalau", 	#パラオ共和国
    "SA\tSaudi Arabia", 	#サイジアラビア王国
    "SB\tSolomon Islands", 	#ソロモン諸島
    "SE\tSweden", 	#スウェーデン王国
    "SG\tSingapore", 	#シンガポール共和国
    "TH\tThailand", 	#タイ王国
    "TO\tTonga", 	#トンガ王国
    "TV\tTuvalu", 	#ツバル
    "TW\tTaiwan", 	#台湾
    "US\tUnited States", 	#米国
    "VN\tVietnam", 	#ベトナム社会主義共和国
    "VU\tVanuatu", 	#バヌアツ共和国
    "WS\tWestern Samoa", 	#西サモア
    );

foreach my $list (@list_country) {
    chomp($list);
    my ($code, $country) = split(/\t/, $list);
    my $allow = 0;
    foreach my $check (@allow_list) {
	chomp($check);
	if ($check eq $code) {
	    $allow = 1;
	}
    }
    if ($allow == 0) {
	push(@deny_country, $code);
    }
    push(@all_country, $code);
    $codehash{$code} = $country;
}

### apnicからdelegate listの取得
print "*** apnicからdelegate listの取得\n";
if (-f "$dirname/delegated-apnic-latest") {
    unlink("$dirname/delegated-apnic-latest");
}
if (-f "$dirname/delegated-apnic-latest.md5") {
    unlink("$dirname/delegated-apnic-latest.md5");
}
`cd $dirname; /usr/bin/lftpget ftp://ftp.apnic.net/public/apnic/stats/apnic/delegated-apnic-latest`;
`cd $dirname; /usr/bin/lftpget ftp://ftp.apnic.net/public/apnic/stats/apnic/delegated-apnic-latest.md5`;

### md5のチェック
print "*** MD5 check\n";
@repl = `cd $dirname; /usr/bin/md5sum -c $dirname/delegated-apnic-latest.md5`;
if (scalar(@repl) != 1) {
    print "NG: md5sum error $dirname/delegated-apnic-latest\n";
    exit(0);
}


### アドレスブロックを整理
print "*** リストからアドレスを変換\n";
@list = `grep ipv4 $dirname/delegated-apnic-latest`;

foreach $line (@list) {
    chomp($line);
    ($registry, $cc, $type, $start, $value, $date, $status, $extensions) = split(/\|/, $line);
    foreach $country (@deny_country) {
	chomp($country);
	if ($country eq $cc) {
	    $mask = 32;
	    $x = $value;
	    while ($x != 1) {
		$x = $x / 2;
		$mask--;
	    }
	    push @{$addresses->{$country}}, Net::Netmask->new("$start/$mask");
	}
    }
}

if (!-d "$dirname/data") {
    mkdir "$dirname/data", 0755;
}

$date = `date +'%Y%m%d'`;
chomp($date);
if (-f "$dirname/data/$date") {
    unlink("$dirname/data/$date");
}


### 国ごとのログを取れるように
open my $fh, '>', "$dirname/data/$date";
### FILTER初期化
#print "*** DENY_FILTERをFlush(iptables -F DENY_FILTER)\n";
print $fh "$iptables -D INPUT -m conntrack --ctstate NEW -j DENY_FILTER\n";
print $fh "$iptables -F DENY_FILTER\n";
print $fh "$iptables -X DENY_FILTER\n";
print $fh "$iptables -N DENY_FILTER\n";
print $fh "$iptables -I INPUT 1 -m conntrack --ctstate NEW -j DENY_FILTER\n";

foreach $country (@all_country) {
    chomp($country);
    $filter_header = $country . '_DENY';
    print $fh "$iptables -F $filter_header\n";
    print $fh "$iptables -X $filter_header\n";
    print $fh "$iptables -N $filter_header\n";
    print $fh "$iptables -A $filter_header -j LOG --log-prefix='[$codehash{$country}] ' --log-level 5\n";
    print $fh "$iptables -A $filter_header -j DROP\n";
}
close $fh;

### aggregate
print "*** aggregate中 ***\n";
foreach $country (@deny_country) {
    chomp($country);
    print "$country($codehash{$country})\t";
    @aggregated = ();
    @aggregated = cidrs2cidrs(@{$addresses->{$country}});
    open my $fh, '>>', "$dirname/data/$date";
    $filter_header = $country . '_DENY';
    $count = scalar(@aggregated);
    print $fh "echo \"*** iptables 登録中: $country($codehash{$country}) $count address\"\n";
    foreach $line (@aggregated) {
	chomp($line);
	print $fh "$iptables -A DENY_FILTER -p tcp -s $line $limit -j $filter_header\n";
    }
    close $fh;
}
print "\n";

### FILTER更新
print "*** 新しいKRFILTERを登録\n";
#system("sudo /bin/sh $dirname/data/$date");
print "*** 完了\n";
