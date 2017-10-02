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

from fabric.api import env

from remora.fab import helpers


ASSETS_DIR = os.path.join(helpers.remora_scripts_dir, 'assets')


def assets_dir():
    assets_dir = env.configs.get('local', {}).get('assets_dir', ASSETS_DIR)
    assets_dir = os.path.expanduser(assets_dir)
    return assets_dir


def certs_dir():
    certs_dir = os.path.join(assets_dir(), 'certs')
    return certs_dir