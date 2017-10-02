#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

import os
import tempfile

from fabric.api import env
from fabric.api import execute
from fabric.api import local
from fabric.api import runs_once
from fabric.api import task
from fabric.operations import require

from remora.common import utils
from remora.fab.certs import constants
from remora.fab import helpers


def generate_local_env(target):
    certs_dir = os.path.join(constants.certs_dir(), target)
    return [
        'export LOCAL_CERTS_DIR="%s"' % certs_dir,
    ]


def gen_certs_or_keypairs(target, script_name, host='', *options):
    with tempfile.TemporaryDirectory() as temp_dir:
        default_env = os.path.join(temp_dir, 'default-env.sh')
        utils.generate_env_file(
            default_env,
            env,
            generate_local_env(target)
        )

        local(
            'source {0} && bash {1}/{2} {3} {4}'.format(
                default_env,
                helpers.remora_scripts_dir,
                script_name,
                host,
                ' '.join(options)
            ),
            shell=env.configs['local']['shell'],
        )


def gen_client_certs(target, *options):
    gen_certs_or_keypairs(
        target,
        'gen-cert-client.sh',
        '',
        *options
    )


def gen_kubelet_certs(target, *options):
    gen_certs_or_keypairs(
        target,
        'gen-cert-kubelet.sh',
        env.host,
        *options
    )


@task
@runs_once
def etcd_ca():
    require('stage')
    gen_certs_or_keypairs(
        'etcd',
        'gen-cert-ca.sh'
    )


@task
@runs_once
def kubernetes_ca():
    require('stage')
    gen_certs_or_keypairs(
        'kubernetes',
        'gen-cert-ca.sh'
    )


@task
@runs_once
def etcd_server():
    require('stage')
    gen_certs_or_keypairs(
        'etcd',
        'gen-cert-etcd-server.sh',
    )


@task
@runs_once
def etcd_client():
    require('stage')
    gen_client_certs(
        'etcd',
        'etcd-client',
        '"/CN=etcd-client"'
    )


@task
@runs_once
def etcd():
    execute(etcd_ca)
    execute(etcd_server)
    execute(etcd_client)


@task(alias='sa')
@runs_once
def service_account():
    require('stage')
    gen_certs_or_keypairs(
        'kubernetes',
        'gen-keypair-sa.sh'
    )


@task
def kubelet():
    require('stage')
    gen_kubelet_certs(
        'kubernetes',
        'kubelet',
        '"/O=system:nodes/CN=system:node:{}"'.format(env.host)
    )


@task
@runs_once
def apiserver():
    require('stage')
    gen_client_certs(
        'kubernetes',
        'admin',
        '"/O=system:masters/CN=kubernetes-admin"'
    )
    gen_certs_or_keypairs(
        'kubernetes',
        'gen-cert-apiserver.sh',
    )
    gen_client_certs(
        'kubernetes',
        'apiserver-kubelet-client',
        '"/O=system:masters/CN=kube-apiserver-kubelet-client"'
    )


@task
@runs_once
def controller_manager():
    require('stage')
    gen_client_certs(
        'kubernetes',
        'controller-manager',
        '"/CN=system:kube-controller-manager"'
    )


@task
@runs_once
def scheduler():
    require('stage')
    gen_client_certs(
        'kubernetes',
        'scheduler',
        '"/CN=system:kube-scheduler"'
    )


@task(alias='k8s')
@runs_once
def kubernetes():
    execute(kubernetes_ca)
    execute(service_account)
    execute(kubelet)
    execute(apiserver)
    execute(controller_manager)
    execute(scheduler)


@task(default=True)
@runs_once
def all():
    execute(etcd)
    execute(kubernetes)
