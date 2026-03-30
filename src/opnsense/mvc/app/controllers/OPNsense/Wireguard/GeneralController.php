<?php

/*
 * Copyright (C) 2024 Deciso B.V.
 * Copyright (C) 2018 Michael Muenz <m.muenz@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
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

namespace OPNsense\Wireguard;

class GeneralController extends \OPNsense\Base\IndexController
{
    protected function templateJSIncludes()
    {
        $result = parent::templateJSIncludes();
        $result[] = '/ui/js/jquery.qrcode.js';
        $result[] = '/ui/js/qrcode.js';
        return $result;
    }

    public function indexAction()
    {
        $this->view->generalForm = $this->getForm("general");

        $this->view->formDialogEditWireguardClient = $this->getForm("dialogEditWireguardClient");
        $this->view->formGridWireguardClient = $this->getFormGrid("dialogEditWireguardClient");

        $gridList = $this->getFormGrid("dialogEditWireguardClient", "dialogEditWireguardClientList");
        $visibleFields = ['enabled', 'name', 'servers', 'tunneladdress'];
        foreach ($gridList['fields'] as &$field) {
            $fieldId = $field['column-id'];
            $field['visible'] = in_array($fieldId, $visibleFields) ? 'true' : 'false';
            switch ($field['column-id']) {
                case 'uuid':
                    $field['label'] = gettext('ID');
                    $field['visible'] = 'false';
                    break;
                case 'name':
                    $field['label'] = gettext('Client Name');
                    break;
                case 'servers':
                    $field['label'] = gettext('Instance');
                    break;
                case 'tunneladdress':
                    $field['label'] = gettext('Assigned Client IP');
                    break;
                case 'pubkey':
                    $field['label'] = gettext('Client Public Key');
                    $field['formatter'] = 'clientpubkey';
                    break;
                case 'peer_dns':
                    $field['label'] = gettext('DNS Servers');
                    $field['formatter'] = 'peerdns';
                    break;
            }
        }
        unset($field);

        $gridList['fields'][] = [
            'column-id' => 'serverendpoint',
            'label' => gettext('Server Endpoint'),
            'visible' => 'false',
            'sortable' => 'false',
            'identifier' => 'false',
            'type' => 'string',
            'formatter' => 'serverendpoint'
        ];

        $gridList['fields'][] = [
            'column-id' => 'tunnelrouting',
            'label' => gettext('Tunnel Routing'),
            'visible' => 'false',
            'sortable' => 'false',
            'identifier' => 'false',
            'type' => 'string',
            'formatter' => 'tunnelrouting'
        ];

        $order = [
            'uuid',
            'enabled',
            'name',
            'servers',
            'tunneladdress',
            'pubkey',
            'serverendpoint',
            'tunnelrouting',
            'peer_dns'
        ];
        usort($gridList['fields'], function ($a, $b) use ($order) {
            $ia = array_search($a['column-id'], $order);
            $ib = array_search($b['column-id'], $order);
            if ($ia === false) {
                $ia = count($order);
            }
            if ($ib === false) {
                $ib = count($order);
            }
            return $ia <=> $ib;
        });

        $gridList['edit_dialog_id'] = $this->view->formGridWireguardClient['edit_dialog_id'];
        $this->view->formGridWireguardClientList = $gridList;

        $this->view->formDialogEditWireguardServer = $this->getForm("dialogEditWireguardServer");
        $this->view->formGridWireguardServer = $this->getFormGrid("dialogEditWireguardServer");

        $this->view->formDialogConfigBuilder = $this->getForm("dialogConfigBuilder");
        $this->view->pick('OPNsense/Wireguard/general');
    }
}
