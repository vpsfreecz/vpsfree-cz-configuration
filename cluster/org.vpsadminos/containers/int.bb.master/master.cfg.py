from buildbot.plugins import *


c = BuildmasterConfig = {}
c['title'] = 'vpsAdminOS'
c['titleURL'] = 'vpsAdminOS'
c['buildbotURL'] = 'https://master.bb.vpsadminos.org/'
c['protocols'] = {'pb': {'port': 9989}}
c['db'] = {'db_url': 'sqlite:///state.sqlite'}
c['www']= {'port': 8010}

c['www']['change_hook_dialects'] = {'github': {}}

c['schedulers'] = [
    schedulers.SingleBranchScheduler(
        name='all',
        change_filter=util.ChangeFilter(repository='https://github.com/vpsfreecz/vpsadminos'),
        treeStableTimer=None,
        builderNames=['buildos']
    ),
    schedulers.ForceScheduler(
        name='forcebuild',
        builderNames=['buildos'],
        codebases=[
            util.CodebaseParameter(
                "",
                label="Repository",
                branch=util.ChoiceStringParameter(
                    name="branch",
                    choices=["master", "devel"],
                    default="master"
                ),

                revision=util.FixedParameter(name="revision", default=""),
                repository=util.FixedParameter(name="repository", default=""),
                project=util.FixedParameter(name="project", default=""),
            ),
        ]
    )
]

steps = [
    steps.Git(
        repourl='https://github.com/vpsfreecz/vpsadminos',
        branch=util.Property('branch'),
        mode='full',
        method='clobber',
        submodules=False,
        workdir='build/vpsadminos',
        haltOnFailure=True
    ),
    steps.ShellCommand(
        command=["wget", "https://nixos.org/channels/nixos-19.09/nixexprs.tar.xz", "-O", "nixexprs.tar.xz"],
        env={'PATH': ['/run/current-system/sw/bin', "${PATH}"]},
        haltOnFailure=True
    ),
    steps.ShellCommand(
        command=["mkdir", "-p", "nixpkgs"]
    ),
    steps.ShellCommand(
        command=["tar", "xfa", "nixexprs.tar.xz", "--strip-components=1", "-C", "nixpkgs"],
        env={'PATH': ['/run/current-system/sw/bin', "${PATH}"]},
        haltOnFailure=True
    ),
    steps.ShellCommand(
        command=["make", "toplevel"],
        workdir="build/vpsadminos",
        env={
            'PATH': ['/run/current-system/sw/bin', "${PATH}"],
            'NIX_PATH': [
                'nixpkgs=${PWD}/worker/buildos/build/nixpkgs',
                'vpsadminos=${PWD}/worker/buildos/build/vpsadminos'
            ],
        },
        haltOnFailure=True
    ),
    steps.ShellCommand(
        command=["nix-copy-closure", "--to", "push@172.16.4.30", "./os/result/toplevel"],
        workdir="build/vpsadminos",
        env={
            'PATH': ['/run/current-system/sw/bin', "${PATH}"],
            'NIX_SSHOPTS': '-i /private/buildbot/worker/id_ecdsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null',
        }
    ),
]
factory = util.BuildFactory(steps)

c['builders'] = [
    util.BuilderConfig(
        name='buildos',
        workernames=['nixos01', 'nixos02'],
        factory=factory
    )
]

c['workers'] = []
workers = ['nixos01', 'nixos02']

for w in workers:
    with open('/private/buildbot/workers/{}/pass'.format(w)) as f:
        c['workers'].append(worker.Worker(w, f.readline().strip()))

c['status'] = []

c['buildbotNetUsageData'] = None
