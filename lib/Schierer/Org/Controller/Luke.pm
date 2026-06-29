package Schierer::Org::Controller::Luke;
# cspell: disable

use v5.42.0;
use utf8::all;
use Mooish::Base -standard;
extends 'WebFramework::Controller::Base';

use Future::AsyncAwait;
require Path::Tiny;
require Path::Iterator::Rule;
require JSON::MaybeXS;
require POSIX;
require DateTime;
require Data::Printer;
require MIME::Types;
require Schierer::Org::Model::TimelineData;
require Schierer::Org::View::Timeline;

has luke_dir => (
  is      => 'ro',
  default => sub {
    my $self = shift;
    my $dir  = $self->app_config->{config}->{luke_content_dir}
      // 'packages/luke';
    return Path::Tiny::path($dir);
  },
);

has redirect_map => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self   = shift;
    my $file   = $self->luke_dir->child('build-output/redirects.json');
    my $static = {
      '/~luke/log/20090724'               => '/~luke/log/arcive/2009/07/24',
      '/~luke/log/20100205'               => '/~luke/log/arcive/2010/02/05',
      '/~luke/log/20050208/20050208-1101' =>
        '/~luke/log/science/prolife_science/',
      '/~luke/log/20050603/20050603-1424' =>
        '/~luke/log/Society/homosexuality/',
      '/~luke/log/20050607/20050607-1002' => '/~luke/log/Society/usury/',
      '/~luke/log/20050608/20050608-1129' =>
        '/~luke/log/Politics_And_Law/Public_Schooling/',
      '/~luke/log/20050610/20050610-1530' =>
        '/~luke/log/Politics_And_Law/Our_Government_Is_Unlimited',
      '/~luke/log/20050610/20050610-1628' => '/~luke/log/science/Trust/',
      '/~luke/log/20050615/20050615-1338' =>
        '/~luke/log/Politics_And_Law/Public_Schooling/',
      '/~luke/log/fiction/Harry_Potter/Nineteen_Missing_Years' =>
        'https://hp-fan.schierer.org/Harrypedia/Nineteen%20Missing%20Years',
      '/~luke/log/fiction/Harry_Potter/Nineteen_Missing_Years/Harry_and_Ginny'
        => 'https://hp-fan.schierer.org/Harrypedia/Nineteen Missing Years/Harry and Ginny',
'/~luke/log/fiction/Harry_Potter/Nineteen_Missing_Years/Changes_to_Hogwarts'
        => 'https://hp-fan.schierer.org/Harrypedia/Nineteen Missing Years/Changes to Hogwarts',
      '/~luke/log/fiction/Harry_Potter/Family_Inseparable' =>
        'https://hp-fan.schierer.org/Fan Fiction/Family Inseparable',
      '/~luke/log/fiction/Harry_Potter/Family_Inseparable/Chapter01' =>
        'https://hp-fan.schierer.org/Fan Fiction/Family Inseparable/Chapter01',
      '/~luke/log/fiction/Harry_Potter/Family_Inseparable/Chapter02' =>
        'https://hp-fan.schierer.org/Fan Fiction/Family Inseparable/Chapter01',
      '/~luke/log/fiction/Harry_Potter/Family_Inseparable/Chapter03' =>
        'https://hp-fan.schierer.org/Fan Fiction/Family Inseparable/Chapter01',
      '/~luke/log/fiction/Harry_Potter/Family_Inseparable/Chapter04' =>
        'https://hp-fan.schierer.org/Fan Fiction/Family Inseparable/Chapter01',
      '/~luke/log/fiction/Harry_Potter/Family_Inseparable/Chapter05' =>
        'https://hp-fan.schierer.org/Fan Fiction/Family Inseparable/Chapter01',
      '/~luke/log/fiction/Harry_Potter/Family_Inseparable/Chapter06' =>
        'https://hp-fan.schierer.org/Fan Fiction/Family Inseparable/Chapter01',
      '/~luke/log/fiction/Harry_Potter/Family_Inseparable/Chapter07' =>
        'https://hp-fan.schierer.org/Fan Fiction/Family Inseparable/Chapter01',
      '/~luke/log/fiction/Harry_Potter/Family_Inseparable/Chapter08' =>
        'https://hp-fan.schierer.org/Fan Fiction/Family Inseparable/Chapter01',
      '/~luke/log/fiction/Harry_Potter/Family_Inseparable/Chapter09' =>
        'https://hp-fan.schierer.org/Fan Fiction/Family Inseparable/Chapter01',
      '/~luke/log/fiction/Harry_Potter/Family_Inseparable/Chapter10' =>
        'https://hp-fan.schierer.org/Fan Fiction/Family Inseparable/Chapter01',
      '/~luke/log/fiction/Harry_Potter/Family_Inseparable/Notes' =>
        'https://hp-fan.schierer.org/Fan Fiction/Family Inseparable/Notes',
      '/~luke/log/fiction/Harry_Potter/Not_Normal' =>
        'https://hp-fan.schierer.org/Fan Fiction/Not Normal',
    };
    return $static unless $file->exists;
    my $json    = JSON::MaybeXS->new(utf8 => 1);
    my $dynamic = $json->decode($file->slurp_raw);
    return { $static->%*, $dynamic->%*, };
  },
);

has timeline_data => (
  is      => 'lazy',
  default => sub {
    my $self = shift;

    my $data_file =
      $self->luke_dir->child('log/apologetics/history/timeline_data.yaml');

    return Schierer::Org::Model::TimelineData->new(
      data_file => $data_file->stringify,);
  }
);

has date_manifest => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;
    my $file = $self->luke_dir->child('build-output/dates.json');
    return {} unless $file->exists;
    my $json = JSON::MaybeXS->new(utf8 => 1);
    return $json->decode($file->slurp_raw);
  },
);

has recent_changes => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;
    my $file = $self->luke_dir->child('build-output/commitHistory.json');
    return [] unless $file->exists;
    my $json = JSON::MaybeXS->new(utf8 => 1);
    return $json->decode($file->slurp_raw);
  },
);

has googleStream => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;
    return unless $self->app->env eq 'production';
    return qq{
      <!-- Google tag (gtag.js) -->
      <script async src="https://www.googletagmanager.com/gtag/js?id=G-Y3WJYW9RQ1"></script>
      <script>
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());

        gtag('config', 'G-Y3WJYW9RQ1');
      </script>
    };
  }
);

has autoindex_dirs => (
  is      => 'ro',
  default => sub {
    return {
      '20050129'             => '20050129',
      '20050130'             => '20050130',
      '20050131'             => '20050131',
      '20050201'             => '20050201',
      '20050202'             => '20050202',
      '20050203'             => '20050203',
      '20050204'             => '20050204',
      '20050207'             => '20050207',
      '20050208'             => '20050208',
      '20050209'             => '20050209',
      '20050210'             => '20050210',
      '20050211'             => '20050211',
      '20050214'             => '20050214',
      '20050215'             => '20050215',
      '20050216'             => '20050216',
      '20050217'             => '20050217',
      '20050218'             => '20050218',
      '20050221'             => '20050221',
      '20050222'             => '20050222',
      '20050223'             => '20050223',
      '20050224'             => '20050224',
      '20050225'             => '20050225',
      '20050226'             => '20050226',
      '20050301'             => '20050301',
      '20050302'             => '20050302',
      '20050303'             => '20050303',
      '20050304'             => '20050304',
      '20050307'             => '20050307',
      '20050308'             => '20050308',
      '20050309'             => '20050309',
      '20050310'             => '20050310',
      '20050311'             => '20050311',
      '20050315'             => '20050315',
      '20050316'             => '20050316',
      '20050317'             => '20050317',
      '20050318'             => '20050318',
      '20050321'             => '20050321',
      '20050322'             => '20050322',
      '20050323'             => '20050323',
      '20050324'             => '20050324',
      '20050325'             => '20050325',
      '20050326'             => '20050326',
      '20050328'             => '20050328',
      '20050329'             => '20050329',
      '20050330'             => '20050330',
      '20050331'             => '20050331',
      '20050401'             => '20050401',
      '20050404'             => '20050404',
      '20050405'             => '20050405',
      '20050406'             => '20050406',
      '20050407'             => '20050407',
      '20050408'             => '20050408',
      '20050410'             => '20050410',
      '20050411'             => '20050411',
      '20050412'             => '20050412',
      '20050413'             => '20050413',
      '20050414'             => '20050414',
      '20050415'             => '20050415',
      '20050417'             => '20050417',
      '20050418'             => '20050418',
      '20050419'             => '20050419',
      '20050420'             => '20050420',
      '20050421'             => '20050421',
      '20050422'             => '20050422',
      '20050424'             => '20050424',
      '20050425'             => '20050425',
      '20050426'             => '20050426',
      '20050427'             => '20050427',
      '20050428'             => '20050428',
      '20050429'             => '20050429',
      '20050502'             => '20050502',
      '20050503'             => '20050503',
      '20050504'             => '20050504',
      '20050505'             => '20050505',
      '20050506'             => '20050506',
      '20050508'             => '20050508',
      '20050509'             => '20050509',
      '20050510'             => '20050510',
      '20050511'             => '20050511',
      '20050512'             => '20050512',
      '20050513'             => '20050513',
      '20050516'             => '20050516',
      '20050517'             => '20050517',
      '20050518'             => '20050518',
      '20050519'             => '20050519',
      '20050520'             => '20050520',
      '20050523'             => '20050523',
      '20050525'             => '20050525',
      '20050526'             => '20050526',
      '20050531'             => '20050531',
      '20050601'             => '20050601',
      '20050602'             => '20050602',
      '20050603'             => '20050603',
      '20050606'             => '20050606',
      '20050607'             => '20050607',
      '20050608'             => '20050608',
      '20050609'             => '20050609',
      '20050610'             => '20050610',
      '20050613'             => '20050613',
      '20050614'             => '20050614',
      '20050615'             => '20050615',
      '20050616'             => '20050616',
      '20050617'             => '20050617',
      '20050618'             => '20050618',
      '20050620'             => '20050620',
      '20050621'             => '20050621',
      '20050624'             => '20050624',
      '20050627'             => '20050627',
      '20050628'             => '20050628',
      '20050629'             => '20050629',
      '20050630'             => '20050630',
      '20050701'             => '20050701',
      '20050705'             => '20050705',
      '20050706'             => '20050706',
      '20050707'             => '20050707',
      '20050708'             => '20050708',
      '20050710'             => '20050710',
      '20050711'             => '20050711',
      '20050712'             => '20050712',
      '20050713'             => '20050713',
      '20050714'             => '20050714',
      '20050715'             => '20050715',
      '20050720'             => '20050720',
      '20050723'             => '20050723',
      '20050724'             => '20050724',
      '20050803'             => '20050803',
      '20050804'             => '20050804',
      '20050805'             => '20050805',
      '20050808'             => '20050808',
      '20050809'             => '20050809',
      '20050810'             => '20050810',
      '20050811'             => '20050811',
      '20050812'             => '20050812',
      '20050815'             => '20050815',
      '20050817'             => '20050817',
      '20050818'             => '20050818',
      '20050819'             => '20050819',
      '20050822'             => '20050822',
      '20050823'             => '20050823',
      '20050824'             => '20050824',
      '20050826'             => '20050826',
      '20050829'             => '20050829',
      '20050830'             => '20050830',
      '20050901'             => '20050901',
      '20050902'             => '20050902',
      '20050906'             => '20050906',
      '20050907'             => '20050907',
      '20050908'             => '20050908',
      '20050912'             => '20050912',
      '20050914'             => '20050914',
      '20050915'             => '20050915',
      '20050916'             => '20050916',
      '20050919'             => '20050919',
      '20050920'             => '20050920',
      '20050921'             => '20050921',
      '20050922'             => '20050922',
      '20050923'             => '20050923',
      '20050926'             => '20050926',
      '20050929'             => '20050929',
      '20050930'             => '20050930',
      '20051003'             => '20051003',
      '20051005'             => '20051005',
      '20051006'             => '20051006',
      '20051007'             => '20051007',
      '20051010'             => '20051010',
      '20051011'             => '20051011',
      '20051012'             => '20051012',
      '20051015'             => '20051015',
      '20051018'             => '20051018',
      '20051020'             => '20051020',
      '20051028'             => '20051028',
      '20051031'             => '20051031',
      '20051102'             => '20051102',
      '20051103'             => '20051103',
      '20051106'             => '20051106',
      '20051108'             => '20051108',
      '20051110'             => '20051110',
      '20051111'             => '20051111',
      '20051114'             => '20051114',
      '20051115'             => '20051115',
      '20051116'             => '20051116',
      '20051121'             => '20051121',
      '20051122'             => '20051122',
      '20051123'             => '20051123',
      '20051213'             => '20051213',
      '20051225'             => '20051225',
      '20051228'             => '20051228',
      '20060105'             => '20060105',
      '20060110'             => '20060110',
      '20060111'             => '20060111',
      '20060112'             => '20060112',
      '20060113'             => '20060113',
      '20060117'             => '20060117',
      '20060118'             => '20060118',
      '20060119'             => '20060119',
      '20060120'             => '20060120',
      '20060123'             => '20060123',
      '20060124'             => '20060124',
      '20060125'             => '20060125',
      '20060126'             => '20060126',
      '20060130'             => '20060130',
      '20060203'             => '20060203',
      '20060206'             => '20060206',
      '20060207'             => '20060207',
      '20060208'             => '20060208',
      '20060209'             => '20060209',
      '20060213'             => '20060213',
      '20060214'             => '20060214',
      '20060215'             => '20060215',
      '20060217'             => '20060217',
      '20060221'             => '20060221',
      '20060223'             => '20060223',
      '20060227'             => '20060227',
      '20060303'             => '20060303',
      '20060306'             => '20060306',
      '20060307'             => '20060307',
      '20060308'             => '20060308',
      '20060310'             => '20060310',
      '20060315'             => '20060315',
      '20060321'             => '20060321',
      '20060322'             => '20060322',
      '20060418'             => '20060418',
      '20060509'             => '20060509',
      '20060516'             => '20060516',
      '20060606'             => '20060606',
      '20060630'             => '20060630',
      '20060703'             => '20060703',
      '20060705'             => '20060705',
      '20060709'             => '20060709',
      '20060711'             => '20060711',
      '20060712'             => '20060712',
      '20060713'             => '20060713',
      '20060718'             => '20060718',
      '20060720'             => '20060720',
      '20060721'             => '20060721',
      '20060727'             => '20060727',
      '20060803'             => '20060803',
      '20060804'             => '20060804',
      '20060807'             => '20060807',
      '20060808'             => '20060808',
      '20060809'             => '20060809',
      '20060810'             => '20060810',
      '20060811'             => '20060811',
      '20060821'             => '20060821',
      '20060825'             => '20060825',
      '20060828'             => '20060828',
      '20060829'             => '20060829',
      '20060830'             => '20060830',
      '20060902'             => '20060902',
      '20060905'             => '20060905',
      '20060906'             => '20060906',
      '20060907'             => '20060907',
      '20060911'             => '20060911',
      '20060912'             => '20060912',
      '20060913'             => '20060913',
      '20060914'             => '20060914',
      '20060915'             => '20060915',
      '20060918'             => '20060918',
      '20060919'             => '20060919',
      '20060922'             => '20060922',
      '20060925'             => '20060925',
      '20060926'             => '20060926',
      '20060927'             => '20060927',
      '20060928'             => '20060928',
      '20061002'             => '20061002',
      '20061003'             => '20061003',
      '20061004'             => '20061004',
      '20061005'             => '20061005',
      '20061006'             => '20061006',
      '20061009'             => '20061009',
      '20061011'             => '20061011',
      '20061012'             => '20061012',
      '20061013'             => '20061013',
      '20061016'             => '20061016',
      '20061017'             => '20061017',
      '20061018'             => '20061018',
      '20061019'             => '20061019',
      '20061024'             => '20061024',
      '20061025'             => '20061025',
      '20061030'             => '20061030',
      '20061031'             => '20061031',
      '20061106'             => '20061106',
      '20061107'             => '20061107',
      '20061108'             => '20061108',
      '20061109'             => '20061109',
      '20061113'             => '20061113',
      '20061115'             => '20061115',
      '20061117'             => '20061117',
      '20061128'             => '20061128',
      '20061130'             => '20061130',
      '20061206'             => '20061206',
      '20061207'             => '20061207',
      '20061208'             => '20061208',
      '20061211'             => '20061211',
      '20061218'             => '20061218',
      '20061221'             => '20061221',
      '20061227'             => '20061227',
      '20061228'             => '20061228',
      '20070102'             => '20070102',
      '20070103'             => '20070103',
      '20070108'             => '20070108',
      '20070110'             => '20070110',
      '20070116'             => '20070116',
      '20070118'             => '20070118',
      '20070124'             => '20070124',
      '20070126'             => '20070126',
      '20070205'             => '20070205',
      '20070206'             => '20070206',
      '20070212'             => '20070212',
      '20070215'             => '20070215',
      '20070219'             => '20070219',
      '20070220'             => '20070220',
      '20070222'             => '20070222',
      '20070223'             => '20070223',
      '20070227'             => '20070227',
      '20070228'             => '20070228',
      '20070301'             => '20070301',
      '20070313'             => '20070313',
      '20070319'             => '20070319',
      '20070321'             => '20070321',
      '20070329'             => '20070329',
      '20070331'             => '20070331',
      '20070402'             => '20070402',
      '20070404'             => '20070404',
      '20070407'             => '20070407',
      '20070415'             => '20070415',
      '20070417'             => '20070417',
      '20070418'             => '20070418',
      '20070423'             => '20070423',
      '20070424'             => '20070424',
      '20070425'             => '20070425',
      '20070426'             => '20070426',
      '20070430'             => '20070430',
      '20070502'             => '20070502',
      '20070510'             => '20070510',
      '20070517'             => '20070517',
      '20070529'             => '20070529',
      '20070604'             => '20070604',
      '20070606'             => '20070606',
      '20070608'             => '20070608',
      '20070614'             => '20070614',
      '20070615'             => '20070615',
      '20070618'             => '20070618',
      '20070621'             => '20070621',
      '20070625'             => '20070625',
      '20070627'             => '20070627',
      '20070709'             => '20070709',
      '20070710'             => '20070710',
      '20070711'             => '20070711',
      '20070712'             => '20070712',
      '20070719'             => '20070719',
      '20070723'             => '20070723',
      '20070724'             => '20070724',
      '20070726'             => '20070726',
      '20070727'             => '20070727',
      '20070730'             => '20070730',
      '20070802'             => '20070802',
      '20070803'             => '20070803',
      '20070804'             => '20070804',
      '20070809'             => '20070809',
      '20070810'             => '20070810',
      '20070813'             => '20070813',
      '20070815'             => '20070815',
      '20070818'             => '20070818',
      '20070821'             => '20070821',
      '20070830'             => '20070830',
      '20070831'             => '20070831',
      '20070904'             => '20070904',
      '20070905'             => '20070905',
      '20070907'             => '20070907',
      '20070912'             => '20070912',
      '20070917'             => '20070917',
      '20070918'             => '20070918',
      '20070919'             => '20070919',
      '20070923'             => '20070923',
      '20071002'             => '20071002',
      '20071003'             => '20071003',
      '20071008'             => '20071008',
      '20071010'             => '20071010',
      '20071015'             => '20071015',
      '20071018'             => '20071018',
      '20071030'             => '20071030',
      '20071101'             => '20071101',
      '20071107'             => '20071107',
      '20071108'             => '20071108',
      '20071119'             => '20071119',
      '20071126'             => '20071126',
      '20071127'             => '20071127',
      '20071130'             => '20071130',
      '20071203'             => '20071203',
      '20071206'             => '20071206',
      '20071207'             => '20071207',
      '20071217'             => '20071217',
      '20080114'             => '20080114',
      '20080122'             => '20080122',
      '20080123'             => '20080123',
      '20080125'             => '20080125',
      '20080201'             => '20080201',
      '20080206'             => '20080206',
      '20080207'             => '20080207',
      '20080208'             => '20080208',
      '20080211'             => '20080211',
      '20080220'             => '20080220',
      '20080222'             => '20080222',
      '20080225'             => '20080225',
      '20080303'             => '20080303',
      '20080306'             => '20080306',
      '20080317'             => '20080317',
      '20080319'             => '20080319',
      '20080331'             => '20080331',
      '20080418'             => '20080418',
      '20080524'             => '20080524',
      '20080616'             => '20080616',
      '20080910'             => '20080910',
      '20080911'             => '20080911',
      '20080916'             => '20080916',
      '20080919'             => '20080919',
      '20080927'             => '20080927',
      '20081002'             => '20081002',
      '20081007'             => '20081007',
      '20081114'             => '20081114',
      '20081210'             => '20081210',
      '20081219'             => '20081219',
      '20090103'             => '20090103',
      '20090111'             => '20090111',
      '20090114'             => '20090114',
      '20090214'             => '20090214',
      '20090216'             => '20090216',
      '20090222'             => '20090222',
      '20090301'             => '20090301',
      '20090303'             => '20090303',
      '20090401'             => '20090401',
      '20090404'             => '20090404',
      '20090416'             => '20090416',
      '20090503'             => '20090503',
      '20090530'             => '20090530',
      '20090705'             => '20090705',
      '20090714'             => '20090714',
      '20090719'             => '20090719',
      '20090724'             => '20090724',
      '20090730'             => '20090730',
      '20090829'             => '20090829',
      'Politics_And_Law'     => 'Politics and Law',
      'Society'              => 'Society',
      'apologetics'          => 'Apologetics',
      'apologetics/history'  => 'Church/Apologetics Related History',
      'fiction'              => 'Fiction',
      'fiction/Harry_Potter' => 'Harry Potter',
      'healthcare'           => 'Health Care',
      'healthcare/obamacare' => 'Obamacare',
      'history'              => 'History',
      'quotes'               => 'Noteworthy Quotes',
      'science'              => 'Science',
    };
  },
);

sub build ($self) {
  $self->logger->info(sprintf('build method for "%s"', __PACKAGE__));

  $self->_register_redirects();
  $self->_register_static_files();
  $self->_register_markdown_routes();
  $self->_register_autoindex_routes();
  $self->_register_timeline_route();

  $self->add_navigation_route('/~luke', 'Luke Schierer');

  # Add index route for /~luke and /~luke/
  $self->router->add(
    '/~luke',
    {
      to => async sub ($c, $ctx, @args) {
        my $index_file = $self->luke_dir->child('index.html');
        if ($index_file->exists) {
          return $ctx->res->send_file($index_file->stringify,
            inline => 1);
        }
        $index_file = $self->luke_dir->child('index.md');
        if ($index_file->exists) {
          my $entry = {
            route => $ctx->req->path,
            path  => $index_file,
          };
          return await $self->_handle_markdown($ctx, $entry);
        }

        $ctx->res->redirect('/~luke/log/', 302);
        return;
      },
      action => 'http.*',
    }
  );

  $self->add_navigation_route('/~luke/log', 'Random Unfinished Thoughts');
  $self->router->add(
    '/~luke/log',
    {
      to => async sub ($c, $ctx, @args) {
        my $index_file = $self->luke_dir->child('log/index.html');
        if ($index_file->exists) {
          return $ctx->res->send_file($index_file->stringify,
            inline => 1);
        }
        $index_file = $self->luke_dir->child('log/index.md');
        if ($index_file->exists) {
          my $entry = {
            route => $ctx->req->path,
            path  => $index_file,
          };
          return await $self->_handle_markdown($ctx, $entry);
        }

        return;
      },
      action => 'http.*',
    }
  );

  my $static_assets_rule = Path::Iterator::Rule->new;
  $static_assets_rule->nonempty->file->name(qr/\.(?:png|svg|jpg|gif)$/);
  my $iter = $static_assets_rule->iter($self->luke_dir->child('assets'),
    { sorted => 1 });
  $self->_register_routes_from_iterator(
    $iter, 'assets',
    sub { shift->_static_handler(@_) },
    { no_sitemap => 1 }
  );

  my $css_rule = Path::Iterator::Rule->new;
  $css_rule->nonempty->file->name(qr/\.css$/);
  $iter = $css_rule->iter($self->luke_dir->child('build-output/styles'),
    { sorted => 1 });
  $self->_register_routes_from_iterator(
    $iter, 'build-output/styles',
    sub { shift->_static_handler(@_) },
    { no_sitemap => 1 }
  );

  my $node_rule = Path::Iterator::Rule->new;
  $node_rule->nonempty->file;
  $iter =
    $node_rule->iter($self->luke_dir->child('node_modules'), { sorted => 1 });
  $self->_register_routes_from_iterator(
    $iter, 'node_modules',
    sub { shift->_static_handler(@_) },
    { no_sitemap => 1 }
  );

  my $log_images = Path::Iterator::Rule->new;
  $log_images->nonempty->file->name(qr/\.(?:svg|png|gif|jpg)$/);
  $iter = $log_images->iter($self->luke_dir->child('log'), { sorted => 1 });
  $self->_register_routes_from_iterator(
    $iter, 'log',
    sub { shift->_static_handler(@_) },
    { no_sitemap => 1 }
  );

}

sub _register_timeline_route ($self) {
  my $route = '/~luke/log/apologetics/history/TimelineOfErrors';

  $self->add_navigation_route($route, 'Timeline of Errors');

  $self->router->add(
    $route,
    {
      to     => '_timeline_handler',
      action => 'http.get',
    }
  );

  $self->logger->info("Registered timeline route: $route");
}

async sub _timeline_handler ($c, $ctx, @args) {
  my $view = Schierer::Org::View::Timeline->new(data => $c->timeline_data);
  my $svg  = $view->create();

  my $undated =
    [grep { !defined $_->{date} } @{ $c->timeline_data->sorted_entities }];

  my $current_path    = $ctx->req->path;
  my $navigation_html = $c->render_navigation($current_path);

  my $vars = {
    title           => 'Timeline of Errors',
    svg             => $svg,
    css_files       => ['/~luke/styles/apologetics/history/TimelineOfErrors.css'],
    undated         => $undated,
    layout          => 'luke_rut',
    sidebar         => 1,
    nav_html        => $navigation_html,
    google          => $c->googleStream(),
    calendar_widget => $c->_get_current_calendar(),
    archive_years   => $c->_get_archive_years(),
    tag_list        => $c->_get_tag_list(),
  };

  my $html = $c->template('luke/timeline_of_errors', $vars);
  $ctx->res->html($html);
}

sub _register_redirects ($self) {
  my $map   = $self->redirect_map;
  my $count = 0;

  for my $source (keys %$map) {
    my $target = $map->{$source};

    $self->router->add(
      $source,
      {
        to => async sub ($c, $ctx, @args) {
          $ctx->res->redirect($target, 308);
          return;
        },
        action => 'http.*',
      }
    );
    $count++;
  }

  $self->logger->info("Registered $count ~luke redirect routes");
}

sub _register_routes_from_iterator ($self, $iterator, $base_path, $handler,
  $opts = {}) {
  my $count              = 0;
  my $strip_md           = $opts->{strip_md}       // 0;
  my $add_trailing_slash = $opts->{trailing_slash} // 0;
  my $no_sitemap         = $opts->{no_sitemap}     // 0;
  my $extract_title      = $opts->{extract_title}  // 0;

  while (defined(my $file = $iterator->())) {
    $file = Path::Tiny::path($file);

    my $rel = $file->relative($self->luke_dir->child($base_path))->stringify;
    $rel =~ s/\.md$// if $strip_md;         # Only remove .md if requested
    my $route = "/~luke/$base_path/$rel";
    $route =~ s{//+}{/}g;
    $route =~ s{/index$}{} if $strip_md;    # Only strip index for markdown
    $route .= '/'
      if $add_trailing_slash
      && $route !~ m{/$};                   # Add trailing slash if requested

    #special cases
    $route =~ s{luke/build-output/}{luke/};

    $self->logger->debug(
      sprintf('registering route "%s" from base_path "%s"', $route, $base_path)
    );

    if ($route !~ /node_module/) {
      my $title = '';
      if ($extract_title && $file->stringify =~ /\.md$/) {
        my $fm = $self->parse_markdown_frontmatter($file);
        $title = $fm->{title} // '';
      }
      # Derive title from path if still empty
      if (!$title) {
        $title = $file->basename(qr/\.md$/);
        $title =~ s/_/ /g;
        $title =~ s/\b(\w)/\U$1/g;
      }
      my %nav_opts;
      $nav_opts{no_sitemap} = 1 if $no_sitemap;
      $self->add_navigation_route($route, $title, \%nav_opts);
    }

    $self->router->add(
      $route,
      {
        to => async sub ($c, $ctx, @args) {
          await $handler->($self, $ctx, $file, $route);
        },
        action => 'http.get',
      }
    );
    $count++;
  }

  return $count;
}

async sub _markdown_handler ($self, $ctx, $file, $route) {
  my $entry = {
    path         => $file->stringify,
    route        => $route,
    manifest_key => $file->relative($self->luke_dir)->stringify =~ s/\.md$//r,
  };
  return await $self->_handle_markdown($ctx, $entry);
}

async sub _static_handler ($self, $ctx, $file, $route) {
  $self->logger->debug(sprintf(
    'serving "%s" for route "%s"',
    $file->exists ? $file : "no such file", $route
  ));
  my $mts = MIME::Types->new();
  my $type = $mts->mimeTypeOf($file);
  $ctx->res->content_type($type) unless not defined($type);
  $self->logger->debug(sprintf('using %s as mimetype for file "%s"', defined($type) ? $type : 'undef', $file));
  $ctx->res->send_file($file->stringify, inline => 1);
  return;
}

sub _register_static_files ($self) {
  my $luke_dir = $self->luke_dir;
  my $count    = 0;

  # Register routes for static files at the luke root (*.html, *.pdf, *.txt)
  my $rule = Path::Iterator::Rule->new;
  my $next = $rule->file->nonempty->name(qr/\.(html|pdf|txt)$/)->iter(
    $luke_dir->stringify,
    {
      depthfirst      => -1,
      follow_symlinks =>  0,
      sorted          =>  1,
    }
  );

  while (defined(my $file = $next->())) {
    $file = Path::Tiny::path($file);

    # Only root-level files, not files under log/
    next if $file->relative($luke_dir) =~ m{^log/};
    next if $file->relative($luke_dir) =~ m{^build-output/};
    next if $file->relative($luke_dir) =~ m{^node_modules/};

    my $rel   = $file->relative($luke_dir)->stringify;
    my $route = "/~luke/$rel";
    $self->add_navigation_route($route, '', { no_sitemap => 1 });

    $self->logger->debug(sprintf('registering static file route "%s"', $route));
    my $file_copy = $file;    # Capture for closure
    $self->router->add(
      $route,
      {
        to => async sub ($c, $ctx, @args) {
          await $self->_static_handler($ctx, $file_copy, $route);
        },
        action => 'http.get',
      }
    );
    $count++;
  }

  $self->logger->info("Registered $count ~luke static file routes");
}

sub _register_markdown_routes ($self) {
  my $log_dir = $self->luke_dir->child('log');

  my $rule = Path::Iterator::Rule->new;
  $rule->file->nonempty->name(qr/\.md$/);

  my $iter = $rule->iter(
    $log_dir,
    {
      depthfirst      => -1,
      follow_symlinks =>  0,
      sorted          =>  1,
    }
  );

  my $count = $self->_register_routes_from_iterator(
    $iter,
    $log_dir->relative($self->luke_dir),
    sub { shift->_markdown_handler(@_) },
    { strip_md => 1, extract_title => 1 }
  );

  $self->logger->info("Registered $count markdown routes");
}

sub _register_autoindex_routes ($self) {
  my $dirs    = $self->autoindex_dirs;
  my $log_dir = $self->luke_dir->child('log');
  my $count   = 0;

  foreach my $path (keys $self->autoindex_dirs->%*) {
    my $route = "/~luke/log/$path";
    my $title = $self->autoindex_dirs->{$path};

    my $log_dir = $self->luke_dir->child('log');
    my $dir     = $log_dir->child($path);
    if ($dir->is_dir) {
      my $entries = $self->generate_directory_index($dir);
      foreach my $entry ($entries->@*) {
        $self->logger->debug("repairing entry: " . Data::Printer::np($entry));
        $entry->{path} =~ s{^/\.\./\.\./packages/luke/(.+)$}{/~luke/$1};
        $self->logger->debug("repaired path is: " . $entry->{path});
      }

      $self->add_navigation_route($route, $title);
      $self->router->add(
        $route,
        {
          to => async sub ($c, $ctx, @args) {
            my $extra_vars = {
              title           => $title,
              entries         => $entries,
              layout          => 'luke_rut',
              calendar_widget => $self->_get_current_calendar(),
              archive_years   => $self->_get_archive_years(),
              tag_list        => $self->_get_tag_list(),
              google          => $self->googleStream(),
            };
            my $html = $self->template('luke/autoindex', $extra_vars);
            $ctx->res->html($html);
          },
          action => 'http.get',
        }
      );
      $count++;
    }
    else {
      $self->logger->warn(
        sprintf(
'no directory for path "%s" from autoindex_dirs at computed location "%s"',
          $path, $dir
        )
      );
    }
  }

  $self->logger->info("Registered $count autoindex routes");
}

async sub _handle_markdown ($self, $ctx, $entry) {
  # Parse frontmatter to get layout
  my $frontmatter = $self->parse_markdown_frontmatter($entry->{path});

  my $extra_vars = {};
  $extra_vars->{frontmatter} = $frontmatter;
  $extra_vars->{google}      = $self->googleStream();

  # Look up date from manifest

  my $date_str;
  $date_str = $self->date_manifest->{ $entry->{manifest_key} }
    if exists $entry->{manifest_key};
  if ($date_str) {
    $extra_vars->{last_edited} = $self->_format_relative_date($date_str);
  }

  # Add calendar widget
  $extra_vars->{calendar_widget} = $self->_get_current_calendar();

  # Add list of years with archives
  $extra_vars->{archive_years} = $self->_get_archive_years();

  # Add tag list
  $extra_vars->{tag_list} = $self->_get_tag_list();

  # Controller override: use luke/log_entry template for blog posts
  $extra_vars->{template_override} = 'luke/log_entry';

  # Pass layout from frontmatter (defaults to 'luke_rut' in template)
  if ($frontmatter->{layout}) {
    my $layout = $frontmatter->{layout};
    # Normalize 'rut' to 'luke_rut'
    $layout = 'luke_rut' if $layout eq 'rut';
    $extra_vars->{layout} = $layout;
  }
  elsif ($entry->{path} =~ /log/) {
    $extra_vars->{layout} = 'luke_rut';
  }
  else {
    $extra_vars->{layout} = 'luke_default';
  }

  my $html =
    $self->render_markdown_page($entry->{path}, $entry->{route}, $extra_vars,);

  if ($html) {
    if ($html =~ /<recent-changes>/) {
      my $changes = $self->recent_changes;
      foreach my $change (@$changes) {
        my $dt = DateTime->from_epoch(epoch => $change->{date});
        $change->{date_formatted} = $dt->ymd . ' ' . $dt->hms;
      }
      $extra_vars->{recent_changes} = $changes;
      my $rchtml = $self->template('luke/recent_changes', $extra_vars);
      $html =~ s{<recent-changes>.*?</recent-changes>}{$rchtml};
    }
    $ctx->res->html($html);
  }
  else {
    $ctx->res->status(404);
    $ctx->res->html('<h1>404 - Page Not Found</h1>');
  }
  return;
}

sub _format_relative_date ($self, $iso_str) {
  # Parse ISO 8601 date string
  # Handle formats like "2005-01-31T11:45:00" or "2005-01-31 11:45:00 -0500"
  my ($year, $month, $day) = $iso_str =~ /^(\d{4})-(\d{2})-(\d{2})/;
  return '' unless $year;

  my $then       = POSIX::mktime(0, 0, 12, $day, $month - 1, $year - 1900);
  my $now        = time();
  my $delta_days = int(($now - $then) / 86400);

  if ($delta_days < 1) {
    return 'earlier today';
  }
  elsif ($delta_days == 1) {
    return 'yesterday';
  }
  elsif ($delta_days < 7) {
    return "$delta_days days ago";
  }
  elsif ($delta_days < 14) {
    return 'last week';
  }
  elsif ($delta_days < 30) {
    my $weeks = int($delta_days / 7);
    return "about $weeks weeks ago";
  }
  elsif ($delta_days < 60) {
    return 'about a month ago';
  }
  elsif ($delta_days < 365) {
    my $months = int($delta_days / 30);
    return "about $months months ago";
  }
  elsif ($delta_days < 730) {
    return 'about a year ago';
  }
  else {
    my $years = int($delta_days / 365);
    return "about $years years ago";
  }
}

sub _get_current_calendar ($self) {
  my ($year, $month) = (localtime)[5, 4];
  $year += 1900;
  $month = sprintf("%02d", $month + 1);

  my $cal_file =
    $self->luke_dir->child("log/archive/$year/$month/calendar.html");

  if ($cal_file->exists) {
    return $cal_file->slurp_utf8;
  }

  # Fall back to most recent calendar
  my $archive_dir = $self->luke_dir->child("log/archive");
  if ($archive_dir->exists) {
    my @years = sort { $b cmp $a }
      grep { $_->is_dir && $_->basename =~ /^\d{4}$/ } $archive_dir->children;

    for my $year_dir (@years) {
      my @months = sort { $b <=> $a }
        grep { $_->is_dir && $_->basename =~ /^\d{2}$/ } $year_dir->children;

      for my $month_dir (@months) {
        my $cal = $month_dir->child('calendar.html');
        return $cal->slurp_utf8 if $cal->exists;
      }
    }
  }

  return '<p>No calendar available</p>';
}

sub _get_archive_years ($self) {
  my $archive_dir = $self->luke_dir->child("log/archive");
  return [] unless $archive_dir->exists;

  my @years = sort { $a <=> $b }
    map { $_->basename }
    grep { $_->is_dir && $_->basename =~ /^\d{4}$/ } $archive_dir->children;

  return \@years;
}

sub _get_tag_list ($self) {
  my $tags_file = $self->luke_dir->child("build-output/tags.json");
  return [] unless $tags_file->exists;

  my $json = JSON::MaybeXS->new(utf8 => 1);
  my $tags = eval { $json->decode($tags_file->slurp_raw) };
  return $tags // [];
}

1;
__END__
