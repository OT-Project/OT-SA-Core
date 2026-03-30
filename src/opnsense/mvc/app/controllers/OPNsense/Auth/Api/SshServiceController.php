<?php

/*
 * Copyright (C) 2024 Deciso B.V.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

namespace OPNsense\Auth\Api;

use OPNsense\Base\ApiMutableServiceControllerBase;
use OPNsense\Core\Backend;

/**
 * Class SshServiceController
 * @package OPNsense\Auth\Api
 */
class SshServiceController extends ApiMutableServiceControllerBase
{
    protected static $internalServiceClass = '\OPNsense\Auth\SshUser';
    protected static $internalServiceTemplate = 'OPNsense/Auth/SshManagement';
    protected static $internalServiceEnabled = 'enabled';
    protected static $internalServiceName = 'sshmanagement';

    /**
     * Reconfigure SSH access settings
     * @return array
     */
    public function reconfigureAction()
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed'];
        }

        $backend = new Backend();
        $backend->configdRun('template reload ' . escapeshellarg(static::$internalServiceTemplate));
        $backend->configdpRun('sshmanagement configure');

        return ['result' => 'ok'];
    }

    /**
     * Import existing system users into SSH Management
     * @return array
     */
    public function importAction()
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed'];
        }

        $backend = new Backend();
        $response = $backend->configdRun('sshmanagement import');

        $result = json_decode(trim($response), true);
        if ($result === null) {
            return ['result' => 'failed', 'message' => 'Import script returned invalid response'];
        }

        return $result;
    }
}
