#
#   Licensed under the Apache License, Version 2.0 (the "License"); you may
#   not use this file except in compliance with the License. You may obtain
#   a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#   WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#   License for the specific language governing permissions and limitations
#   under the License.

from remora.common.loader import default


class DefaultCertsRendererLoader(default.DefaultLoader):
    def __init__(self):
        super(DefaultCertsRendererLoader, self).__init__(
            namespace='remora_certs_renderers')


class DefaultK8sManifestsRendererLoader(default.DefaultLoader):
    def __init__(self):
        super(DefaultK8sManifestsRendererLoader, self).__init__(
            namespace='remora_k8s_manifests_renderers')
