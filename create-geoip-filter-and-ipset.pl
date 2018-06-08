#!/usr/bin/perl

#use strict;
#use warnings;
use Net::Netmask;
use Net::IP;
use File::Basename;
use Data::Dumper;
$| = 1;

my $dirname = dirname(__FILE__);

# http://dev.maxmind.com/geoip/legacy/geolite/
$geoip_uri = 'http://geolite.maxmind.com/download/geoip/database/GeoIPCountryCSV.zip';

my $config;
my $conf_file = './config.ini';
if (-f "$conf_file") {
    print "read $conf_file\n";
    $config = do $conf_file or die "$!$@";
} else {
    print "Can't read config.ini\n";
    exit(1);
}

my $run_mode = $ARGV[0];

$iptables = $config->{iptables};
$limit = '-m multiport --dport ' . $config->{limit_port};
$allow_list = $config->{allow_country};
@allow_country = @$allow_list;

my @list_country = (
    "IS\tIceland", #アイスランド
    "IE\tIreland", #アイルランド
    "AZ\tAzerbaijan", #アゼルバイジャン
    "AF\tAfghanistan", #アフガニスタン
    "US\tUnited States", #アメリカ合衆国
    "VI\tVirgin Islands, U.S.", #アメリカ領ヴァージン諸島
    "AS\tAmerican Samoa", #アメリカ領サモア
    "AE\tUnited Arab Emirates", #アラブ首長国連邦
    "DZ\tAlgeria", #アルジェリア
    "AR\tArgentina", #アルゼンチン
    "AW\tAruba", #アルバ
    "AL\tAlbania", #アルバニア
    "AM\tArmenia", #アルメニア
    "AI\tAnguilla", #アンギラ
    "AO\tAngola", #アンゴラ
    "AG\tAntigua and Barbuda", #アンティグア・バーブーダ
    "AD\tAndorra", #アンドラ
    "YE\tYemen", #イエメン
    "GB\tUnited Kingdom", #イギリス
    "IO\tBritish Indian Ocean Territory", #イギリス領インド洋地域
    "VG\tVirgin Islands, British", #イギリス領ヴァージン諸島
    "IL\tIsrael", #イスラエル
    "IT\tItaly", #イタリア
    "IQ\tIraq", #イラク
    "IR\tIran, Islamic Republic of", #イラン・イスラム共和国
    "IN\tIndia", #インド
    "ID\tIndonesia", #インドネシア
    "WF\tWallis and Futuna", #ウォリス・フツナ
    "UG\tUganda", #ウガンダ
    "UA\tUkraine", #ウクライナ
    "UZ\tUzbekistan", #ウズベキスタン
    "UY\tUruguay", #ウルグアイ
    "EC\tEcuador", #エクアドル
    "EG\tEgypt", #エジプト
    "EE\tEstonia", #エストニア
    "ET\tEthiopia", #エチオピア
    "ER\tEritrea", #エリトリア
    "SV\tEl Salvador", #エルサルバドル
    "AU\tAustralia", #オーストラリア
    "AT\tAustria", #オーストリア
    "AX\tÅland Islands", #オーランド諸島
    "OM\tOman", #オマーン
    "NL\tNetherlands", #オランダ
    "GH\tGhana", #ガーナ
    "CV\tCape Verde", #カーボベルデ
    "GG\tGuernsey", #ガーンジー
    "GY\tGuyana", #ガイアナ
    "KZ\tKazakhstan", #カザフスタン
    "QA\tQatar", #カタール
    "UM\tUnited States Minor Outlying Islands", #合衆国領有小離島
    "CA\tCanada", #カナダ
    "GA\tGabon", #ガボン
    "CM\tCameroon", #カメルーン
    "GM\tGambia", #ガンビア
    "KH\tCambodia", #カンボジア
    "MP\tNorthern Mariana Islands", #北マリアナ諸島
    "GN\tGuinea", #ギニア
    "GW\tGuinea-Bissau", #ギニアビサウ
    "CY\tCyprus", #キプロス
    "CU\tCuba", #キューバ
    "CW\tCuraçao", #キュラソー
    "GR\tGreece", #ギリシャ
    "KI\tKiribati", #キリバス
    "KG\tKyrgyzstan", #キルギス
    "GT\tGuatemala", #グアテマラ
    "GP\tGuadeloupe", #グアドループ
    "GU\tGuam", #グアム
    "KW\tKuwait", #クウェート
    "CK\tCook Islands", #クック諸島
    "GL\tGreenland", #グリーンランド
    "CX\tChristmas Island", #クリスマス島
    "GD\tGrenada", #グレナダ
    "HR\tCroatia", #クロアチア
    "KY\tCayman Islands", #ケイマン諸島
    "KE\tKenya", #ケニア
    "CI\tCote dIvoire", #コートジボワール
    "CC\tCocos Keeling Islands", #ココス（キーリング）諸島
    "CR\tCosta Rica", #コスタリカ
    "KM\tComoros", #コモロ
    "CO\tColombia", #コロンビア
    "CG\tCongo", #コンゴ共和国
    "CD\tCongo, the Democratic Republic of the", #コンゴ民主共和国
    "SA\tSaudi Arabia", #サウジアラビア
    "GS\tSouth Georgia and the South Sandwich Islands", #サウスジョージア・サウスサンドウィッチ諸島
    "WS\tSamoa", #サモア
    "ST\tSao Tome and Principe", #サントメ・プリンシペ
    "BL\tSaint Barthélemy", #サン・バルテルミー
    "ZM\tZambia", #ザンビア
    "PM\tSaint Pierre and Miquelon", #サンピエール島・ミクロン島
    "SM\tSan Marino", #サンマリノ
    "MF\tSaint Martin French part", #サン・マルタン（フランス領）
    "SL\tSierra Leone", #シエラレオネ
    "DJ\tDjibouti", #ジブチ
    "GI\tGibraltar", #ジブラルタル
    "JE\tJersey", #ジャージー
    "JM\tJamaica", #ジャマイカ
    "GE\tGeorgia", #ジョージア
    "SY\tSyrian Arab Republic", #シリア・アラブ共和国
    "SG\tSingapore", #シンガポール
    "SX\tSint Maarten Dutch part", #シント・マールテン（オランダ領）
    "ZW\tZimbabwe", #ジンバブエ
    "CH\tSwitzerland", #スイス
    "SE\tSweden", #スウェーデン
    "SD\tSudan", #スーダン
    "SJ\tSvalbard and Jan Mayen", #スヴァールバル諸島およびヤンマイエン島
    "ES\tSpain", #スペイン
    "SR\tSuriname", #スリナム
    "LK\tSri Lanka", #スリランカ
    "SK\tSlovakia", #スロバキア
    "SI\tSlovenia", #スロベニア
    "SZ\tSwaziland", #スワジランド
    "SC\tSeychelles", #セーシェル
    "GQ\tEquatorial Guinea", #赤道ギニア
    "SN\tSenegal", #セネガル
    "RS\tSerbia", #セルビア
    "KN\tSaint Kitts and Nevis", #セントクリストファー・ネイビス
    "VC\tSaint Vincent and the Grenadines", #セントビンセントおよびグレナディーン諸島
    "SH\tSaint Helena, Ascension and Tristan da Cunha", #セントヘレナ・アセンションおよびトリスタンダクーニャ
    "LC\tSaint Lucia", #セントルシア
    "SO\tSomalia", #ソマリア
    "SB\tSolomon Islands", #ソロモン諸島
    "TC\tTurks and Caicos Islands", #タークス・カイコス諸島
    "TH\tThailand", #タイ
    "KR\tKorea, Republic of", #大韓民国
    "TW\tTaiwan, Province of China", #台湾
    "TJ\tTajikistan", #タジキスタン
    "TZ\tTanzania, United Republic of", #タンザニア
    "CZ\tCzechia", #チェコ
    "TD\tChad", #チャド
    "CF\tCentral African Republic", #中央アフリカ共和国
    "CN\tChina", #中華人民共和国
    "TN\tTunisia", #チュニジア
    "KP\tKorea, Democratic People's Republic of", #朝鮮民主主義人民共和国
    "CL\tChile", #チリ
    "TV\tTuvalu", #ツバル
    "DK\tDenmark", #デンマーク
    "DE\tGermany", #ドイツ
    "TG\tTogo", #トーゴ
    "TK\tTokelau", #トケラウ
    "DO\tDominican Republic", #ドミニカ共和国
    "DM\tDominica", #ドミニカ国
    "TT\tTrinidad and Tobago", #トリニダード・トバゴ
    "TM\tTurkmenistan", #トルクメニスタン
    "TR\tTurkey", #トルコ
    "TO\tTonga", #トンガ
    "NG\tNigeria", #ナイジェリア
    "NR\tNauru", #ナウル
    "NA\tNamibia", #ナミビア
    "AQ\tAntarctica", #南極
    "NU\tNiue", #ニウエ
    "NI\tNicaragua", #ニカラグア
    "NE\tNiger", #ニジェール
    "JP\tJapan", #日本
    "EH\tWestern Sahara", #西サハラ
    "NC\tNew Caledonia", #ニューカレドニア
    "NZ\tNew Zealand", #ニュージーランド
    "NP\tNepal", #ネパール
    "NF\tNorfolk Island", #ノーフォーク島
    "NO\tNorway", #ノルウェー
    "HM\tHeard Island and McDonald Islands", #ハード島とマクドナルド諸島
    "BH\tBahrain", #バーレーン
    "HT\tHaiti", #ハイチ
    "PK\tPakistan", #パキスタン
    "VA\tHoly See Vatican City State", #バチカン市国
    "PA\tPanama", #パナマ
    "VU\tVanuatu", #バヌアツ
    "BS\tBahamas", #バハマ
    "PG\tPapua New Guinea", #パプアニューギニア
    "BM\tBermuda", #バミューダ
    "PW\tPalau", #パラオ
    "PY\tParaguay", #パラグアイ
    "BB\tBarbados", #バルバドス
    "PS\tPalestinian Territory, Occupied", #パレスチナ
    "HU\tHungary", #ハンガリー
    "BD\tBangladesh", #バングラデシュ
    "TL\tTimor-Leste", #東ティモール
    "PN\tPitcairn", #ピトケアン
    "FJ\tFiji", #フィジー
    "PH\tPhilippines", #フィリピン
    "FI\tFinland", #フィンランド
    "BT\tBhutan", #ブータン
    "BV\tBouvet Island", #ブーベ島
    "PR\tPuerto Rico", #プエルトリコ
    "FO\tFaroe Islands", #フェロー諸島
    "FK\tFalkland Islands Malvinas", #フォークランド（マルビナス）諸島
    "BR\tBrazil", #ブラジル
    "FR\tFrance", #フランス
    "GF\tFrench Guiana", #フランス領ギアナ
    "PF\tFrench Polynesia", #フランス領ポリネシア
    "TF\tFrench Southern Territories", #Flag of the French Southern and Antarctic Lands.svg フランス領南方・南極地域
    "BG\tBulgaria", #ブルガリア
    "BF\tBurkina Faso", #ブルキナファソ
    "BN\tBrunei Darussalam", #ブルネイ・ダルサラーム
    "BI\tBurundi", #ブルンジ
    "VN\tViet Nam", #ベトナム
    "BJ\tBenin", #ベナン
    "VE\tVenezuela, Bolivarian Republic of", #ベネズエラ・ボリバル共和国
    "BY\tBelarus", #ベラルーシ
    "BZ\tBelize", #ベリーズ
    "PE\tPeru", #ペルー
    "BE\tBelgium", #ベルギー
    "PL\tPoland", #ポーランド
    "BA\tBosnia and Herzegovina", #ボスニア・ヘルツェゴビナ
    "BW\tBotswana", #ボツワナ
    "BQ\tBonaire, Saint Eustatius and Saba", #ボネール、シント・ユースタティウスおよびサバ
    "BO\tBolivia, Plurinational State of", #ボリビア多民族国
    "PT\tPortugal", #ポルトガル
    "HK\tHong Kong", #香港
    "HN\tHonduras", #ホンジュラス
    "MH\tMarshall Islands", #マーシャル諸島
    "MO\tMacau", #マカオ
    "MK\tMacedonia, the former Yugoslav Republic of", #マケドニア旧ユーゴスラビア共和国
    "MG\tMadagascar", #マダガスカル
    "YT\tMayotte", #マヨット
    "MW\tMalawi", #マラウイ
    "ML\tMali", #マリ
    "MT\tMalta", #マルタ
    "MQ\tMartinique", #マルティニーク
    "MY\tMalaysia", #マレーシア
    "IM\tIsle of Man", #マン島
    "FM\tMicronesia, Federated States of", #ミクロネシア連邦
    "ZA\tSouth Africa", #南アフリカ
    "SS\tSouth Sudan", #南スーダン
    "MM\tMyanmar", #ミャンマー
    "MX\tMexico", #メキシコ
    "MU\tMauritius", #モーリシャス
    "MR\tMauritania", #モーリタニア
    "MZ\tMozambique", #モザンビーク
    "MC\tMonaco", #モナコ
    "MV\tMaldives", #モルディブ
    "MD\tMoldova, Republic of", #モルドバ共和国
    "MA\tMorocco", #モロッコ
    "MN\tMongolia", #モンゴル
    "ME\tMontenegro", #モンテネグロ
    "MS\tMontserrat", #モントセラト
    "JO\tJordan", #ヨルダン
    "LA\tLao People's Democratic Republic", #ラオス人民民主共和国
    "LV\tLatvia", #ラトビア
    "LT\tLithuania", #リトアニア
    "LY\tLibya", #リビア
    "LI\tLiechtenstein", #リヒテンシュタイン
    "LR\tLiberia", #リベリア
    "RO\tRomania", #ルーマニア
    "LU\tLuxembourg", #ルクセンブルク
    "RW\tRwanda", #ルワンダ
    "LS\tLesotho", #レソト
    "LB\tLebanon", #レバノン
    "RE\tRéunion", #レユニオン
    "RU\tRussian Federation", #ロシア連邦
    "AP\tAsia Pacific region", 	#アジア太平洋地域に複数箇所にまたがる物
	"A1\tAnonymous Proxy",
	"A2\tSatellite Provider",
    );


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
    my ($code, $country) = split(/\t/, $list);
    my $allow = 0;
    foreach my $check (@$allow_list) {
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

foreach $line (@allow_country) {
	print "*** ALLOW Country: $line\n";
}
foreach $line (@deny_country) {
	print "*** DENY Country: $line\n";
}

print "*** download geoip database\n";

if (-f "$dirname/GeoIPCountryWhois.csv") {
    unlink("$dirname/GeoIPCountryWhois.csv");
}

$flag = 0;
$count = 0;
while($flag == 0) {
    $count++;
    `cd $dirname ; /usr/bin/curl -L -O $geoip_uri && /usr/bin/unzip $dirname/GeoIPCountryCSV.zip`;
    $exit_value = $? >> 8;
    if ($exit_value == 0) {
        $flag = 1;
    }
    if ($count > 10) {
        print "geoip download fail\n";
        exit(1);
    }
}

@all_list = `cat $dirname/GeoIPCountryWhois.csv`;


### アドレスブロックを整理
print "*** リストからアドレスを変換\n";

foreach $line (@all_list) {
    chomp($line);
    $line =~ s/\"//g;
    ($start, $end, $count1, $count2, $cc, $cc_desc) = split(/,/, $line);
    my $ip = new Net::IP("$start - $end");
    foreach $temp ($ip->find_prefixes()) {
        push @{$addresses->{$cc}}, Net::Netmask->new("$temp");
		$countries{$cc} = 1;
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
    $filter_header = $country . '_DENY';
    print $fh "echo \"*** FILTER初期化中: $codehash{$country}\"\n";
    print $fh "$iptables -F $filter_header\n";
    print $fh "$iptables -X $filter_header\n";
    print $fh "$iptables -N $filter_header\n";
    print $fh "$iptables -A $filter_header -j NFLOG --nflog-prefix=\"[DROP $codehash{$country}] \" --nflog-group 2\n";
    print $fh "$iptables -A $filter_header -j DROP\n";
    print $fh "$iptables -A DENY_FILTER -p tcp -m set --match-set $country src $limit -j $filter_header\n";
}
foreach $country (@allow_country) {
    chomp($country);
    $filter_header = $country . '_ALLOW';
    print $fh "echo \"*** FILTER初期化中: $codehash{$country}\"\n";
    print $fh "$iptables -F $filter_header\n";
    print $fh "$iptables -X $filter_header\n";
    print $fh "$iptables -N $filter_header\n";
    print $fh "$iptables -A $filter_header -j NFLOG --nflog-prefix=\"[ACCEPT $codehash{$country}] \" --nflog-group 2\n";
    print $fh "$iptables -A $filter_header -j ACCEPT\n";
    print $fh "$iptables -A DENY_FILTER -p tcp -m set --match-set $country src $limit -j $filter_header\n";
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

    print $fh "ipset create -exist $country-temp hash:net\n";
    print $fh "ipset flush $country-temp\n";

    foreach $line (@aggregated) {
        chomp($line);
        $count2++;
        #print $fh "$iptables -w -A DENY_FILTER -p tcp -s $line $limit -j $filter_header\n";
        #print $fh "$iptables -A DENY_FILTER -p tcp -s $line $limit -j $filter_header\n";
        print $fh "ipset add $country-temp $line\n";
        print $fh "printf \"%6d/%6d\" $count2 $count\n";
        print $fh "echo -ne '\b\b\b\b\b\b\b\b\b\b\b\b\b'\n";
    }
    print $fh "ipset list $country > /dev/null 2>&1\n";
    print $fh 'if [ $? -eq 0 ]; then' . "\n";
    print $fh "  ipset swap $country-temp $country\n";
    print $fh "else\n";
    print $fh "  ipset rename $country-temp $country\n";
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
    system("sudo /bin/sh -c "$dirname/data/$year/$date-update-ipset && ipset save > /etc/ipset.conf");
    exit(0);
}

### FILTER更新
print "*** 新しいKRFILTERを登録\n";
#system("sudo /bin/sh $dirname/data/$date");
print "# for initial\n";
print "please run 'sudo /bin/sh $dirname/data/$year/$date-iptables'\n";
print "# for iplist update only\n";
print "please run 'sudo /bin/sh -c "$dirname/data/$year/$date-update-ipset && ipset save > /etc/ipset.conf"'\n";
print "*** 完了\n";
