# 批量克隆barerepo
import os
import sys
from tokenize import group
basedir, filename = os.path.split(os.path.abspath(sys.argv[0])) 

def gitclone(groupdir,repolist,bare="--bare "):
    workdir = basedir + "/" + groupdir
    os.system("mkdir -p " + workdir)
    os.chdir(workdir)
    for r in repolist:
        s = "git clone " + bare + baseurl + r
        os.system(s)

server = "git@192.168.1.10:"
#server = "http://twgitlab.com:7000/"

#FP
baseurl = server + "fp/"
gr = "FP"
rl = ["adminqueue",
"data-migration",
"data-report",
"fameandpartners_app",
"fameandpartnersapp",
"fp-3d-utils",
"fp-admin-vue",
"fp-bergen-statistic",
"fp-client-vue",
"fp-data-analysis",
"fp-email-test",
"fp-front-v4",
"fp-front-vue",
"fp-page",
"fp-return-statistic",
"fp-screenshot",
"fp-server-eggjs",
"fp-v4",
"fp2-fulfill-statistic",
"fp2-sale-statistic",
"fpsaledatastatics",
"fpwebsite2test",
"fpwebsitetest",
"frillyshopifyapp",
"lambdatmp",
"template_impulse",
"urlredirector",
"FPAppTest",
"interface_testing",
"sestool",
"fp-website-vue",
"fp-watcher"
]

gitclone(gr,rl)

#seamplacement
baseurl = server + "sp/"
gr = "sp"
rl = ["seamplacement"]
gitclone(gr,rl)

#measuretomade
baseurl = server + "m2m/"
gr = "m2m"
rl = ["measuretomade"]
gitclone(gr,rl)

#uscad
baseurl = server + "uscad/"
gr = "uscad"
rl = ["uscore"]
gitclone(gr,rl)

#testgroup
baseurl = server + "testgroup/"
gr = "testgroup"
rl = ["douyinchongzhi","douyin_autotest","testframework"]
gitclone(gr,rl)

#rd
baseurl = server + "rd/"
gr = "rd"
rl = ["Cloth",			"fce_lib_src",		"usbody",
"bbw",			"pdc",			"usfcecpu",
"bodymeasure",		"pifuhd",			"vt_work",
"cameracalibration",	"sim_work",		"webbodydeform",
"fce2",			"style3d",			"whmin_work"]
gitclone(gr,rl)


#alltocn
baseurl = server + "alltocn/"
gr = "alltocn"
rl = ["apiservertest",
"tun2socks",
"androidclienttest",
"iosclienttest",
"windowsclienttest",
"dataanalysiscmd",
"dataplatform",
"statistic",
"andoidclient",
"monitor",
"iosclient",
"windowsclient",
"APIServer",
"ssserver"]
gitclone(gr,rl)

#usdesign
baseurl = server + "usdesign/"
gr = "usdesign"
rl = ["dem-bones",
"cloudsimulationmanager",
"glslpathtracing",
"skin-mesh-animation",
"dem-bones",
"optixrender",
"usfashion"]
gitclone(gr,rl)

#pub
baseurl = server + "pub/"
gr = "pub"
rl = ["backup","ddns","pythonwork_nijie","rendertraining","testrepobyc"]
gitclone(gr,rl)

#research
baseurl = server + "research/"
gr = "research"
rl = ["refinement"]
gitclone(gr,rl)