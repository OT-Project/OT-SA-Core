{#
 # Copyright (c) 2014-2023 Deciso B.V.
 # Copyright (c) 2018 Michael Muenz <m.muenz@gmail.com>
 # All rights reserved.
 #
 # Redistribution and use in source and binary forms, with or without modification,
 # are permitted provided that the following conditions are met:
 #
 # 1.  Redistributions of source code must retain the above copyright notice,
 #     this list of conditions and the following disclaimer.
 #
 # 2.  Redistributions in binary form must reproduce the above copyright notice,
 #     this list of conditions and the following disclaimer in the documentation
 #     and/or other materials provided with the distribution.
 #
 # THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 # INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 # AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 # AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 # OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 # SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 # INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 # CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 # ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 # POSSIBILITY OF SUCH DAMAGE.
 #}

<script>
    $(document).ready(function() {
        const data_get_map = {'frm_general_settings':"/api/wireguard/general/get"};
        mapDataToFormUI(data_get_map).done(function(data){
            formatTokenizersUI();
            $('.selectpicker').selectpicker('refresh');
        });

        const grid_peers = $("#{{formGridWireguardClient['table_id']}}").UIBootgrid({
            search: '/api/wireguard/client/search_client',
            get: '/api/wireguard/client/get_client/',
            set: '/api/wireguard/client/set_client/',
            add: '/api/wireguard/client/add_client/',
            del: '/api/wireguard/client/del_client/',
            toggle: '/api/wireguard/client/toggle_client/',
            options:{
                initialSearchPhrase: getUrlHash('search'),
                requestHandler: function(request){
                    request['type'] = 's2s';
                    const selectedServers = $('#server_filter').val() || [];
                    if (selectedServers.length > 0) {
                        request['servers'] = selectedServers;
                    }
                    return request;
                }
            }
        });
        
        grid_peers.on("loaded.rs.jquery.bootgrid", function (e){
            // reload servers before grid load
            if ($("#server_filter > option").length == 0) {
                ajaxGet('/api/wireguard/client/list_servers', {}, function(data, status){
                    if (data.rows !== undefined) {
                        for (let i=0; i < data.rows.length ; ++i) {
                            let row = data.rows[i];
                            $("#server_filter").append($("<option/>").val(row.uuid).html(row.name));
                        }
                        $("#server_filter").selectpicker('refresh');
                    }
                });
            }
        });

        const grid_clienttosite = $("#{{formGridWireguardClientList['table_id']}}")
            .UIBootgrid({
                search: '/api/wireguard/client/search_client',
                get: '/api/wireguard/client/get_client/',
                set: '/api/wireguard/client/set_client/',
                add: '/api/wireguard/client/add_client/',
                del: '/api/wireguard/client/del_client/',
                toggle: '/api/wireguard/client/toggle_client/',
                options: {
                    requestHandler: function(request){
                        request['type'] = 'c2s';
                        const selectedServers = $('#server_filter').val() || [];
                        if (selectedServers.length > 0) {
                            request['servers'] = selectedServers;
                        }
                        return request;
                    }
                },
                formatters: {
                    "clientpubkey": function (column, row) {
                        const key = row.pubkey || '';
                        const shortKey = key.length > 20 ? (key.substring(0, 10) + '...' + key.substring(key.length - 8)) : key;
                        return '<span class="text-monospace">' + shortKey + '</span> ' +
                            '<button type="button" class="btn btn-xs btn-default command-copykey" data-key="' + key + '" title="{{ lang._("Copy") }}">' +
                            '<i class="fa fa-copy"></i></button>';
                    },
                    "serverendpoint": function (column, row) {
                        const endpoint = row.serveraddress ? (row.serveraddress + ':' + (row.serverport || '51820')) : '';
                        if (!endpoint) {
                            return '<span class="text-muted">-</span>';
                        }
                        return endpoint;
                    },
                    "tunnelrouting": function (column, row) {
                        const routes = String(row.tunnelrouting || '').trim();
                        if (!routes) {
                            return '<span class="label label-primary">Full Tunnel</span> <span class="text-muted">0.0.0.0/0</span>';
                        }
                        const isFullTunnel = routes.indexOf('0.0.0.0/0') >= 0 || routes.indexOf('::/0') >= 0;
                        const routeLabel = $('<div/>').text(routes).html();
                        if (isFullTunnel) {
                            return '<span class="label label-primary">Full Tunnel</span> ' + routeLabel;
                        }
                        return '<span class="label label-success">Split Tunnel</span> ' + routeLabel;
                    },
                    "peerdns": function (column, row) {
                        const dnsValue = row.peer_dns || row.peerDns || row.dns || '';
                        return dnsValue || '-';
                    },
                    "configqr": function (column, row) {
                        return '<button type="button" class="btn btn-sm btn-primary command-recoverqr" data-row-id="' + row.uuid + '" title="{{ lang._("View QR/Config again") }}"><i class="fa fa-qrcode"></i> {{ lang._("View QR/Config") }}</button> ' +
                            '<button type="button" class="btn btn-xs btn-default command-viewqr" data-row-id="' + row.uuid + '" title="{{ lang._("View QR") }}"><i class="fa fa-qrcode"></i></button> ' +
                            '<button type="button" class="btn btn-xs btn-default command-downloadconf" data-row-id="' + row.uuid + '" title="{{ lang._("Download Config") }}"><i class="fa fa-download"></i></button>';
                    }
                }
            });

        grid_clienttosite.on("loaded.rs.jquery.bootgrid", function () {
            const table = $("#{{formGridWireguardClientList['table_id']}}");
            table.find(".command-copykey").off("click").on("click", function () {
                const key = $(this).data("key") || '';
                if (navigator.clipboard && key) {
                    navigator.clipboard.writeText(key);
                }
            });

            table.find(".command-viewqr, .command-recoverqr").off("click").on("click", function () {
                const uuid = $(this).data("row-id");
                ajaxGet('/api/wireguard/client/get_client/' + uuid, {}, function (data) {
                    if (!data.client) {
                        return;
                    }
                    const containerId = 'wg-client-qrcode-' + uuid;
                    const previewId = 'wg-client-config-' + uuid;
                    const endpointId = 'wg-client-endpoint-' + uuid;
                    const routingId = 'wg-client-routing-' + uuid;
                    const privkeyId = 'wg-client-privkey-' + uuid;
                    const downloadId = 'wg-client-download-' + uuid;
                    BootstrapDialog.show({
                        title: '{{ lang._("WireGuard config") }}',
                        size: BootstrapDialog.SIZE_WIDE,
                        message:
                            '<div class="row">' +
                                '<div class="col-md-4">' +
                                    '<label>{{ lang._("Server Endpoint") }}</label>' +
                                    '<input type="text" class="form-control" id="' + endpointId + '" value="' + $('<div/>').text((data.client.serveraddress ? (data.client.serveraddress + ':' + (data.client.serverport || '51820')) : '')).html() + '" placeholder="vpn.company.com:51820">' +
                                '</div>' +
                                '<div class="col-md-4">' +
                                    '<label>{{ lang._("Tunnel Routing") }}</label>' +
                                    '<input type="text" class="form-control" id="' + routingId + '" value="' + $('<div/>').text(data.client.tunnelrouting || '0.0.0.0/0').html() + '" placeholder="192.168.1.0/24">' +
                                '</div>' +
                                '<div class="col-md-4">' +
                                    '<label>Private key</label>' +
                                    '<input type="text" class="form-control" id="' + privkeyId + '" value="' + $('<div/>').text(c2sPrivateKeyCache || '').html() + '" placeholder="{{ lang._("Required for .conf/QR") }}">' +
                                '</div>' +
                            '</div>' +
                            '<hr/>' +
                            '<div class="row">' +
                                '<div class="col-md-7">' +
                                    '<textarea class="form-control" id="' + previewId + '" rows="14" readonly></textarea>' +
                                    '<button type="button" id="' + downloadId + '" class="btn btn-primary" style="margin-top:10px"><i class="fa fa-fw fa-download"></i> Download .conf</button>' +
                                '</div>' +
                                '<div class="col-md-5"><div id="' + containerId + '"></div></div>' +
                            '</div>'
                    });

                    const renderConfig = function () {
                        const endpoint = $('#' + endpointId).val();
                        const routing = $('#' + routingId).val();
                        const privateKey = $('#' + privkeyId).val();
                        const rows = [];
                        rows.push('[Interface]');
                        rows.push('PrivateKey = ' + (privateKey || '[REPLACE_WITH_CLIENT_PRIVATE_KEY]'));
                        if (data.client.tunneladdress) {
                            rows.push('Address = ' + data.client.tunneladdress);
                        }
                        rows.push('');
                        rows.push('[Peer]');
                        if (data.client.pubkey) {
                            rows.push('PublicKey = ' + data.client.pubkey);
                        }
                        if (endpoint) {
                            rows.push('Endpoint = ' + endpoint);
                        }
                        if (routing) {
                            rows.push('AllowedIPs = ' + routing);
                        }
                        const config = rows.join("\\n");
                        $('#' + previewId).val(config);
                        $('#' + containerId).empty().qrcode(config);
                    };

                    setTimeout(function () {
                        $('#' + endpointId + ', #' + routingId + ', #' + privkeyId).on('input', renderConfig);
                        $('#' + downloadId).on('click', function () {
                            const config = $('#' + previewId).val();
                            const fileName = (data.client.name || 'wireguard-client') + '.conf';
                            const blob = new Blob([config], {type: 'text/plain'});
                            const url = window.URL.createObjectURL(blob);
                            const a = document.createElement('a');
                            a.href = url;
                            a.download = fileName;
                            document.body.appendChild(a);
                            a.click();
                            document.body.removeChild(a);
                            window.URL.revokeObjectURL(url);
                        });
                        renderConfig();
                    }, 0);
                });
            });

            table.find(".command-downloadconf").off("click").on("click", function () {
                const uuid = $(this).data("row-id");
                ajaxGet('/api/wireguard/client/get_client/' + uuid, {}, function (data) {
                    if (!data.client) {
                        return;
                    }
                    const endpoint = data.client.serveraddress ? (data.client.serveraddress + ':' + (data.client.serverport || '51820')) : '';
                    const rows = [];
                    rows.push('[Interface]');
                    rows.push('PrivateKey = [REPLACE_WITH_CLIENT_PRIVATE_KEY]');
                    if (data.client.tunneladdress) {
                        rows.push('Address = ' + data.client.tunneladdress);
                    }
                    rows.push('');
                    rows.push('[Peer]');
                    if (data.client.pubkey) {
                        rows.push('PublicKey = ' + data.client.pubkey);
                    }
                    if (endpoint) {
                        rows.push('Endpoint = ' + endpoint);
                    }
                    rows.push('AllowedIPs = 0.0.0.0/0, ::/0');

                    const config = rows.join("\n");
                    const fileName = (data.client.name || 'wireguard-client') + '.conf';
                    const blob = new Blob([config], {type: 'text/plain'});
                    const url = window.URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = fileName;
                    document.body.appendChild(a);
                    a.click();
                    document.body.removeChild(a);
                    window.URL.revokeObjectURL(url);
                });
            });
        });

        const grid_instances = $("#{{formGridWireguardServer['table_id']}}").UIBootgrid({
            search: '/api/wireguard/server/search_server',
            get: '/api/wireguard/server/get_server/',
            set: '/api/wireguard/server/set_server/',
            add: '/api/wireguard/server/add_server/',
            del: '/api/wireguard/server/del_server/',
            toggle: '/api/wireguard/server/toggle_server/'
        });

        // ... (phần code trước vẫn giữ nguyên)

        grid_instances.on("loaded.rs.jquery.bootgrid", function () {
            const dlgSel = '#{{formGridWireguardServer["edit_dialog_id"]}}';

            // Reset form khi đóng dialog
            $(dlgSel).off('hidden.bs.modal.wg_reset').on('hidden.bs.modal.wg_reset', function (e) {
                // Clear instance field để detect Add mode đúng lần sau
                $("#server\\.instance").val('');
                console.log("Dialog closed - reset instance field");
            });

            // IMPORTANT: tránh bind lặp khi grid reload
            $(dlgSel).off('shown.bs.modal.wg_autofill').on('shown.bs.modal.wg_autofill', function (e) {
                console.log("Dialog opened");
                
                // Ẩn các trường không cần thiết
                $("tr[id='row_server\\.carp_depend_on']").hide();
                $("tr[id='row_server\\.disableroutes']").hide();
                
                // ====== CRITICAL: Kiểm tra Add/Edit mode và cleanup NGAY ======
                const isNewRecord = $("#server\\.instance").val() === '';
                
                if (isNewRecord) {
                    // Add mode: Clear tunnel address field và token tags từ lần trước
                    const $tunnelField = $("#server\\.tunneladdress");
                    $tunnelField.empty(); // Clear all old options
                    
                    // Clear token tags từ lần trước
                    const $tokenizerWidget = $tunnelField.parent().find('.tokenize');
                    if ($tokenizerWidget.length) {
                        const $container = $tokenizerWidget.find('.tokens-container');
                        // Remove all existing tokens except search box
                        $container.find('.token:not(.token-search)').remove();
                    }
                    console.log("Cleared old tunnel address data for Add mode");
                }
                
                // ====== CRITICAL: Debug và force refresh tokenizer ======
                // Kiểm tra ngay lập tức xem field có data không
                setTimeout(function() {
                    const $tunnelField = $("#server\\.tunneladdress");
                    console.log("=== TUNNEL ADDRESS DEBUG ===");
                    console.log("Field element:", $tunnelField);
                    console.log("Field exists:", $tunnelField.length > 0);
                    console.log("Field val():", $tunnelField.val());
                    console.log("Field data('data-value'):", $tunnelField.data('data-value'));
                    console.log("Field attr('value'):", $tunnelField.attr('value'));
                    console.log("Field parent HTML:", $tunnelField.parent().html());
                    console.log("=== END DEBUG ===");
                }, 50);
                
                // ====== Force refresh tokenizer sau khi dialog mở ======
                // Framework đã map data, nhưng tokenizer cần được trigger để hiển thị
                setTimeout(function() {
                    const $tunnelField = $("#server\\.tunneladdress");
                    const currentVal = $tunnelField.val();
                    console.log("Force refresh tokenizer (100ms) - Current value:", currentVal);
                    
                    if (currentVal && currentVal.length > 0) {
                        // Trigger change để tokenizer cập nhật UI
                        $tunnelField.trigger('change');
                        
                        // Force formatTokenizersUI
                        if (typeof formatTokenizersUI === 'function') {
                            formatTokenizersUI();
                        }
                    }
                }, 100);

                // ====== Helper: sync tunnel address theo instance ======
                function syncTunnelAddress(instanceId, overwrite = false) {
                    const idNum = parseInt(instanceId, 10);
                    const $tunnelSelect = $("#server\\.tunneladdress");
                    let currentValue = $tunnelSelect.val();
                    
                    // Kiểm tra xem field có giá trị hay không (xử lý cả array và string)
                    let isEmpty = false;
                    if (Array.isArray(currentValue)) {
                        isEmpty = currentValue.length === 0 || currentValue.every(v => !v || v.trim() === '');
                    } else {
                        isEmpty = !currentValue || currentValue.trim() === '';
                    }

                    // Chỉ tự động điền nếu Instance ID từ 1-254
                    if (Number.isFinite(idNum) && idNum >= 1 && idNum <= 254) {
                        const autoAddr = '10.' + idNum + '.0.1/24';
                        if (overwrite || isEmpty) {
                            // Đối với tokenizer, luôn set giá trị dạng mảng
                            $tunnelSelect.val([autoAddr]);
                            $tunnelSelect.trigger('change');
                            $tunnelSelect.attr('title', 'Địa chỉ mặc định: ' + autoAddr + '. Bạn có thể thêm, xóa hoặc sửa địa chỉ.');
                        }
                    } else {
                        // Instance ID > 254 hoặc không hợp lệ: xóa giá trị tự động, để người dùng tự điền
                        if (overwrite) {
                            $tunnelSelect.val([]);
                            $tunnelSelect.trigger('change');
                        }
                        $tunnelSelect.attr('title', 'Instance ID > 254: vui lòng nhập thủ công một hoặc nhiều địa chỉ mạng theo CIDR (ví dụ: 10.10.10.1/24). Nhấn Enter sau mỗi địa chỉ.');
                    }
                    
                    // Format lại tokenizer
                    if (typeof formatTokenizersUI === 'function') {
                        setTimeout(function() {
                            formatTokenizersUI();
                        }, 50);
                    }
                }

                // Xử lý khi instance ID thay đổi
                $("#server\\.instance")
                .off("change.wg_autotunnel")
                .on("change.wg_autotunnel", function () {
                    const idNum = parseInt($(this).val(), 10);

                    // remove old feedback
                    const oldFeedback = $(this).closest('.form-group').find('.invalid-feedback');
                    oldFeedback.remove();
                    $(this).removeClass('is-invalid');

                    // Chỉ hiển thị warning nếu instance ID KHÔNG hợp lệ (< 1 hoặc > 254)
                    // Không hiển thị gì nếu ID hợp lệ (1-254)
                    if (Number.isFinite(idNum) && (idNum < 1 || idNum > 254)) {
                        $('<div class="invalid-feedback" style="display:block">Instance ID từ 1-254 sẽ tự động sinh tunnel address. Ngoài phạm vi này bạn cần tự nhập Tunnel address.</div>')
                            .insertAfter($(this));
                        $(this).addClass('is-invalid');
                    }

                    // always sync tunnel address (rule: 1..254 auto, >254 blank)
                    syncTunnelAddress($(this).val(), true);
                });

                // Kiểm tra Add hay Edit (đã check ở đầu rồi, dùng lại biến)
                // const isNewRecord = $("#server\\.instance").val() === '';

                if (isNewRecord) {
                    // ===== Add mới: tự động sinh tất cả =====
                    // Đã clear tunnel address ở trên rồi, không cần clear nữa
                    
                    // Bước 1: Tạo keypair trước
                    ajaxGet("/api/wireguard/general/generateKeypair", {}, function (keypairData) {
                        if (keypairData.pubkey && keypairData.privkey) {
                            $("#server\\.pubkey").val(keypairData.pubkey);
                            $("#server\\.privkey").val(keypairData.privkey);
                            console.log("Keypair generated");
                        }
                    });
                    
                    // Bước 2: Gọi API getNewInstanceDefaults và điền các field
                    ajaxGet("/api/wireguard/general/getNewInstanceDefaults", {}, function (defaults) {
                        console.log("API getNewInstanceDefaults response:", defaults);
                        
                        if (defaults.instance !== undefined) {
                            // Điền các field đơn giản
                            $("#server\\.instance").val(defaults.instance);
                            $("#server\\.name").val(defaults.name || '');
                            $("#server\\.port").val(defaults.port || '');
                            
                            console.log("Set basic fields - instance:", defaults.instance, "name:", defaults.name, "port:", defaults.port);
                            
                            // Xử lý tunnel address - extract value từ object format
                            if (defaults.tunneladdress && typeof defaults.tunneladdress === 'object') {
                                // Lấy giá trị đầu tiên từ object
                                const tunnelValues = Object.keys(defaults.tunneladdress);
                                console.log("Tunnel address keys:", tunnelValues);
                                
                                if (tunnelValues.length > 0) {
                                    const tunnelAddr = tunnelValues[0];
                                    console.log("Extracted tunnel address:", tunnelAddr);
                                    
                                    // Đợi để DOM và tokenizer sẵn sàng
                                    setTimeout(function() {
                                        const $tunnelField = $("#server\\.tunneladdress");
                                        
                                        // CRITICAL: Clear tất cả options cũ trước khi thêm option mới
                                        // Tránh conflict khi đóng/mở dialog nhiều lần
                                        $tunnelField.empty();
                                        
                                        // Thêm option mới và select nó
                                        $tunnelField.append($('<option></option>').val(tunnelAddr).text(tunnelAddr).prop('selected', true));
                                        
                                        console.log("Added option to select, triggering format...");
                                        
                                        // Force re-initialize tokenizer - framework sẽ tự tạo token tags từ selected options
                                        if (typeof formatTokenizersUI === 'function') {
                                            formatTokenizersUI();
                                            console.log("Tokenizer re-initialized - framework will create token tags");
                                        }
                                        
                                        // Trigger change sau khi format
                                        setTimeout(function() {
                                            $tunnelField.trigger('change');
                                            console.log("Tunnel address set complete");
                                        }, 100);
                                    }, 250);
                                }
                            }
                            
                            // Refresh UI sau cùng
                            setTimeout(function() {
                                if (typeof formatTokenizersUI === 'function') {
                                    formatTokenizersUI();
                                }
                                $('.selectpicker').selectpicker('refresh');
                                console.log("UI refreshed - Add new instance");
                            }, 400);
                        }
                    });

                } else {
                    // ===== Edit: chỉ sinh field còn thiếu =====
                    // QUAN TRỌNG: Đợi form load xong data từ API trước (framework cần thời gian để map data)
                    setTimeout(function() {
                        const instanceId = $("#server\\.instance").val();
                        console.log("Edit mode - Instance ID:", instanceId);
                        
                        // Chỉ kích hoạt event handler, KHÔNG gọi syncTunnelAddress để tránh overwrite data
                        // Data đã được load từ API, chỉ cần setup event cho lần change tiếp theo
                        if (instanceId) {
                            // Trigger change chỉ để setup validation UI, không overwrite
                            const $tunnelField = $("#server\\.tunneladdress");
                            const currentTunnelValue = $tunnelField.val();
                            console.log("Current tunnel address:", currentTunnelValue);
                            
                            // Chỉ trigger validation, không sync lại tunnel address
                            const idNum = parseInt(instanceId, 10);
                            const oldFeedback = $("#server\\.instance").closest('.form-group').find('.invalid-feedback');
                            oldFeedback.remove();
                            $("#server\\.instance").removeClass('is-invalid');
                            
                            if (!Number.isFinite(idNum) || idNum < 1 || idNum > 254) {
                                $('<div class="invalid-feedback" style="display:block">Instance ID từ 1-254 sẽ tự động sinh tunnel address. Ngoài phạm vi này bạn cần tự nhập Tunnel address.</div>')
                                    .insertAfter($("#server\\.instance"));
                                $("#server\\.instance").addClass('is-invalid');
                            }
                        }

                        // Name nếu trống
                        if (!$("#server\\.name").val() && instanceId) {
                            ajaxGet("/api/wireguard/general/generateInstanceName/" + instanceId, {}, function (data) {
                                if (data.name) {
                                    $("#server\\.name").val(data.name);
                                }
                            });
                        }

                        // Listen port nếu trống
                        if (!$("#server\\.port").val()) {
                            ajaxGet("/api/wireguard/general/getNextListenPort", {}, function (data) {
                                if (data.port) {
                                    $("#server\\.port").val(data.port);
                                }
                            });
                        }

                        // keypair nếu trống
                        if ((!$("#server\\.pubkey").val() || !$("#server\\.privkey").val()) && 
                            confirm("Bạn chưa có keypair. Bạn có muốn tạo keypair mới không?")) {
                            ajaxGet("/api/wireguard/general/generateKeypair", {}, function (data) {
                                if (data.pubkey && data.privkey) {
                                    $("#server\\.pubkey").val(data.pubkey);
                                    $("#server\\.privkey").val(data.privkey);
                                }
                            });
                        }
                    }, 300); // Đợi 300ms để framework map data xong
                }
                
                // Format lại tokenizers sau khi tất cả đã load xong
                // Tăng timeout để đảm bảo data từ API đã được map xong vào form
                setTimeout(function() {
                    if (typeof formatTokenizersUI === 'function') {
                        formatTokenizersUI();
                    }
                    $('.selectpicker').selectpicker('refresh');
                    
                    // CRITICAL: Force refresh lần cuối cho tunnel address field
                    const $tunnelField = $("#server\\.tunneladdress");
                    const finalValue = $tunnelField.val();
                    console.log("Final refresh - Tunnel address value:", finalValue);
                    
                    if (finalValue && finalValue.length > 0) {
                        // Re-trigger formatTokenizersUI specifically for this field
                        $tunnelField.trigger('change');
                        
                        // Double check tokenizer is visible
                        setTimeout(function() {
                            if (typeof formatTokenizersUI === 'function') {
                                formatTokenizersUI();
                            }
                            console.log("All UI components refreshed");
                        }, 100);
                    } else {
                        console.log("All UI components refreshed");
                    }
                }, 400);
            });
        });

// ... (phần code sau vẫn giữ nguyên)

        $("#reconfigureAct").SimpleActionButton({
            onPreAction: function() {
                const dfObj = new $.Deferred();
                saveFormToEndpoint("/api/wireguard/general/set", 'frm_general_settings', function(){
                    dfObj.resolve();
                });
                return dfObj;
            }
        });

        /**
         * Move keypair generation button inside the instance form and hook api event
         */
        $("#control_label_server\\.pubkey").append($("#keygen_div").detach().show());
        $("#keygen").click(function(){
            ajaxGet("/api/wireguard/general/generateKeypair", {}, function(data, status){
                if (data.pubkey && data.privkey) {
                    $("#server\\.pubkey").val(data.pubkey);
                    $("#server\\.privkey").val(data.privkey);
                }
            });
        });
        
        $("#control_label_client\\.psk").append($("#pskgen_div").detach().show());
        $("#pskgen").click(function(){
            ajaxGet("/api/wireguard/client/psk", {}, function(data, status){
                if (data.status && data.status === 'ok') {
                    $("#client\\.psk").val(data.psk);
                }
            });
        });

        let c2sPrivateKeyCache = '';
        $("#control_label_client\\.pubkey").append($("#keygen_client_div").detach().show());
        $("#keygen_client").click(function(){
            ajaxGet("/api/wireguard/general/generateKeypair", {}, function(data, status){
                if (data.pubkey && data.privkey) {
                    c2sPrivateKeyCache = data.privkey;
                    $("#client\\.pubkey").val(data.pubkey).change();
                    const $privateField = $(peersDialogSelector + " #c2s_client_private_key");
                    if ($privateField.length > 0) {
                        $privateField.val(data.privkey).trigger('input');
                    }
                }
            });
        });

        let currentClientDialogMode = 's2s';
        const peersDialogSelector = '#{{formGridWireguardClient["edit_dialog_id"]}}';
        const resolveClientDialogIsC2S = function ($dialog) {
            const activeTabId = String($('#maintabs li.active a').attr('id') || '');
            if (activeTabId === 'tab_clienttosite') {
                return true;
            }
            if (activeTabId === 'tab_peers') {
                return false;
            }

            const typeValue = String($dialog.find('#client\\.type').val() || '').trim().toLowerCase();
            if (typeValue === 'c2s') {
                return true;
            }
            if (typeValue === 's2s') {
                return false;
            }

            return currentClientDialogMode === 'c2s';
        };
        const updateC2sRoutingBadge = function ($dialog) {
            const mode = String($dialog.find('#c2s_tunnel_mode').val() || 'full');
            const $badge = $dialog.find('#c2s_routing_badge');
            $badge.removeClass('label-primary label-success');
            if (mode === 'full') {
                $badge.addClass('label-primary').text('{{ lang._("Full Tunnel") }}');
            } else {
                $badge.addClass('label-success').text('{{ lang._("Split Tunnel") }}');
            }
        };

        const getC2sRoutingValue = function ($dialog) {
            const mode = String($dialog.find('#c2s_tunnel_mode').val() || 'full');
            if (mode === 'split') {
                const splitNetwork = String($dialog.find('#c2s_split_network').val() || '').trim();
                return splitNetwork || '192.168.1.0/24';
            }
            return '0.0.0.0/0';
        };

        const applyEndpointFromInstance = function ($dialog, endpoint) {
            const endpointValue = String(endpoint || '').trim();
            let endpointHost = '';
            let endpointPort = '51820';

            if (endpointValue.length > 0) {
                const bracketMatch = endpointValue.match(/^\[([^\]]+)\](?::([0-9]{1,5}))?$/);
                if (bracketMatch) {
                    endpointHost = String(bracketMatch[1] || '').trim();
                    endpointPort = String(bracketMatch[2] || endpointPort).trim();
                } else {
                    const firstColon = endpointValue.indexOf(':');
                    const lastColon = endpointValue.lastIndexOf(':');
                    if (firstColon !== -1 && firstColon === lastColon) {
                        endpointHost = String(endpointValue.substring(0, lastColon) || '').trim();
                        endpointPort = String(endpointValue.substring(lastColon + 1) || endpointPort).trim();
                    } else {
                        endpointHost = endpointValue;
                    }
                }
            }

            $dialog.find('#client\\.serveraddress').val(endpointHost);
            $dialog.find('#client\\.serverport').val(endpointHost.length > 0 ? endpointPort : '');

            const $c2sEndpointField = $dialog.find('#c2s_server_endpoint');
            if ($c2sEndpointField.length > 0) {
                if (endpointHost.length > 0) {
                    $c2sEndpointField.val(endpointHost + ':' + endpointPort);
                } else {
                    $c2sEndpointField.val('');
                }
            }
        };

        const syncC2sConfigPreview = function ($dialog) {
            const endpoint = String($dialog.find('#c2s_server_endpoint').val() || '').trim();
            const routing = getC2sRoutingValue($dialog);
            const dnsServers = String($dialog.find('#c2s_dns_servers').val() || '').trim();
            const privateKey = String($dialog.find('#c2s_client_private_key').val() || '').trim();
            $dialog.find('#client\\.peer_dns').val(dnsServers);
            $dialog.find('#client\\.tunnelrouting').val(routing);
            const $serverAddressField = $dialog.find('#client\\.serveraddress');
            const $serverPortField = $dialog.find('#client\\.serverport');
            const $assignedField = $dialog.find('#client\\.tunneladdress');
            let assignedList = [];
            const assignedRaw = $assignedField.val();

            // Keep persisted endpoint fields in sync with the C2S helper input.
            let endpointHost = '';
            let endpointPort = '51820';
            if (endpoint.length > 0) {
                const bracketMatch = endpoint.match(/^\[([^\]]+)\](?::([0-9]{1,5}))?$/);
                if (bracketMatch) {
                    endpointHost = String(bracketMatch[1] || '').trim();
                    endpointPort = String(bracketMatch[2] || endpointPort).trim();
                } else {
                    const firstColon = endpoint.indexOf(':');
                    const lastColon = endpoint.lastIndexOf(':');
                    if (firstColon !== -1 && firstColon === lastColon) {
                        endpointHost = String(endpoint.substring(0, lastColon) || '').trim();
                        endpointPort = String(endpoint.substring(lastColon + 1) || endpointPort).trim();
                    } else {
                        endpointHost = endpoint;
                    }
                }
            }
            $serverAddressField.val(endpointHost);
            $serverPortField.val(endpointHost.length > 0 ? endpointPort : '');

            if (Array.isArray(assignedRaw)) {
                assignedList = assignedRaw;
            } else if (String(assignedRaw || '').trim().length > 0) {
                assignedList = String(assignedRaw).split(',');
            }

            // Tokenize/select_multiple may keep values in selected options or data-value.
            if (assignedList.length === 0) {
                assignedList = $assignedField.find('option:selected').map(function () {
                    return $(this).val();
                }).get();
            }
            if (assignedList.length === 0) {
                const dataValue = String($assignedField.attr('data-value') || '').trim();
                if (dataValue.length > 0) {
                    assignedList = dataValue.split(',');
                }
            }

            // Last fallback: read visible tokens when tokenizer UI has data but select value is stale.
            if (assignedList.length === 0) {
                assignedList = $assignedField.closest('td').find('.tokenize .tokens-container .token:not(.token-search)').map(function () {
                    return String($(this).text() || '').trim();
                }).get();
            }

            // Keep real select value in sync so HTML5 required validation works correctly.
            assignedList = assignedList
                .map(function (item) { return String(item || '').trim(); })
                .filter(function (item) { return item.length > 0; });

            // C2S uses a single Assigned Client IP; keep first entry and normalize mask.
            if (assignedList.length > 1) {
                assignedList = [assignedList[0]];
            }
            assignedList = assignedList.map(function (item) {
                const baseIp = String(item || '').split('/')[0].trim();
                return baseIp.length > 0 ? (baseIp + '/32') : '';
            }).filter(function (item) {
                return item.length > 0;
            });

            if (assignedList.length > 0) {
                $assignedField.find('option').prop('selected', false);
                assignedList.forEach(function (item) {
                    let $opt = $assignedField.find('option').filter(function () {
                        return String($(this).val() || '') === item;
                    });
                    if ($opt.length === 0) {
                        $assignedField.append($('<option/>').val(item).text(item));
                        $opt = $assignedField.find('option').filter(function () {
                            return String($(this).val() || '') === item;
                        });
                    }
                    $opt.prop('selected', true);
                });
                $assignedField.val(assignedList);
                $assignedField.attr('data-value', assignedList.join(','));
            }

            const assignedIp = assignedList.join(',');
            const publicKey = String($dialog.find('#client\\.pubkey').val() || '').trim();

            updateC2sRoutingBadge($dialog);

            const hasRequiredKeys = privateKey.length > 0 && publicKey.length > 0;
            const canRender = hasRequiredKeys && endpoint.length > 0 && assignedIp.length > 0;
            if (!canRender) {
                $dialog.find('#c2s_config_output').val('');
                $dialog.find('#c2s_config_qrcode').empty().hide();
                return;
            }

            const rows = [];
            rows.push('[Interface]');
            rows.push('PrivateKey = ' + privateKey);
            rows.push('Address = ' + assignedIp);
            if (dnsServers.length > 0) {
                rows.push('DNS = ' + dnsServers);
            }
            rows.push('');
            rows.push('[Peer]');
            rows.push('PublicKey = ' + publicKey);
            rows.push('Endpoint = ' + endpoint);
            rows.push('AllowedIPs = ' + routing);

            const config = rows.join("\\n");
            $dialog.find('#c2s_config_output').val(config);
            $dialog.find('#c2s_config_qrcode').empty().qrcode(config).show();
        };

        const setC2sAssignedClientIp = function ($dialog, rawValue) {
            const $assignedField = $dialog.find('#client\\.tunneladdress');
            const baseIp = String(rawValue || '').split('/')[0].trim();
            if (!baseIp) {
                return;
            }
            const normalized = baseIp + '/32';
            $assignedField.find('option').prop('selected', false);
            let $opt = $assignedField.find('option').filter(function () {
                return String($(this).val() || '') === normalized;
            });
            if ($opt.length === 0) {
                $assignedField.append($('<option/>').val(normalized).text(normalized));
                $opt = $assignedField.find('option').filter(function () {
                    return String($(this).val() || '') === normalized;
                });
            }
            $opt.prop('selected', true);
            $assignedField.val([normalized]).attr('data-value', normalized).trigger('change');
            if (typeof formatTokenizersUI === 'function') {
                formatTokenizersUI();
            }
        };

        const getC2sSelectedServers = function ($dialog) {
            const $serversField = $dialog.find('#client\\.servers');
            let raw = $serversField.val();
            if (Array.isArray(raw)) {
                return raw.map(function (item) {
                    return String(item || '').trim();
                }).filter(function (item) {
                    return item.length > 0;
                });
            }
            const value = String(raw || '').trim();
            if (value.length > 0) {
                return value.split(',').map(function (item) {
                    return String(item || '').trim();
                }).filter(function (item) {
                    return item.length > 0;
                });
            }
            const dataValue = String($serversField.attr('data-value') || '').trim();
            if (dataValue.length > 0) {
                return dataValue.split(',').map(function (item) {
                    return String(item || '').trim();
                }).filter(function (item) {
                    return item.length > 0;
                });
            }
            return [];
        };

        const enforceSingleC2sServerSelection = function ($dialog) {
            const $serversField = $dialog.find('#client\\.servers');
            const selectedServers = getC2sSelectedServers($dialog);
            if (selectedServers.length <= 1) {
                return selectedServers;
            }

            const firstServer = selectedServers[selectedServers.length - 1];
            $serversField.find('option').prop('selected', false);
            let $opt = $serversField.find('option').filter(function () {
                return String($(this).val() || '') === firstServer;
            });
            if ($opt.length === 0) {
                $serversField.append($('<option/>').val(firstServer).text(firstServer));
                $opt = $serversField.find('option').filter(function () {
                    return String($(this).val() || '') === firstServer;
                });
            }
            $opt.prop('selected', true);
            $serversField.val([firstServer]).attr('data-value', firstServer).trigger('change');
            if (typeof formatTokenizersUI === 'function') {
                formatTokenizersUI();
            }
            if ($serversField.hasClass('selectpicker')) {
                $serversField.selectpicker('refresh');
            }

            return [firstServer];
        };

        const hasC2sAssignedClientIp = function ($dialog) {
            const $assignedField = $dialog.find('#client\\.tunneladdress');
            const raw = $assignedField.val();
            if (Array.isArray(raw) && raw.length > 0) {
                return raw.some(function (item) {
                    return String(item || '').trim().length > 0;
                });
            }
            if (String(raw || '').trim().length > 0) {
                return true;
            }
            const dataValue = String($assignedField.attr('data-value') || '').trim();
            if (dataValue.length > 0) {
                return true;
            }
            const tokenCount = $assignedField.closest('td').find('.tokenize .tokens-container .token:not(.token-search)').length;
            return tokenCount > 0;
        };

        const applyC2sFrontendLabels = function ($dialog) {
            const $nameLabel = $dialog.find("tr[id='row_client\\.name'] label:first");
            if ($nameLabel.length > 0) {
                const originalNameLabel = $nameLabel.data('original-label') || $nameLabel.html();
                if (!$nameLabel.data('original-label')) {
                    $nameLabel.data('original-label', originalNameLabel);
                }
                $nameLabel.html('<strong>{{ lang._("Client Name") }}</strong>');
            }

            const $serversLabel = $dialog.find("tr[id='row_client\\.servers'] label:first");
            if ($serversLabel.length > 0) {
                const originalServersLabel = $serversLabel.data('original-label') || $serversLabel.html();
                if (!$serversLabel.data('original-label')) {
                    $serversLabel.data('original-label', originalServersLabel);
                }
                $serversLabel.html('<strong>{{ lang._("Instance") }}</strong>');
            }

            const $tunnelRow = $dialog.find("tr[id='row_client\\.tunneladdress']");
            const $tunnelLabelCell = $tunnelRow.find('td:first');
            if ($tunnelLabelCell.length > 0) {
                const originalLabelCellHtml = $tunnelLabelCell.data('original-label-cell') || $tunnelLabelCell.html();
                if (!$tunnelLabelCell.data('original-label-cell')) {
                    $tunnelLabelCell.data('original-label-cell', originalLabelCellHtml);
                }
                $tunnelLabelCell.html('<a href="#" class="showhelp"><i class="fa fa-info-circle"></i></a> <strong>{{ lang._("Assigned Client IP") }}</strong>');
            }

            const $label = $dialog.find('#control_label_client\\.tunneladdress');
            if ($label.length > 0) {
                const originalLabel = $label.data('original-label') || $label.html();
                if (!$label.data('original-label')) {
                    $label.data('original-label', originalLabel);
                }
                const originalWeight = $label.data('original-font-weight') || $label.css('font-weight');
                if (!$label.data('original-font-weight')) {
                    $label.data('original-font-weight', originalWeight);
                }
                $label.text('{{ lang._("Assigned Client IP") }}').css('font-weight', '700');
            }

            const $pubLabel = $dialog.find("tr[id='row_client\\.pubkey'] label:first");
            if ($pubLabel.length > 0) {
                const originalPubLabel = $pubLabel.data('original-label') || $pubLabel.html();
                if (!$pubLabel.data('original-label')) {
                    $pubLabel.data('original-label', originalPubLabel);
                }
                $pubLabel.html('<strong>{{ lang._("Client Public Key") }}</strong>');
            }
        };

        const setDialogMode = function (isC2S, $dialog) {
            $dialog.find('#client\\.type').val(isC2S ? 'c2s' : 's2s');
            $dialog.find('.modal-title').text(isC2S ? '{{ lang._("Edit client") }}' : '{{ lang._("Edit peer") }}');

            // Keep hidden/internal fields out of sight.
            $dialog.find("tr[id='row_client\\.type']").hide();
            $dialog.find("tr[id='row_client\\.serveraddress']").hide();
            $dialog.find("tr[id='row_client\\.serverport']").hide();
            $dialog.find("tr[id='row_client\\.tunnelrouting']").hide();
            $dialog.find("tr[id='row_client\\.peer_dns']").css('display', isC2S ? 'none' : '');
            $dialog.find("tr[id='row_client\\.keepalive']").css('display', isC2S ? 'none' : '');
            $dialog.find("tr[id='row_client\\.psk']").css('display', isC2S ? 'none' : '');
            
            // Show tunneladdress field for C2S mode with updated label
            const $tunnelRow = $dialog.find("tr[id='row_client\\.tunneladdress']");
            $tunnelRow.css('display', '');
            // Keep Assigned Client IP ahead of instance/endpoint specific rows.
            const $serversRow = $dialog.find("tr[id='row_client\\.servers']");
            if ($serversRow.length > 0) {
                $tunnelRow.insertBefore($serversRow);
            }
            const $tunnelLabelCell = $tunnelRow.find('td:first');
            
            // Update label for C2S mode
            if (isC2S) {
                applyC2sFrontendLabels($dialog);
                setTimeout(function () {
                    applyC2sFrontendLabels($dialog);
                }, 0);
                setTimeout(function () {
                    applyC2sFrontendLabels($dialog);
                }, 100);

                if ($dialog.find('#c2s_privatekey_row').length === 0) {
                    const privateRowHtml = '' +
                        '<tr id="c2s_privatekey_row">' +
                            '<td><a id="help_for_c2s_privatekey" href="#" class="showhelp" data-toggle="tooltip" data-placement="auto right" title="Private key for this client. You can specify your own one, or generate one with the gear button. Please keep this key safe."><i class="fa fa-info-circle"></i></a> <strong>{{ lang._("Client Private Key") }}</strong></td>' +
                            '<td><input id="c2s_client_private_key" type="text" class="form-control" /></td>' +
                            '<td class="vtable"></td>' +
                        '</tr>';
                    $dialog.find("tr[id='row_client\\.pubkey']").after(privateRowHtml);
                }

                $dialog.find('#client\\.servers').attr('required', 'required');
            } else {
                // Restore original label for S2S mode
                const originalLabelCellHtml = $tunnelLabelCell.data('original-label-cell');
                if (originalLabelCellHtml) {
                    $tunnelLabelCell.html(originalLabelCellHtml);
                }

                const $label = $dialog.find('#control_label_client\\.tunneladdress');
                const originalLabel = $label.data('original-label');
                if (originalLabel) {
                    $label.html(originalLabel);
                }
                const originalWeight = $label.data('original-font-weight');
                if (originalWeight) {
                    $label.css('font-weight', originalWeight);
                } else {
                    $label.css('font-weight', '');
                }

                const $pubLabel = $dialog.find("tr[id='row_client\\.pubkey'] label:first");
                const originalPubLabel = $pubLabel.data('original-label');
                if (originalPubLabel) {
                    $pubLabel.html(originalPubLabel);
                }
                const $nameLabel = $dialog.find("tr[id='row_client\\.name'] label:first");
                const originalNameLabel = $nameLabel.data('original-label');
                if (originalNameLabel) {
                    $nameLabel.html(originalNameLabel);
                }
                const $serversLabel = $dialog.find("tr[id='row_client\\.servers'] label:first");
                const originalServersLabel = $serversLabel.data('original-label');
                if (originalServersLabel) {
                    $serversLabel.html(originalServersLabel);
                }
                $dialog.find('#c2s_privatekey_row').remove();

                $dialog.find('#client\\.servers').removeAttr('required');
            }

            $dialog.find('.c2s-config-row').remove();
            if (!isC2S) {
                const syncS2sEndpointFromServer = function () {
                    const selectedServers = getC2sSelectedServers($dialog);
                    if (selectedServers.length === 0) {
                        return;
                    }
                    ajaxGet('/api/wireguard/client/get_server_info/' + selectedServers[0], {}, function(data) {
                        if (data.status === 'ok' && data.endpoint) {
                            applyEndpointFromInstance($dialog, data.endpoint);
                        }
                    });
                };
                $dialog.find('#client\\.servers')
                    .off('change.s2sEndpointSync changed.bs.select.s2sEndpointSync')
                    .on('change.s2sEndpointSync changed.bs.select.s2sEndpointSync', function () {
                        syncS2sEndpointFromServer();
                    });

                if (getC2sSelectedServers($dialog).length > 0) {
                    syncS2sEndpointFromServer();
                }

                $dialog.find('#client\\.servers').off('change.c2sAutoIp');
                return;
            }

            const exportHtml = '' +
                '<tr id="c2s_cfg_endpoint_row" class="c2s-config-row" style="display:none;">' +
                    '<td><a href="#" class="showhelp c2s-toggle-help" data-target="#c2s_help_server_endpoint" title="{{ lang._("Show details") }}"><i class="fa fa-info-circle"></i></a> {{ lang._("Server Endpoint") }}</td>' +
                    '<td><input id="c2s_server_endpoint" type="hidden" /></td>' +
                    '<td class="vtable"></td>' +
                '</tr>' +
                '<tr id="c2s_cfg_routing_row" class="c2s-config-row">' +
                    '<td><a href="#" class="showhelp c2s-toggle-help" data-target="#c2s_help_tunnel_routing" title="{{ lang._("Show details") }}"><i class="fa fa-info-circle"></i></a> {{ lang._("Tunnel Routing") }} <span id="c2s_routing_badge" class="label label-primary">{{ lang._("Full Tunnel") }}</span></td>' +
                    '<td>' +
                        '<select id="c2s_tunnel_mode" class="form-control" required="required">' +
                            '<option value="full" selected="selected">{{ lang._("Full Tunnel") }} (0.0.0.0/0)</option>' +
                            '<option value="split">{{ lang._("Split Tunnel") }} (192.168.1.0/24)</option>' +
                        '</select>' +
                        '<input id="c2s_split_network" type="text" class="form-control" value="192.168.1.0/24" style="margin-top:8px; display:none;" />' +
                        '<div id="c2s_help_tunnel_routing" class="help-block c2s-help-text" style="display:none;">{{ lang._("Choose Full Tunnel or Split Tunnel. Split mode uses company LAN range.") }}</div>' +
                    '</td>' +
                    '<td class="vtable"></td>' +
                '</tr>' +
                '<tr id="c2s_cfg_dns_row" class="c2s-config-row">' +
                    '<td><a href="#" class="showhelp c2s-toggle-help" data-target="#c2s_help_dns_servers" title="{{ lang._("Show details") }}"><i class="fa fa-info-circle"></i></a> {{ lang._("DNS Servers") }}</td>' +
                    '<td><input id="c2s_dns_servers" type="text" class="form-control" placeholder="1.1.1.1, 8.8.8.8" /><div id="c2s_help_dns_servers" class="help-block c2s-help-text" style="display:none;">{{ lang._("List of DNS server IPs separated by comma.") }}</div></td>' +
                    '<td class="vtable"></td>' +
                '</tr>' +
                '<tr id="c2s_cfg_output_row" class="c2s-config-row">' +
                    '<td><a id="help_for_c2s_config_qr" href="#" class="showhelp"><i class="fa fa-info-circle"></i></a> {{ lang._("Config / QR Code") }}</td>' +
                    '<td>' +
                        '<textarea id="c2s_config_output" class="form-control" rows="10" readonly></textarea>' +
                        '<button id="c2s_download_config" type="button" class="btn btn-primary" style="margin-top:10px"><i class="fa fa-fw fa-download"></i> {{ lang._("Download .conf") }}</button>' +
                        '<button id="c2s_download_qr" type="button" class="btn btn-primary" style="margin-top:10px; margin-left:8px"><i class="fa fa-fw fa-qrcode"></i> {{ lang._("Download QR") }}</button>' +
                    '</td>' +
                    '<td class="vtable"><div id="c2s_config_qrcode" style="display:none;"></div></td>' +
                '</tr>';
            $dialog.find("tr[id='row_client\\.servers']").after(exportHtml);

            const endpointDefault = String($dialog.find('#client\\.serveraddress').val() || '').trim();
            const portDefault = String($dialog.find('#client\\.serverport').val() || '').trim();
            if (endpointDefault.length > 0) {
                $dialog.find('#c2s_server_endpoint').val(endpointDefault + ':' + (portDefault || '51820'));
            }
            const persistedDnsServers = String($dialog.find('#client\\.peer_dns').val() || '').trim();
            if (persistedDnsServers.length > 0) {
                $dialog.find('#c2s_dns_servers').val(persistedDnsServers);
            }
            const persistedRouting = String($dialog.find('#client\\.tunnelrouting').val() || '').trim();
            if (persistedRouting.length > 0) {
                const isFull = persistedRouting.indexOf('0.0.0.0/0') >= 0 || persistedRouting.indexOf('::/0') >= 0;
                if (isFull) {
                    $dialog.find('#c2s_tunnel_mode').val('full');
                } else {
                    $dialog.find('#c2s_tunnel_mode').val('split');
                    $dialog.find('#c2s_split_network').val(persistedRouting);
                }
            }
            if (c2sPrivateKeyCache.length > 0) {
                $dialog.find('#c2s_client_private_key').val(c2sPrivateKeyCache);
            }

            $dialog.find('#c2s_tunnel_mode').off('change.c2sRouting').on('change.c2sRouting', function () {
                const isSplit = String($(this).val() || '') === 'split';
                const $splitInput = $dialog.find('#c2s_split_network');
                if (isSplit) {
                    $splitInput.show().attr('required', 'required');
                } else {
                    $splitInput.hide().removeAttr('required');
                }
                syncC2sConfigPreview($dialog);
            });
            $dialog.find('#c2s_tunnel_mode').trigger('change');

            $dialog.find('.c2s-toggle-help').off('click.c2sHelp').on('click.c2sHelp', function (e) {
                e.preventDefault();
                const target = String($(this).data('target') || '');
                if (!target) {
                    return;
                }
                const $target = $dialog.find(target);
                if ($target.length > 0) {
                    $target.stop(true, true).slideToggle(120);
                }
            });

            // Function to auto-suggest IP from selected instance
            const autoSuggestIp = function () {
                const selectedServers = enforceSingleC2sServerSelection($dialog);
                if (selectedServers.length === 0) {
                    return;
                }
                ajaxGet('/api/wireguard/client/get_server_info/' + selectedServers[0], {}, function(data) {
                    if (data.status === 'ok') {
                        if (data.address) {
                            setC2sAssignedClientIp($dialog, data.address);
                        }
                        if (data.endpoint) {
                            applyEndpointFromInstance($dialog, data.endpoint);
                        }
                        if (data.peer_dns) {
                            $dialog.find('#c2s_dns_servers').val(data.peer_dns);
                        }
                        syncC2sConfigPreview($dialog);
                    } else {
                        alert('{{ lang._("Failed to get server information") }}');
                    }
                });
            };

            // Auto-suggest when instance changes
            $dialog.find('#client\\.servers').off('change.c2sAutoIp changed.bs.select.c2sAutoIp').on('change.c2sAutoIp changed.bs.select.c2sAutoIp', function () {
                autoSuggestIp();
            });

            if (!hasC2sAssignedClientIp($dialog) && enforceSingleC2sServerSelection($dialog).length > 0) {
                setTimeout(function () {
                    autoSuggestIp();
                }, 50);
            }

            $dialog.find('#c2s_server_endpoint, #c2s_tunnel_mode, #c2s_split_network, #c2s_dns_servers, #c2s_client_private_key, #client\\.tunneladdress, #client\\.pubkey')
                .off('input.c2sPreview change.c2sPreview')
                .on('input.c2sPreview change.c2sPreview', function () {
                    syncC2sConfigPreview($dialog);
                });

            // Ensure tokenized Allowed IPs are synchronized right before Save validation.
            $dialog.find('button[id^="btn_"][id$="_save"]').off('click.c2sSync').on('click.c2sSync', function () {
                syncC2sConfigPreview($dialog);
                // Hard overwrite value persisted to DB: Assigned Client IP -> Allowed IPs field.
                const assigned = String($dialog.find('#client\\.tunneladdress').attr('data-value') || '').split(',').map(function (s) {
                    return String(s || '').trim();
                }).filter(function (s) {
                    return s.length > 0;
                });
                if (assigned.length > 0) {
                    const first = assigned[0];
                    const firstBaseIp = String(first || '').split('/')[0].trim();
                    const normalized = firstBaseIp.length > 0 ? (firstBaseIp + '/32') : '';
                    if (!normalized) {
                        return;
                    }
                    const $assignedField = $dialog.find('#client\\.tunneladdress');
                    $assignedField.find('option').prop('selected', false);
                    let $opt = $assignedField.find('option').filter(function () {
                        return String($(this).val() || '') === normalized;
                    });
                    if ($opt.length === 0) {
                        $assignedField.append($('<option/>').val(normalized).text(normalized));
                        $opt = $assignedField.find('option').filter(function () {
                            return String($(this).val() || '') === normalized;
                        });
                    }
                    $opt.prop('selected', true);
                    $assignedField.val([normalized]).attr('data-value', normalized).trigger('change');
                }
            });

            $dialog.find('#c2s_download_config').off('click').on('click', function () {
                // Ensure preview is up-to-date before reading text to download.
                syncC2sConfigPreview($dialog);

                const config = String($dialog.find('#c2s_config_output').val() || '').trim();
                if (!config) {
                    alert('{{ lang._("Configuration is empty. Please verify Endpoint, Assigned Client IP and Private Key.") }}');
                    return;
                }

                const safeName = String($dialog.find('#client\\.name').val() || 'wireguard-client').trim() || 'wireguard-client';
                const fileName = safeName + '.conf';
                const blob = new Blob([config], {type: 'text/plain;charset=utf-8'});

                if (window.navigator && window.navigator.msSaveOrOpenBlob) {
                    window.navigator.msSaveOrOpenBlob(blob, fileName);
                    return;
                }

                const url = (window.URL || window.webkitURL).createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = fileName;
                a.style.display = 'none';
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                setTimeout(function () {
                    (window.URL || window.webkitURL).revokeObjectURL(url);
                }, 1000);
            });

            $dialog.find('#c2s_download_qr').off('click').on('click', function () {
                syncC2sConfigPreview($dialog);

                const $qrContainer = $dialog.find('#c2s_config_qrcode');
                const canvas = $qrContainer.find('canvas').get(0);
                const img = $qrContainer.find('img').get(0);
                let dataUrl = '';

                if (canvas && typeof canvas.toDataURL === 'function') {
                    dataUrl = canvas.toDataURL('image/png');
                } else if (img && img.src) {
                    dataUrl = img.src;
                }

                if (!dataUrl) {
                    alert('{{ lang._("QR code is empty. Please verify config fields first.") }}');
                    return;
                }

                const safeName = String($dialog.find('#client\\.name').val() || 'wireguard-client').trim() || 'wireguard-client';
                const fileName = safeName + '-qr.png';
                const a = document.createElement('a');
                a.href = dataUrl;
                a.download = fileName;
                a.style.display = 'none';
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
            });

            syncC2sConfigPreview($dialog);
        };

        $(peersDialogSelector).on('shown.bs.modal', function () {
            const $dialog = $(this);
            const isC2SDialog = resolveClientDialogIsC2S($dialog);
            currentClientDialogMode = isC2SDialog ? 'c2s' : 's2s';
            setDialogMode(isC2SDialog, $dialog);
            
            // Auto-suggest IP for new C2S clients or when tunneladdress is empty
            if (isC2SDialog) {
                setTimeout(function () {
                    const selectedServers = enforceSingleC2sServerSelection($dialog);
                    
                    // Auto-fill if no address is set and an instance is selected
                    if (!hasC2sAssignedClientIp($dialog) && selectedServers.length > 0) {
                        ajaxGet('/api/wireguard/client/get_server_info/' + selectedServers[0], {}, function(data) {
                            if (data.status === 'ok' && data.address) {
                                setC2sAssignedClientIp($dialog, data.address);
                                applyEndpointFromInstance($dialog, data.endpoint || '');
                                if (data.peer_dns) {
                                    $dialog.find('#c2s_dns_servers').val(data.peer_dns);
                                }
                                syncC2sConfigPreview($dialog);
                            }
                        });
                    }
                }, 100);
            }
        });

        /**
         * Quick instance filter on top
         */
        $("#filter_container").detach().insertAfter('#{{formGridWireguardClient["table_id"]}}-header .search');
        $("#server_filter").change(function(){
            $("#{{formGridWireguardClient['table_id']}}").bootgrid('reload');
            $("#{{formGridWireguardClientList['table_id']}}").bootgrid('reload');
                });

        /**
         * Peer generator tab hooks
         */
        $("#control_label_configbuilder\\.psk").append($("#pskgen_cb_div").detach().show());
        $("#pskgen_cb").click(function(){
            ajaxGet("/api/wireguard/client/psk", {}, function(data, status){
                if (data.status && data.status === 'ok') {
                    $("#configbuilder\\.psk").val(data.psk).change();
                }
            });
        });
        
        // Thêm nút Download config bên cạnh QR code
        let downloadBtn = $('<button id="download_config" type="button" class="btn btn-primary" style="margin-left:10px" title="Download WireGuard config"><i class="fa fa-fw fa-download"></i> Download Config</button>');
        $("#control_label_configbuilder\\.output").append(downloadBtn);
        
        $("#download_config").click(function(){
            let config = $("#configbuilder\\.output").val();
            let peerName = $("#configbuilder\\.name").val() || 'wireguard-peer';
            let blob = new Blob([config], {type: 'text/plain'});
            let url = window.URL.createObjectURL(blob);
            let a = document.createElement('a');
            a.href = url;
            a.download = peerName + '.conf';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            window.URL.revokeObjectURL(url);
        });
        
        let tmp = $("#configbuilder\\.output").closest('tr');
        tmp.find('td:eq(2)').empty().append($("<div id='qrcode'/>"));
        $("#configbuilder\\.output").css('max-width', '100%');
        $("#configbuilder\\.output").css('height', '256px');
        $("#configbuilder\\.output").change(function(){
            $('#qrcode').empty().qrcode($(this).val());
        });

        $("#configbuilder\\.servers").change(function(){
            ajaxGet('/api/wireguard/client/get_server_info/' + $(this).val(), {}, function(data, status) {
                if (data.status === 'ok') {
                    let peer_dns = $("#configbuilder\\.peer_dns");
                    $("#configbuilder\\.address").val(data.address);
                    
                    // Cập nhật DNS servers
                    peer_dns
                        .val(data.peer_dns)
                        .data('org-value', data.peer_dns);

                    // Tách endpoint thành IP và port
                    if (data.endpoint) {
                        let parts = data.endpoint.split(':');
                        let endpointIp = parts[0] || '';
                        let endpointPort = parts[1] || '51820';
                        
                        $("#configbuilder\\.endpoint_ip").val(endpointIp).data('org-value', endpointIp).selectpicker('refresh');
                        $("#configbuilder\\.endpoint_port").val(endpointPort);
                    }
                    
                    // Lưu MTU và pubkey
                    $("#configbuilder\\.endpoint_ip").data('mtu', data.mtu).data('pubkey', data.pubkey);
                    $("#configbuilder\\.endpoint_ip").change();
                }
            });
        });

        $("#configbuilder\\.store_btn").replaceWith($("#btn_configbuilder_save"));

        $("#btn_configbuilder_save").click(function(){
            let instance_id = $("#configbuilder\\.servers").val();
            let endpointIp = $("#configbuilder\\.endpoint_ip").val();
            let endpointPort = $("#configbuilder\\.endpoint_port").val() || '51820';
            let endpoint = endpointIp + ':' + endpointPort;
            let peer_dns = $("#configbuilder\\.peer_dns");
            
            // Kiểm tra các trường bắt buộc
            if (!instance_id) {
                alert("{{ lang._('Please select a server instance') }}");
                return;
            }
            
            if (!$("#configbuilder\\.name").val()) {
                alert("{{ lang._('Please enter a peer name') }}");
                return;
            }
            
            let peer = {
                configbuilder: {
                    enabled: '1',
                    type: 'c2s',
                    name: String($("#configbuilder\\.name").val() || ''),
                    pubkey: String($("#configbuilder\\.pubkey").val() || ''),
                    psk: String($("#configbuilder\\.psk").val() || ''),
                    tunneladdress: String($("#configbuilder\\.address").val() || ''),
                    keepalive: String($("#configbuilder\\.keepalive").val() || ''),
                    server: String(instance_id || ''),
                    // Gửi serveraddress và serverport riêng biệt để hiển thị trong grid
                    serveraddress: String(endpointIp || ''),
                    serverport: String(endpointPort || ''),
                    peer_dns: String(peer_dns.val() || '')
                }
            };
            
            console.log('Sending peer data:', peer);
            
            ajaxCall('/api/wireguard/client/add_client_builder', peer, function(data, status) {
                console.log('Response received:', data);
                if (data.validations) {
                    if (data.validations['configbuilder.tunneladdress']) {
                        /*
                            tunnel address for the client is this peers address, since we remap these
                            in the form, we should remap the errors as well.
                        */
                        data.validations['configbuilder.address'] = data.validations['configbuilder.tunneladdress'];
                        delete data.validations['configbuilder.tunneladdress'];
                    }
                    handleFormValidation("frm_config_builder", data.validations);
                } else if (data.result === 'saved') {
                    // Hiển thị thông báo thành công với cấu hình
                    if (data.peer) {
                        let message = '<div style="max-height: 500px; overflow-y: auto;">';
                        message += '<h4 style="color: #5cb85c; margin-top: 0;">✓ Peer Created Successfully!</h4>';
                        message += '<hr style="margin: 10px 0;">';
                        
                        message += '<h5><strong>Peer Information:</strong></h5>';
                        message += '<table class="table table-condensed" style="margin-bottom: 15px;">';
                        message += '<tr><td style="width: 150px;"><strong>Name:</strong></td><td>' + data.peer.name + '</td></tr>';
                        message += '<tr><td><strong>Public Key:</strong></td><td><code style="font-size: 11px;">' + data.peer.pubkey + '</code></td></tr>';
                        message += '<tr><td><strong>Tunnel Address:</strong></td><td><code>' + data.peer.tunneladdress + '</code></td></tr>';
                        if (data.peer.serveraddress) {
                            message += '<tr><td><strong>Endpoint Address:</strong></td><td><code>' + data.peer.serveraddress + '</code></td></tr>';
                        }
                        if (data.peer.serverport) {
                            message += '<tr><td><strong>Endpoint Port:</strong></td><td><code>' + data.peer.serverport + '</code></td></tr>';
                        }
                        if (data.peer.keepalive) {
                            message += '<tr><td><strong>Keep Alive:</strong></td><td>' + data.peer.keepalive + 's</td></tr>';
                        }
                        if (data.peer.psk) {
                            message += '<tr><td><strong>Pre-shared Key:</strong></td><td>' + data.peer.psk + '</td></tr>';
                        }
                        message += '</table>';
                        
                        if (data.server) {
                            message += '<h5><strong>Server Information:</strong></h5>';
                            message += '<table class="table table-condensed" style="margin-bottom: 15px;">';
                            message += '<tr><td style="width: 150px;"><strong>Instance:</strong></td><td>' + data.server.name + '</td></tr>';
                            message += '<tr><td><strong>Endpoint:</strong></td><td><code>' + data.server.endpoint + '</code></td></tr>';
                            message += '<tr><td><strong>Server Pubkey:</strong></td><td><code style="font-size: 11px;">' + data.server.pubkey + '</code></td></tr>';
                            message += '</table>';
                        }
                        
                        if (data.config_preview) {
                            message += '<h5><strong>Configuration Preview:</strong></h5>';
                            message += '<pre style="background: #f5f5f5; padding: 10px; border-radius: 4px; font-size: 12px; max-height: 250px; overflow-y: auto;">' + data.config_preview + '</pre>';
                            message += '<p style="color: #888; font-size: 12px; margin-top: 10px;"><em>Note: Remember to use the actual private key from the form when creating the config file.</em></p>';
                        }
                        
                        message += '</div>';
                        
                        // Hiển thị modal với thông tin
                        BootstrapDialog.show({
                            type: BootstrapDialog.TYPE_SUCCESS,
                            title: 'Peer Created Successfully',
                            message: message,
                            size: BootstrapDialog.SIZE_WIDE,
                            buttons: [{
                                label: 'Close',
                                cssClass: 'btn-success',
                                action: function(dialogRef) {
                                    dialogRef.close();
                                }
                            }]
                        });
                        
                        console.log('Peer created:', data);
                    }
                    
                    if (endpointIp != $("#configbuilder\\.endpoint_ip").data('org-value') || peer_dns.val() != peer_dns.data('org-value')) {
                        // Đảm bảo tất cả giá trị là string, không phải array
                        let endpointValue = String(endpoint || '');
                        let peerDnsValue = String(peer_dns.val() || '');
                        
                        let param = {
                            'server': {
                                'endpoint': endpointValue,
                                'peer_dns': peerDnsValue
                            }
                        };
                        
                        console.log('Updating server with param:', param);
                        
                        ajaxCall('/api/wireguard/server/set_server/' + instance_id, param, function(data, status){
                            // Reload tab peers để hiển thị cấu hình mới
                            $("#{{formGridWireguardClient['table_id']}}").bootgrid('reload');
                            configbuilder_new();
                        });
                    } else {
                        // Reload tab peers để hiển thị cấu hình mới
                        $("#{{formGridWireguardClient['table_id']}}").bootgrid('reload');
                        configbuilder_new();
                    }
                } else if (data.error) {
                    // Hiển thị lỗi từ API
                    BootstrapDialog.show({
                        type: BootstrapDialog.TYPE_DANGER,
                        title: '{{ lang._("Error") }}',
                        message: '<div class="alert alert-danger">' + data.error + '</div>',
                        buttons: [{
                            label: '{{ lang._("Close") }}',
                            action: function(dialogRef) {
                                dialogRef.close();
                            }
                        }]
                    });
                } else {
                    console.warn('Unexpected response:', data);
                }
            });
        });
        
        $('input[id ^= "configbuilder\\."]').change(configbuilder_update_config);
        $('select[id ^= "configbuilder\\."]').change(configbuilder_update_config);

        function configbuilder_new() {
            mapDataToFormUI({'frm_config_builder':"/api/wireguard/client/get_client_builder"}).done(function(data){
                formatTokenizersUI();
                $('.selectpicker').selectpicker('refresh');
                
                // Tự động sinh keypair
                ajaxGet("/api/wireguard/server/key_pair", {}, function(data, status){
                    if (data.status && data.status === 'ok') {
                        $("#configbuilder\\.pubkey").val(data.pubkey);
                        $("#configbuilder\\.privkey").val(data.privkey).change();
                    }
                });
                
                // Tự động điền hostname vào Name
                ajaxGet("/api/wireguard/general/generateInstanceName/0", {}, function(data) {
                    if (data.name) {
                        let hostname = data.name.split('_VPN_')[0];
                        $("#configbuilder\\.name").val(hostname);
                    }
                });
                
                // Set mặc định Keepalive = 3
                $("#configbuilder\\.keepalive").val("3");
                
                // Set mặc định Endpoint port = 51820
                $("#configbuilder\\.endpoint_port").val("51820");
                
                // Mặc định Allowed IPs
                $("#configbuilder\\.tunneladdress").val("0.0.0.0/0,::/0");
                
                // Load danh sách IPs của firewall cho Endpoint IP dropdown (single select)
                ajaxGet("/api/wireguard/general/getFirewallIps", {}, function(data) {
                    if (data.ips) {
                        let select = $("#configbuilder\\.endpoint_ip");
                        select.empty();
                        select.append($('<option></option>').val("").text("-- " + "{{ lang._('Select or enter custom') }}" + " --"));
                        data.ips.forEach(function(ip) {
                            select.append($('<option></option>').val(ip.value).text(ip.label));
                        });
                        select.selectpicker('refresh');
                    }
                });
                
                // Load danh sách DNS servers cho DNS dropdown
                ajaxGet("/api/wireguard/general/getCommonDns", {}, function(data) {
                    if (data.dns) {
                        let select = $("#configbuilder\\.peer_dns");
                        select.empty();
                        data.dns.forEach(function(dns) {
                            select.append($('<option></option>').val(dns.value).text(dns.label));
                        });
                        select.selectpicker('refresh');
                    }
                });
                
                // Load danh sách IPs cho Allowed IPs dropdown
                ajaxGet("/api/wireguard/general/getFirewallIps", {}, function(data) {
                    if (data.ips) {
                        let select = $("#configbuilder\\.tunneladdress");
                        select.empty();
                        // Thêm option mặc định
                        select.append($('<option></option>').val("0.0.0.0/0,::/0").text("All traffic (0.0.0.0/0, ::/0)"));
                        data.ips.forEach(function(ip) {
                            select.append($('<option></option>').val(ip.value).text(ip.label));
                        });
                        select.selectpicker('refresh');
                    }
                });
                
                // Xử lý custom input cho Endpoint IP
                $("#configbuilder\\.endpoint_ip").on('changed.bs.select', function(e, clickedIndex, isSelected, previousValue) {
                    let selectedValue = $(this).val();
                    if (selectedValue === "" && isSelected) {
                        // Nếu chọn option trống, hiện prompt để nhập custom value
                        BootstrapDialog.show({
                            title: "{{ lang._('Enter Custom Endpoint IP') }}",
                            message: '<input type="text" class="form-control" id="custom_endpoint_ip" placeholder="Enter IP or hostname">',
                            buttons: [{
                                label: "{{ lang._('OK') }}",
                                action: function(dialog) {
                                    let customIp = $('#custom_endpoint_ip').val().trim();
                                    if (customIp) {
                                        // Thêm option mới và select nó
                                        let $select = $("#configbuilder\\.endpoint_ip");
                                        // Kiểm tra xem đã tồn tại chưa
                                        if ($select.find('option[value="' + customIp + '"]').length === 0) {
                                            $select.append($('<option></option>').val(customIp).text(customIp + ' (custom)'));
                                        }
                                        $select.val(customIp);
                                        $select.selectpicker('refresh');
                                        $select.change();
                                    } else {
                                        $("#configbuilder\\.endpoint_ip").val('');
                                        $("#configbuilder\\.endpoint_ip").selectpicker('refresh');
                                    }
                                    dialog.close();
                                }
                            }, {
                                label: "{{ lang._('Cancel') }}",
                                action: function(dialog) {
                                    $("#configbuilder\\.endpoint_ip").val(previousValue || '');
                                    $("#configbuilder\\.endpoint_ip").selectpicker('refresh');
                                    dialog.close();
                                }
                            }]
                        });
                    }
                });
                
                clearFormValidation("frm_config_builder");
            });
        }

        function configbuilder_update_config() {
            let rows = [];
            rows.push('[Interface]');
            rows.push('PrivateKey = ' + $("#configbuilder\\.privkey").val());
            if ($("#configbuilder\\.address").val()) {
                rows.push('Address = ' + $("#configbuilder\\.address").val());
            }
            if ($("#configbuilder\\.peer_dns").val()) {
                rows.push('DNS = ' + $("#configbuilder\\.peer_dns").val());
            }
            if ($("#configbuilder\\.endpoint_ip").data('mtu')) {
                rows.push('MTU = ' + $("#configbuilder\\.endpoint_ip").data('mtu'));
            }
            rows.push('');
            rows.push('[Peer]');
            rows.push('PublicKey = ' + $("#configbuilder\\.endpoint_ip").data('pubkey'));
            if ($("#configbuilder\\.psk").val()) {
                rows.push('PresharedKey = ' + $("#configbuilder\\.psk").val());
            }
            
            // Ghép endpoint từ IP và port
            let endpointIp = $("#configbuilder\\.endpoint_ip").val();
            let endpointPort = $("#configbuilder\\.endpoint_port").val() || '51820';
            if (endpointIp) {
                rows.push('Endpoint = ' + endpointIp + ':' + endpointPort);
            }
            
            rows.push('AllowedIPs = ' + $("#configbuilder\\.tunneladdress").val());
            if ($("#configbuilder\\.keepalive").val()) {
                rows.push('PersistentKeepalive = ' + $("#configbuilder\\.keepalive").val());
            }
            $("#configbuilder\\.output").val(rows.join("\n")).change();
        }

        $('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
            if (e.target.id == 'tab_configbuilder'){
                  // peer generator form needs populating
                  configbuilder_new();
              } else if (e.target.id == 'tab_peers') {
                  currentClientDialogMode = 's2s';
                  // regular peer list
                  $("#{{formGridWireguardClient['table_id']}}").bootgrid('reload');
              } else if (e.target.id == 'tab_clienttosite') {
                  currentClientDialogMode = 'c2s';
                  // client-to-site list
                  $("#{{formGridWireguardClientList['table_id']}}").bootgrid('reload');
            }
        });

        $('#tab_peers, #tab_clienttosite').off('click.wgClientMode').on('click.wgClientMode', function () {
            currentClientDialogMode = (this.id === 'tab_clienttosite') ? 'c2s' : 's2s';
        });

        // update history on tab state and implement navigation
        if(window.location.hash != "") {
            $('a[href="' + window.location.hash + '"]').click()
        }
          $('.nav-tabs a').on('shown.bs.tab', function (e) {
              history.pushState(null, null, e.target.hash);
              // reposition filter when viewing lists
              if (e.target.id === 'tab_peers' || e.target.id === 'tab_clienttosite') {
                  let tableId = (e.target.id === 'tab_peers') ? '{{formGridWireguardClient["table_id"]}}' : '{{formGridWireguardClientList["table_id"]}}';
                  $("#filter_container").detach().insertAfter('#' + tableId + '-header .search');
              }
          });
        $(window).on('hashchange', function(e) {
            $('a[href="' + window.location.hash + '"]').click()
        });
    });
</script>

<!-- Navigation bar -->
<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" id="tab_instances" href="#instances">{{ lang._('Instances') }}</a></li>
    <li><a data-toggle="tab" id="tab_peers" href="#peers">{{ lang._('Peers') }}</a></li>
      <li><a data-toggle="tab" id="tab_clienttosite" href="#clienttosite">{{ lang._('Client-to-site') }}</a></li>
    <li><a data-toggle="tab" id="tab_configbuilder" href="#configbuilder">{{ lang._('Peer generator') }}</a></li>
</ul>

<div class="tab-content content-box">
    <div id="peers" class="tab-pane fade">
        <span id="pskgen_div" style="display:none" class="pull-right">
            <button id="pskgen" type="button" class="btn btn-secondary" title="{{ lang._('Generate new psk.') }}" data-toggle="tooltip">
              <i class="fa fa-fw fa-gear"></i>
            </button>
        </span>
                <span id="keygen_client_div" style="display:none" class="pull-right">
                        <button id="keygen_client" type="button" class="btn btn-secondary" title="{{ lang._('Generate new keypair.') }}" data-toggle="tooltip">
                            <i class="fa fa-fw fa-gear"></i>
                        </button>
                </span>
        <div class="hidden">
            <!-- filter per server container -->
            <div id="filter_container" class="btn-group">
                <select id="server_filter" data-title="{{ lang._('Instances') }}" class="selectpicker" data-live-search="true" data-size="5" multiple data-width="200px">
                </select>
            </div>
        </div>
        {{ partial('layout_partials/base_bootgrid_table', formGridWireguardClient)}}
    </div>
    <div id="instances" class="tab-pane fade in active">
        <span id="keygen_div" style="display:none" class="pull-right">
            <button id="keygen" type="button" class="btn btn-secondary" title="{{ lang._('Generate new keypair.') }}" data-toggle="tooltip">
              <i class="fa fa-fw fa-gear"></i>
            </button>
        </span>
        {{ partial('layout_partials/base_bootgrid_table', formGridWireguardServer)}}
    </div>
    <div id="clienttosite" class="tab-pane fade">
        {{ partial('layout_partials/base_bootgrid_table', formGridWireguardClientList)}}
    </div>
    <div id="configbuilder" class="tab-pane fade">
        <span id="pskgen_cb_div" style="display:none" class="pull-right">
            <button id="pskgen_cb" type="button" class="btn btn-secondary" title="{{ lang._('Generate new psk.') }}" data-toggle="tooltip">
              <i class="fa fa-fw fa-gear"></i>
            </button>
        </span>
        <span id="configbuilder_div" style="display:none">
            <button id="btn_configbuilder_save" type="button" class="btn btn-primary">
                <i class="fa fa-fw fa-check"></i>
              </button>
        </span>
        {{ partial("layout_partials/base_form",['fields':formDialogConfigBuilder,'id':'frm_config_builder'])}}
    </div>
</div>
{{ partial("layout_partials/base_form",['fields':generalForm,'id':'frm_general_settings'])}}
{{ partial('layout_partials/base_apply_button', {'data_endpoint': '/api/wireguard/service/reconfigure'}) }}
{{ partial("layout_partials/base_dialog",['fields':formDialogEditWireguardClient,'id':formGridWireguardClient['edit_dialog_id'],'label':lang._('Edit client')])}}
{{ partial("layout_partials/base_dialog",['fields':formDialogEditWireguardServer,'id':formGridWireguardServer['edit_dialog_id'],'label':lang._('Edit instance')])}}
