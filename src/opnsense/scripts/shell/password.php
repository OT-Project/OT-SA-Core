#!/usr/local/bin/php
<?php

/*
 * Copyright (C) 2017-2018 Franco Fichtner <franco@opnsense.org>
 * Copyright (C) 2003-2004 Manuel Kasper <mk@neon1.net>
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

require_once('config.inc');
require_once('auth.inc');
require_once('util.inc');
require_once('/usr/local/opnsense/scripts/shell/langmode.php');

$fp = fopen('php://stdin', 'r');

/*
 * Mocking "pw usermod root -h 0", we always have the root
 * user but we do not know what the future will bring...
 */
if (isset($argv[2]) && isset($argv[3]) && $argv[2] === '-h' && $argv[3] === '0') {
    $admin_user = &getUserEntryByUID(0);
    if (!$admin_user) {
        echo __('user not found') . "\n";
        exit(1);
    }

    echo __('new password for user %s:', $admin_user['name']);
    shell_safe('/bin/stty -echo');
    $password = chop(fgets($fp));
    shell_safe('/bin/stty echo');
    echo "\n";

    if (empty($password)) {
        echo __('empty password read') . "\n";
        exit(1);
    }

    local_user_set_password($admin_user, $password);
    local_user_set($admin_user);

    write_config('Root user reset from console');

    exit(0);
} elseif (isset($argv[2]) && isset($argv[3]) && $argv[2] === '-x' && $argv[3] === '0') {
    $admin_user = &getUserEntryByUID(0);
    if (!$admin_user) {
        $admin_user = array();
        $admin_user['uid'] = 0;
        $a_users = &config_read_array('system', 'user');
        $a_users[] = $admin_user;
    }

    $admin_user['scope'] = 'system';
    $admin_user['name'] = 'root';

    if (isset($admin_user['disabled'])) {
        unset($admin_user['disabled']);
    }
    if (isset($admin_user['shell'])) {
        unset($admin_user['shell']);
    }

    echo __('new password for user %s:', $admin_user['name']);
    shell_safe('/bin/stty -echo');
    $password = chop(fgets($fp));
    shell_safe('/bin/stty echo');
    echo "\n";

    if (empty($password)) {
        echo __('empty password read') . "\n";
        exit(1);
    }

    $config['system']['webgui']['authmode'] = 'Local Database';

    local_user_set_password($admin_user, $password);
    local_user_set($admin_user);

    write_config('Root user reset from console');

    exit(0);
}

echo __('The root user login behaviour will be restored to its defaults.') . "\n\n" . __('Do you want to proceed?') . " " . __('[y/N]: ');

if (strcasecmp(normalize_yes_no(chop(fgets($fp))), 'y') != 0) {
    return;
}

if (isset($config['system']['webgui']['authmode']) && $config['system']['webgui']['authmode'] != 'Local Database') {
    echo sprintf("\n" . __('The authentication server is set to "%s".', $config['system']['webgui']['authmode'])) . "\n";
    echo __('Do you want to set it back to Local Database?') . ' ' . __('[y/N]: ');
    if (strcasecmp(normalize_yes_no(chop(fgets($fp))), 'y') == 0) {
        $config['system']['webgui']['authmode'] = 'Local Database';
    }
}

$admin_user = &getUserEntryByUID(0);
if (!$admin_user) {
    $admin_user = array();
    $admin_user['uid'] = 0;
    $a_users = &config_read_array('system', 'user');
    $a_users[] = $admin_user;
    echo "\n" . __('Restored missing root user.') . "\n";
}

$admin_user['scope'] = 'system';
$admin_user['name'] = 'root';

if (isset($admin_user['disabled'])) {
    unset($admin_user['disabled']);
}
if (isset($admin_user['shell'])) {
    unset($admin_user['shell']);
}

echo "\n" . __('Type a new password: ');

shell_safe('/bin/stty -echo');
$password = chop(fgets($fp));
shell_safe('/bin/stty echo');
echo "\n";
if (empty($password)) {
    echo "\n" . __('Password cannot be empty.') . "\n";
    return;
}

echo __('Confirm new password: ');
shell_safe('/bin/stty -echo');
$confirm = chop(fgets($fp));
shell_safe('/bin/stty echo');
echo "\n";
if ($password !== $confirm) {
    echo "\n" . __('Passwords do not match.') . "\n";
    return;
}

local_user_set_password($admin_user, $password);
local_user_set($admin_user);

write_config('Root user reset from console');

echo "\n" . __('The root user has been reset successfully.') . "\n";
