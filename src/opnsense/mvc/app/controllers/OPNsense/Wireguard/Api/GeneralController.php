<?php

/*
 * Copyright (C) 2018 Michael Muenz <m.muenz@gmail.com>
 * Copyright (C) 2022 Patrik Kernstock <patrik@kernstock.net>
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

namespace OPNsense\Wireguard\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Core\Config;
use OPNsense\Core\Backend;

class GeneralController extends ApiMutableModelControllerBase
{
    protected static $internalModelClass = '\OPNsense\Wireguard\General';
    protected static $internalModelName = 'general';

    /**
     * Generate WireGuard keypair
     * @return array
     */
    public function generateKeypairAction()
    {
        $backend = new Backend();
        $response = $backend->configdRun('wireguard gen_keypair');
        
        $keys = json_decode($response, true);
        
        if (isset($keys['privkey']) && isset($keys['pubkey'])) {
            return [
                'pubkey' => $keys['pubkey'],
                'privkey' => $keys['privkey']
            ];
        }
        
        return [
            'pubkey' => '',
            'privkey' => ''
        ];
    }

    /**
     * Get next available listen port
     * @return array
     */
    public function getNextListenPortAction()
    {
        $result = ['port' => 51820];
        
        // Load Server model instead of General model
        $mdl = (new \OPNsense\Wireguard\Server());
        $usedPorts = [];
        
        if ($mdl->servers && $mdl->servers->server) {
            foreach ($mdl->servers->server->iterateItems() as $server) {
                $portStr = (string)$server->port;
                if (!empty($portStr)) {
                    $usedPorts[] = (int)$portStr;
                }
            }
        }
        
        if (!empty($usedPorts)) {
            sort($usedPorts);
            $nextPort = 51820;
            while (in_array($nextPort, $usedPorts)) {
                $nextPort++;
            }
            $result['port'] = $nextPort;
        }
        
        return $result;
    }

    /**
     * Generate default instance name based on hostname and instance number
     * @param int $instanceId
     * @return array
     */
    public function generateInstanceNameAction($instanceId = null)
    {
        $config = Config::getInstance()->object();
        $hostname = (string)$config->system->hostname;
        
        if (empty($hostname)) {
            $hostname = 'firewall';
        }
        
        if (empty($instanceId)) {
            $instanceId = 0;
        }
        
        return [
            'name' => sprintf('%s_VPN_%d', $hostname, $instanceId)
        ];
    }

    /**
     * Generate tunnel address based on instance ID
     * @param int $instanceId
     * @return array
     */
    public function generateTunnelAddressAction($instanceId = null)
    {
        $result = ['address' => ''];
        // Chỉ sinh địa chỉ cho instance ID từ 1 đến 254
        if ($instanceId !== null && is_numeric($instanceId)) {
            $idNum = (int)$instanceId;
            if ($idNum >= 1 && $idNum <= 254) {
                $result['address'] = sprintf('10.%d.0.1/24', $idNum);
            }
        }
        return $result;
    }

    /**
     * Get next available instance ID
     * @return array
     */
    public function getNextInstanceIdAction()
    {
        $mdl = new \OPNsense\Wireguard\Server();
        $usedIds = [];

        if ($mdl->servers && $mdl->servers->server) {
            foreach ($mdl->servers->server->iterateItems() as $server) {
                $instanceStr = (string)$server->instance;
                if (is_numeric($instanceStr)) {
                    $instanceNum = (int)$instanceStr;
                    if ($instanceNum > 0) {          // chỉ lấy các ID hợp lệ >= 1
                        $usedIds[] = $instanceNum;
                    }
                }
            }
        }

        // Tìm ID trống nhỏ nhất bắt đầu từ 1
        $nextId = 1;
        sort($usedIds);

        // Duyệt qua các ID đã dùng, tìm lỗ trống đầu tiên
        foreach ($usedIds as $usedId) {
            if ($usedId == $nextId) {
                $nextId++;
            } elseif ($usedId > $nextId) {
                // Tìm thấy lỗ trống tại $nextId
                break;
            }
        }

        return [
            'instance' => $nextId
        ];
    }

    /**
     * Get all default values for a new instance
     * This includes: instance ID, tunnel address, name, and port
     * @return array
     */
    public function getNewInstanceDefaultsAction()
    {
        $result = [];
        
        // Get next instance ID
        $nextIdResult = $this->getNextInstanceIdAction();
        $instanceId = $nextIdResult['instance'];
        $result['instance'] = $instanceId;
        
        // Generate tunnel address for this instance
        $tunnelAddressStr = '';
        if ($instanceId >= 1 && $instanceId <= 254) {
            $tunnelAddress = $this->generateTunnelAddressAction($instanceId);
            $tunnelAddressStr = $tunnelAddress['address'];
        }
        
        // Format tunnel address theo structure của framework (giống API get_server)
        if (!empty($tunnelAddressStr)) {
            $result['tunneladdress'] = [
                $tunnelAddressStr => [
                    'value' => $tunnelAddressStr,
                    'selected' => 1
                ]
            ];
        } else {
            $result['tunneladdress'] = [];
        }
        
        // Generate default instance name
        $nameResult = $this->generateInstanceNameAction($instanceId);
        $result['name'] = $nameResult['name'];
        
        // Get next available listen port
        $portResult = $this->getNextListenPortAction();
        $result['port'] = $portResult['port'];
        
        // Get firewall IPs for endpoint dropdown
        $ipsResult = $this->getFirewallIpsAction();
        $result['firewall_ips'] = $ipsResult['ips'];
        
        // Get common DNS servers
        $dnsResult = $this->getCommonDnsAction();
        $result['common_dns'] = $dnsResult['dns'];
        
        return $result;
    }

    /**
     * Get firewall IP addresses for dropdown
     * @return array
     */
    public function getFirewallIpsAction()
    {
        $config = Config::getInstance()->object();
        $ips = [];
        
        // Get interface IPs
        if (isset($config->interfaces)) {
            foreach ($config->interfaces->children() as $ifname => $ifconfig) {
                if (isset($ifconfig->ipaddr) && !empty((string)$ifconfig->ipaddr)) {
                    $ip = (string)$ifconfig->ipaddr;
                    if ($ip !== 'dhcp' && $ip !== 'dhcp6') {
                        $ips[] = ['value' => $ip, 'label' => ucfirst($ifname) . ': ' . $ip];
                    }
                }
            }
        }
        
        return ['ips' => $ips];
    }

    /**
     * Get common DNS servers for dropdown
     * @return array
     */
    public function getCommonDnsAction()
    {
        return [
            'dns' => [
                ['value' => '8.8.8.8', 'label' => 'Google DNS - 8.8.8.8'],
                ['value' => '8.8.4.4', 'label' => 'Google DNS - 8.8.4.4'],
                ['value' => '1.1.1.1', 'label' => 'Cloudflare DNS - 1.1.1.1'],
                ['value' => '1.0.0.1', 'label' => 'Cloudflare DNS - 1.0.0.1'],
                ['value' => '9.9.9.9', 'label' => 'Quad9 DNS - 9.9.9.9'],
                ['value' => '208.67.222.222', 'label' => 'OpenDNS - 208.67.222.222'],
                ['value' => '208.67.220.220', 'label' => 'OpenDNS - 208.67.220.220']
            ]
        ];
    }
}