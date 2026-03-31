<?php

/*
 * Copyright (C) 2025 BKCS - OT Security Appliance
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

require_once("guiconfig.inc");
require_once("filter.inc");
require_once("system.inc");

$ssh_rekeylimit_choices = [
    '' => gettext('System defaults'),
    'default 60s' => gettext('60 seconds'),
    'default 600s' => gettext('10 minutes'),
    '512M 60s' => gettext('512MB, 60 seconds'),
    '512M 600s' => gettext('512MB, 10 minutes'),
    '512M 1h' => gettext('512MB, 1 hour'),
    '1G 60s' => gettext('1GB, 60 seconds'),
    '1G 1h' => gettext('1GB, 1 hour'),
];

$ssh_loglevel_choices = [
    '' => gettext('Default (INFO)'),
    'QUIET' => gettext('QUIET - Minimal logging'),
    'FATAL' => gettext('FATAL - Fatal errors only'),
    'ERROR' => gettext('ERROR - Errors only'),
    'INFO' => gettext('INFO - Standard logging'),
    'VERBOSE' => gettext('VERBOSE - Session details (recommended for auditing)'),
];

$interfaces = get_configured_interface_with_descr();

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $pconfig = [];
    $pconfig['enablesshd'] = $config['system']['ssh']['enabled'] ?? null;
    $pconfig['sshport'] = $config['system']['ssh']['port'] ?? null;
    $pconfig['sshinterfaces'] = !empty($config['system']['ssh']['interfaces']) ? explode(',', $config['system']['ssh']['interfaces']) : [];
    $pconfig['ssh-kex'] = !empty($config['system']['ssh']['kex']) ? explode(',', $config['system']['ssh']['kex']) : [];
    $pconfig['ssh-ciphers'] = !empty($config['system']['ssh']['ciphers']) ? explode(',', $config['system']['ssh']['ciphers']) : [];
    $pconfig['ssh-macs'] = !empty($config['system']['ssh']['macs']) ? explode(',', $config['system']['ssh']['macs']) : [];
    $pconfig['ssh-keys'] = !empty($config['system']['ssh']['keys']) ? explode(',', $config['system']['ssh']['keys']) : [];
    $pconfig['ssh-keysig'] = !empty($config['system']['ssh']['keysig']) ? explode(',', $config['system']['ssh']['keysig']) : [];
    $pconfig['ssh-rekeylimit'] = !empty($config['system']['ssh']['rekeylimit']) ? $config['system']['ssh']['rekeylimit'] : '';
    $pconfig['ssh-loglevel'] = !empty($config['system']['ssh']['loglevel']) ? $config['system']['ssh']['loglevel'] : '';
    $pconfig['sshpasswordauth'] = isset($config['system']['ssh']['passwordauth']);
    $pconfig['sshdpermitrootlogin'] = isset($config['system']['ssh']['permitrootlogin']);
} elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input_errors = [];
    $pconfig = $_POST;

    if (!empty($pconfig['sshport']) && !is_port($pconfig['sshport'])) {
        $input_errors[] = gettext('You must specify a valid SSH port number.');
    }

    if (!empty($pconfig['ssh-rekeylimit']) && !isset($ssh_rekeylimit_choices[$pconfig['ssh-rekeylimit']])) {
        $input_errors[] = gettext('Invalid rekey limit option.');
    }

    if (count($input_errors) == 0) {
        if (empty($config['system']['ssh'])) {
            $config['system']['ssh'] = [];
        }

        /* always store setting to prevent installer auto-start */
        $config['system']['ssh']['noauto'] = 1;

        $config['system']['ssh']['interfaces'] = !empty($pconfig['sshinterfaces']) ? implode(',', $pconfig['sshinterfaces']) : null;
        $config['system']['ssh']['kex'] = !empty($pconfig['ssh-kex']) ? implode(',', $pconfig['ssh-kex']) : null;
        $config['system']['ssh']['ciphers'] = !empty($pconfig['ssh-ciphers']) ? implode(',', $pconfig['ssh-ciphers']) : null;
        $config['system']['ssh']['macs'] = !empty($pconfig['ssh-macs']) ? implode(',', $pconfig['ssh-macs']) : null;
        $config['system']['ssh']['keys'] = !empty($pconfig['ssh-keys']) ? implode(',', $pconfig['ssh-keys']) : null;
        $config['system']['ssh']['keysig'] = !empty($pconfig['ssh-keysig']) ? implode(',', $pconfig['ssh-keysig']) : null;
        $config['system']['ssh']['rekeylimit'] = !empty($pconfig['ssh-rekeylimit']) ? $pconfig['ssh-rekeylimit'] : null;
        $config['system']['ssh']['loglevel'] = !empty($pconfig['ssh-loglevel']) ? $pconfig['ssh-loglevel'] : null;

        if (!empty($pconfig['enablesshd'])) {
            $config['system']['ssh']['enabled'] = 'enabled';
        } elseif (isset($config['system']['ssh']['enabled'])) {
            unset($config['system']['ssh']['enabled']);
        }

        if (!empty($pconfig['sshpasswordauth'])) {
            $config['system']['ssh']['passwordauth'] = true;
        } elseif (isset($config['system']['ssh']['passwordauth'])) {
            unset($config['system']['ssh']['passwordauth']);
        }

        if (!empty($pconfig['sshport'])) {
            $config['system']['ssh']['port'] = $pconfig['sshport'];
        } elseif (isset($config['system']['ssh']['port'])) {
            unset($config['system']['ssh']['port']);
        }

        if (!empty($pconfig['sshdpermitrootlogin'])) {
            $config['system']['ssh']['permitrootlogin'] = true;
        } elseif (isset($config['system']['ssh']['permitrootlogin'])) {
            unset($config['system']['ssh']['permitrootlogin']);
        }

        write_config();

        $savemsg = get_std_save_message();

        filter_configure();
        system_login_configure();
        if (!empty($pconfig['enablesshd'])) {
            mwexec('pluginctl -s openssh restart');
        } else {
            mwexec('pluginctl -s openssh stop');
        }
    }
}

$sshoptions = json_decode(configd_run('openssh query'), true);

legacy_html_escape_form_data($pconfig);

include("head.inc");

?>
<body>
<script>
    $(document).ready(function() {
        $("#show-advanced-cryptocryptobtn").click(function (event) {
            event.preventDefault();
            $(this).parent().parent().hide();
            $(".show-advanced-crypto").show();
            $(window).trigger('resize');
        });
        // show advanced when at least one option is set
        $(".advanced-crypto").each(function () {
            if ($(this).val() != '') {
                $("#show-advanced-cryptocryptobtn").click();
            }
        });
    });
</script>
<?php include("fbegin.inc"); ?>
<section class="page-content-main">
  <div class="container-fluid">
    <div class="row">
<?php
    if (isset($input_errors) && count($input_errors) > 0) {
        print_input_errors($input_errors);
    }
    if (isset($savemsg)) {
        print_info_box($savemsg);
    }
?>
      <section class="col-xs-12">
        <form method="post" name="iform" id="iform">
          <div class="content-box tab-content table-responsive __mb">
            <table class="table table-striped opnsense_standard_table_form">
              <tr>
                <td style="width:22%"><strong><?= gettext('Secure Shell') ?></strong></td>
                <td style="width:78%; text-align:right">
                  <small><?=gettext("full help"); ?> </small>
                  <i class="fa fa-toggle-off text-danger" style="cursor: pointer;" id="show_all_help_page"></i>
                </td>
              </tr>
              <tr>
                <td><i class="fa fa-info-circle text-muted"></i> <?=gettext("Secure Shell Server"); ?></td>
                <td>
                  <input name="enablesshd" type="checkbox" value="yes" <?= empty($pconfig['enablesshd']) ? '' : 'checked="checked"' ?> />
                  <?=gettext("Enable Secure Shell"); ?>
                </td>
              </tr>
              <tr>
                <td><a id="help_for_sshdpermitrootlogin" href="#" class="showhelp"><i class="fa fa-info-circle"></i></a> <?= gettext("Root Login") ?></td>
                <td>
                  <input name="sshdpermitrootlogin" type="checkbox" value="yes" <?= empty($pconfig['sshdpermitrootlogin']) ? '' : 'checked="checked"' ?> />
                  <?=gettext("Permit root user login"); ?>
                  <div class="hidden" data-for="help_for_sshdpermitrootlogin">
                    <?= gettext(
                      'Root login is generally discouraged. It is advised ' .
                      'to log in via another user and switch to root afterwards.'
                    ) ?>
                  </div>
                </td>
              </tr>
              <tr>
                <td><a id="help_for_sshpasswordauth" href="#" class="showhelp"><i class="fa fa-info-circle"></i></a> <?= gettext("Authentication Method") ?></td>
                <td>
                  <input name="sshpasswordauth" type="checkbox" value="yes" <?= empty($pconfig['sshpasswordauth']) ? '' : 'checked="checked"' ?> />
                  <?=gettext("Permit password login"); ?>
                  <div class="hidden" data-for="help_for_sshpasswordauth">
                    <?= gettext('When disabled, authorized keys need to be configured for each user that has been granted secure shell access.') ?>
                  </div>
                </td>
              </tr>
              <tr>
                <td><a id="help_for_sshport" href="#" class="showhelp"><i class="fa fa-info-circle"></i></a> <?=gettext("SSH port"); ?></td>
                <td>
                  <input name="sshport" type="text" value="<?=$pconfig['sshport'];?>" placeholder="22" />
                  <div class="hidden" data-for="help_for_sshport">
                    <?=gettext("Leave this blank for the default of 22."); ?>
                  </div>
                </td>
              </tr>
              <tr>
                <td><a id="help_for_sshinterfaces" href="#" class="showhelp"><i class="fa fa-info-circle"></i></a> <?=gettext('Listen Interfaces') ?></td>
                <td>
                  <select name="sshinterfaces[]" multiple="multiple" class="selectpicker" title="<?= html_safe(gettext('All (recommended)')) ?>">
<?php foreach ($interfaces as $iface => $ifacename): ?>
                      <option value="<?= html_safe($iface) ?>" <?= !empty($pconfig['sshinterfaces']) && in_array($iface, $pconfig['sshinterfaces']) ? 'selected="selected"' : '' ?>><?= html_safe($ifacename) ?></option>
<?php endforeach ?>
                  </select>
                  <div class="hidden" data-for="help_for_sshinterfaces">
                    <?= gettext('Only accept connections from the selected interfaces. Leave empty to listen globally. Use with care.') ?>
                  </div>
                </td>
              </tr>
              <tr>
                <td><i class="fa fa-info-circle text-muted"></i> <?=gettext("Advanced");?></td>
                <td>
                  <button id="show-advanced-cryptocryptobtn" class="btn btn-xs btn-default" value="yes"><?= gettext('Show cryptographic overrides') ?></button>
                </td>
              </tr>
              <tr class="show-advanced-crypto" style="display:none">
                <td><a id="help_for_sshkex" href="#" class="showhelp"><i class="fa fa-info-circle"></i></a> <?=gettext("Key exchange algorithms"); ?></td>
                <td>
                    <select name="ssh-kex[]" class="selectpicker advanced-crypto" multiple="multiple" data-live-search="true" title="<?=gettext("System defaults");?>">
<?php foreach ($options = empty($sshoptions['kex']) ? [] : $sshoptions['kex'] as $option): ?>
                      <option value="<?=$option;?>" <?= !empty($pconfig['ssh-kex']) && in_array($option, $pconfig['ssh-kex']) ? 'selected="selected"' : '' ?>>
                        <?=$option;?>
                      </option>
<?php endforeach ?>
                    </select>
                    <div class="hidden" data-for="help_for_sshkex">
                      <?=gettext("The key exchange methods that are used to generate per-connection keys");?>
                    </div>
                </td>
              </tr>
              <tr class="show-advanced-crypto" style="display:none">
                <td><a id="help_for_sshciphers" href="#" class="showhelp"><i class="fa fa-info-circle"></i></a> <?=gettext("Ciphers"); ?></td>
                <td>
                    <select name="ssh-ciphers[]" class="selectpicker advanced-crypto" multiple="multiple" data-live-search="true" title="<?=gettext("System defaults");?>">
<?php foreach ($options = empty($sshoptions['cipher']) ? [] : $sshoptions['cipher'] as $option): ?>
                      <option value="<?=$option;?>" <?= !empty($pconfig['ssh-ciphers']) && in_array($option, $pconfig['ssh-ciphers']) ? 'selected="selected"' : '' ?>>
                        <?=$option;?>
                      </option>
<?php endforeach ?>
                    </select>
                    <div class="hidden" data-for="help_for_sshciphers">
                      <?=gettext("The ciphers to encrypt the connection");?>
                    </div>
                </td>
              </tr>
              <tr class="show-advanced-crypto" style="display:none">
                <td><a id="help_for_sshmacs" href="#" class="showhelp"><i class="fa fa-info-circle"></i></a> <?=gettext("MACs"); ?></td>
                <td>
                    <select name="ssh-macs[]" class="selectpicker advanced-crypto" multiple="multiple" data-live-search="true" title="<?=gettext("System defaults");?>">
<?php foreach ($options = empty($sshoptions['mac']) ? [] : $sshoptions['mac'] as $option): ?>
                      <option value="<?=$option;?>" <?= !empty($pconfig['ssh-macs']) && in_array($option, $pconfig['ssh-macs']) ? 'selected="selected"' : '' ?>>
                        <?=$option;?>
                      </option>
<?php
                    endforeach;?>
                    </select>
                    <div class="hidden" data-for="help_for_sshmacs">
                      <?=gettext("The message authentication codes used to detect traffic modification");?>
                    </div>
                </td>
              </tr>
              <tr class="show-advanced-crypto" style="display:none">
                <td><a id="help_for_sshkeys" href="#" class="showhelp"><i class="fa fa-info-circle"></i></a> <?=gettext("Host key algorithms"); ?></td>
                <td>
                    <select name="ssh-keys[]" class="selectpicker advanced-crypto" multiple="multiple" data-live-search="true" title="<?=gettext("System defaults");?>">
<?php foreach ($options = empty($sshoptions['key']) ? [] : $sshoptions['key'] as $option): ?>
                      <option value="<?=$option;?>" <?= !empty($pconfig['ssh-keys']) && in_array($option, $pconfig['ssh-keys']) ? 'selected="selected"' : '' ?>>
                        <?=$option;?>
                      </option>
<?php endforeach ?>
                    </select>
                    <div class="hidden" data-for="help_for_sshkeys">
                      <?= gettext('Specifies the host key algorithms that the server offers') ?>
                    </div>
                </td>
              </tr>
              <tr class="show-advanced-crypto" style="display:none">
                <td><a id="help_for_sshkeysig" href="#" class="showhelp"><i class="fa fa-info-circle"></i></a> <?=gettext("Public key signature algorithms"); ?></td>
                <td>
                    <select name="ssh-keysig[]" class="selectpicker advanced-crypto" multiple="multiple" data-live-search="true" title="<?=gettext("System defaults");?>">
<?php foreach ($options = empty($sshoptions['key-sig']) ? [] : $sshoptions['key-sig'] as $option): ?>
                      <option value="<?=$option;?>" <?= !empty($pconfig['ssh-keysig']) && in_array($option, $pconfig['ssh-keysig']) ? 'selected="selected"' : '' ?>>
                        <?=$option;?>
                      </option>
<?php endforeach ?>
                    </select>
                    <div class="hidden" data-for="help_for_sshkeysig">
                      <?=gettext("The signature algorithms that are used for public key authentication");?>
                    </div>
                </td>
              </tr>
              <tr class="show-advanced-crypto" style="display:none">
                <td><a id="help_for_sshrekeylimit" href="#" class="showhelp"><i class="fa fa-info-circle"></i></a> <?=gettext("Rekey Limit"); ?></td>
                <td>
                    <select name="ssh-rekeylimit" class="selectpicker advanced-crypto" data-live-search="true">
<?php foreach ($ssh_rekeylimit_choices as $option => $descr): ?>
                      <option value="<?=$option;?>" <?= $option == $pconfig['ssh-rekeylimit'] ? 'selected="selected"' : '' ?>>
                        <?=$descr;?>
                      </option>
<?php endforeach ?>
                    </select>
                    <div class="hidden" data-for="help_for_sshrekeylimit">
                      <?=gettext("Specifies the maximum amount of data that may be transmitted or received before the session key is renegotiated within a given time. The defaults depend on cipher and are usually the best option.");?>
                    </div>
                </td>
              </tr>
            </table>
          </div>
          <div class="content-box tab-content table-responsive __mb">
            <table class="table table-striped opnsense_standard_table_form">
              <tr>
                <td style="width:22%"><strong><?= gettext('Logging') ?></strong></td>
                <td style="width:78%; text-align:right">
                  <small><?=gettext("full help"); ?> </small>
                  <i class="fa fa-toggle-off text-danger" style="cursor: pointer;" id="show_all_help_page"></i>
                </td>
              </tr>
              <tr>
                <td><a id="help_for_sshloglevel" href="#" class="showhelp"><i class="fa fa-info-circle"></i></a> <?=gettext("Log Level"); ?></td>
                <td>
                    <select name="ssh-loglevel" class="selectpicker">
<?php foreach ($ssh_loglevel_choices as $option => $descr): ?>
                      <option value="<?=$option;?>" <?= $option == $pconfig['ssh-loglevel'] ? 'selected="selected"' : '' ?>>
                        <?=$descr;?>
                      </option>
<?php endforeach ?>
                    </select>
                    <div class="hidden" data-for="help_for_sshloglevel">
                      <?=gettext("Controls the verbosity of SSH logging. VERBOSE is recommended for auditing SSH session access, as it logs user logins, disconnections, key fingerprints, and session activity.");?>
                    </div>
                </td>
              </tr>
              <tr>
                <td><i class="fa fa-info-circle text-muted"></i> <?=gettext("View Log File"); ?></td>
                <td>
                  <a href="/ui/diagnostics/log/core/sshd" class="btn btn-default btn-xs">
                    <i class="fa fa-eye"></i> <?= gettext('Open SSH Log Viewer') ?>
                  </a>
                </td>
              </tr>
            </table>
          </div>
          <div class="content-box tab-content table-responsive">
            <table class="table table-striped opnsense_standard_table_form">
              <tr>
                <td style="width:22%"></td>
                <td style="width:78%"><input name="Submit" type="submit" class="btn btn-primary" value="<?= html_safe(gettext('Save')) ?>" /></td>
              </tr>
            </table>
          </div>
        </form>
      </section>
    </div>
  </div>
</section>
<?php include("foot.inc"); ?>
