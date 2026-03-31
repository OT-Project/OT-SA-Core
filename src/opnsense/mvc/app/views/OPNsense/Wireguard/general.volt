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
                    if ($('#server_filter').val().length > 0) {
                        request['servers'] = $('#server_filter').val();
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

        /**
         * Quick instance filter on top
         */
        $("#filter_container").detach().insertAfter('#{{formGridWireguardClient["table_id"]}}-header .search');
        $("#server_filter").change(function(){
            $('#{{formGridWireguardClient['table_id']}}').bootgrid('reload');
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
                            $('#{{formGridWireguardClient['table_id']}}').bootgrid('reload');
                            configbuilder_new();
                        });
                    } else {
                        // Reload tab peers để hiển thị cấu hình mới
                        $('#{{formGridWireguardClient['table_id']}}').bootgrid('reload');
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
                configbuilder_new();
            } else if (e.target.id == 'tab_peers') {
                $('#{{formGridWireguardClient['table_id']}}').bootgrid('reload');
            } else if (e.target.id == 'tab_instances') {
                $('#{{formGridWireguardServer['table_id']}}').bootgrid('reload');
            }
        });

        // update history on tab state and implement navigation
        if(window.location.hash != "") {
            $('a[href="' + window.location.hash + '"]').click()
        }
        $('.nav-tabs a').on('shown.bs.tab', function (e) {
            history.pushState(null, null, e.target.hash);
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
    <li><a data-toggle="tab" id="tab_configbuilder" href="#configbuilder">{{ lang._('Peer generator') }}</a></li>
</ul>

<div class="tab-content content-box tab-content">
    <div id="peers" class="tab-pane fade in">
        <span id="pskgen_div" style="display:none" class="pull-right">
            <button id="pskgen" type="button" class="btn btn-secondary" title="{{ lang._('Generate new psk.') }}" data-toggle="tooltip">
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
    <div id="configbuilder" class="tab-pane fade in">
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
    {{ partial("layout_partials/base_form",['fields':generalForm,'id':'frm_general_settings'])}}
</div>
{{ partial('layout_partials/base_apply_button', {'data_endpoint': '/api/wireguard/service/reconfigure'}) }}
{{ partial("layout_partials/base_dialog",['fields':formDialogEditWireguardClient,'id':formGridWireguardClient['edit_dialog_id'],'label':lang._('Edit peer')])}}
{{ partial("layout_partials/base_dialog",['fields':formDialogEditWireguardServer,'id':formGridWireguardServer['edit_dialog_id'],'label':lang._('Edit instance')])}}