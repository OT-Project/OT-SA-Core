#!/usr/local/bin/php
<?php

/*
 * Copyright (C) 2025 BKCSense
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

require_once("config.inc");
require_once("util.inc");

/**
 * Get shell language mode from config XML
 * @return string "vi" or "en" (default: "en")
 */
function get_shell_lang_mode()
{
    global $config;
    
    if (isset($config['system']['shell_lang_mode']) && 
        in_array($config['system']['shell_lang_mode'], ['vi', 'en'])) {
        return $config['system']['shell_lang_mode'];
    }
    
    // Default to "vi" if not set or invalid
    return 'vi';
}

/**
 * Set shell language mode in config XML
 * @param string $lang_mode "vi" or "en"
 * @return bool true on success, false on failure
 */
function set_shell_lang_mode($lang_mode)
{
    global $config;
    
    if (!in_array($lang_mode, ['vi', 'en'])) {
        return false;
    }
    
    $config['system']['shell_lang_mode'] = $lang_mode;
    write_config('Shell language mode changed from console');
    
    return true;
}

/**
 * Translation array for shell scripts
 */
$SHELL_TRANSLATIONS = [
    'vi' => [
        // Common
        'y/N' => 'c/K',
        'Y/n' => 'C/k',
        '[y/N]: ' => '[c/K]: ',
        '[Y/n]: ' => '[C/k]: ',
        'yes' => 'có',
        'no' => 'không',
        'done' => 'xong',
        'done.' => 'xong.',
        'Press ENTER to continue.' => 'Nhấn ENTER để tiếp tục.',
        'Press any key to return to menu.' => 'Nhấn phím bất kỳ để quay lại menu.',
        
        // ping.php
        'Enter a host name or IP address: ' => 'Nhập tên máy chủ hoặc địa chỉ IP: ',
        
        // password.php
        'user not found' => 'không tìm thấy người dùng',
        'new password for user %s:' => 'mật khẩu mới cho người dùng %s:',
        'empty password read' => 'mật khẩu đọc được trống',
        'The root user login behaviour will be restored to its defaults.' => 'Hành vi đăng nhập của người dùng root sẽ được khôi phục về mặc định.',
        'Do you want to proceed?' => 'Bạn có muốn tiếp tục không?',
        'The authentication server is set to "%s".' => 'Máy chủ xác thực đang được đặt là "%s".',
        'Do you want to set it back to Local Database?' => 'Bạn có muốn đặt lại về Cơ sở dữ liệu cục bộ không?',
        'Restored missing root user.' => 'Đã khôi phục người dùng root bị thiếu.',
        'Type a new password: ' => 'Nhập mật khẩu mới: ',
        'Confirm new password: ' => 'Xác nhận mật khẩu mới: ',
        'Password cannot be empty.' => 'Mật khẩu không được để trống.',
        'Passwords do not match.' => 'Mật khẩu không khớp.',
        'The root user has been reset successfully.' => 'Đã đặt lại người dùng root thành công.',
        
        // defaults.php
        'You are about to reset the firewall to factory defaults.' => 'Bạn sắp đặt lại tường lửa về mặc định ban đầu.',
        'The firewall will shut down directly after completion.' => 'Tường lửa sẽ tắt ngay sau khi hoàn tất.',
        
        // halt.php
        'The system will halt and power off. Do you want to proceed?' => 'Hệ thống sẽ dừng và tắt nguồn. Bạn có muốn tiếp tục không?',
        
        // reboot.php
        'The system will reboot. Do you want to proceed?' => 'Hệ thống sẽ khởi động lại. Bạn có muốn tiếp tục không?',
        
        // banner.php
        'No network interfaces are assigned.' => 'Không có cổng mạng nào được gán.',
        
        // setaddr.php
        'Available interfaces:' => 'Các cổng mạng khả dụng:',
        'Enter the number of the interface to configure: ' => 'Nhập số thứ tự cổng mạng cần cấu hình: ',
        'Invalid interface!' => 'Cổng mạng không hợp lệ!',
        'Do you want to enable the %s server on %s?' => 'Bạn có muốn bật máy chủ %s trên %s không?',
        'Configure %s address %s interface via %s?' => 'Cấu hình địa chỉ %s cho cổng %s qua %s?',
        'Configure %s address %s interface via WAN tracking?' => 'Cấu hình địa chỉ %s cho cổng %s qua theo dõi WAN?',
        'Enter the new %s %s address. Press <ENTER> for none:' => 'Nhập địa chỉ %s %s mới. Nhấn <ENTER> để bỏ qua:',
        'This IP address conflicts with another interface or a VIP' => 'Địa chỉ IP này xung đột với cổng mạng khác hoặc VIP',
        'Subnet masks are entered as bit counts (like CIDR notation).' => 'Mặt nạ mạng được nhập dưới dạng số bit (như ký hiệu CIDR).',
        'Enter the new %s %s subnet bit count (1 to %s):' => 'Nhập số bit mặt nạ mạng %s %s mới (1 đến %s):',
        'You cannot set network address to an interface' => 'Bạn không thể đặt địa chỉ mạng cho cổng',
        'You cannot set broadcast address to an interface' => 'Bạn không thể đặt địa chỉ broadcast cho cổng',
        'For a WAN, enter the new %s %s upstream gateway address.' => 'Đối với WAN, nhập địa chỉ gateway %s %s mới.',
        'For a LAN, press <ENTER> for none:' => 'Đối với LAN, nhấn <ENTER> để bỏ qua:',
        'Not an %s address!' => 'Không phải địa chỉ %s!',
        'Do you want to use it as the default %s gateway?' => 'Bạn có muốn sử dụng nó làm gateway %s mặc định không?',
        'Do you want to use the gateway as the %s name server, too?' => 'Bạn có muốn sử dụng gateway làm máy chủ DNS %s không?',
        'Enter the %s name server or press <ENTER> for none:' => 'Nhập máy chủ DNS %s hoặc nhấn <ENTER> để bỏ qua:',
        'Enter the start address of the %s client address range:' => 'Nhập địa chỉ bắt đầu của dải địa chỉ %s:',
        'Enter the end address of the %s client address range:' => 'Nhập địa chỉ kết thúc của dải địa chỉ %s:',
        "This IP address must be in the interface's subnet" => 'Địa chỉ IP này phải nằm trong mạng con của cổng',
        'The end address of the DHCP range must be >= the start address' => 'Địa chỉ kết thúc của dải DHCP phải >= địa chỉ bắt đầu',
        'Do you want to change the web GUI protocol from HTTPS to HTTP?' => 'Bạn có muốn thay đổi giao thức web GUI từ HTTPS sang HTTP không?',
        'Do you want to generate a new self-signed web GUI certificate?' => 'Bạn có muốn tạo chứng chỉ web GUI tự ký mới không?',
        'Restore web GUI access defaults?' => 'Khôi phục mặc định truy cập web GUI?',
        'Writing configuration...' => 'Đang ghi cấu hình...',
        'You can now access the web GUI by opening' => 'Bây giờ bạn có thể truy cập web GUI bằng cách mở',
        'the following URL in your web browser:' => 'URL sau trong trình duyệt web của bạn:',
        
        // firmware.sh
        'Fetching change log information, please wait... ' => 'Đang tải thông tin thay đổi, vui lòng chờ... ',
        'This will automatically fetch all available updates and apply them.' => 'Thao tác này sẽ tự động tải và áp dụng tất cả bản cập nhật có sẵn.',
        'A major firmware upgrade is available for this installation: %s' => 'Có bản nâng cấp firmware chính cho cài đặt này: %s',
        'Make sure you have read the release notes and migration guide before' => 'Đảm bảo bạn đã đọc ghi chú phát hành và hướng dẫn di chuyển trước',
        'attempting this upgrade.  Approx. 1000MB will need to be downloaded and' => 'khi thực hiện nâng cấp này. Khoảng 1000MB cần tải xuống và',
        'require 2000MB of free space to unpack.  Continue with this major upgrade' => 'yêu cầu 2000MB dung lượng trống để giải nén. Tiếp tục nâng cấp chính',
        'by typing the major upgrade version number displayed above.' => 'bằng cách nhập số phiên bản nâng cấp hiển thị ở trên.',
        'Minor updates may be available, answer \'y\' to run them instead.' => 'Có thể có bản cập nhật nhỏ, trả lời \'c\' để chạy chúng thay thế.',
        'This update requires a reboot.' => 'Bản cập nhật này yêu cầu khởi động lại.',
        'Proceed with this action?' => 'Tiến hành thao tác này?',
        'A firmware action is currently in progress.' => 'Một thao tác firmware đang được thực hiện.',
        
        // restore.sh
        'No backups available.' => 'Không có bản sao lưu nào.',
        'Select backup to restore or leave blank to exit: ' => 'Chọn bản sao lưu để khôi phục hoặc để trống để thoát: ',
        'Do you want to reboot to apply the backup cleanly?' => 'Bạn có muốn khởi động lại để áp dụng bản sao lưu?',
        
        // console.inc - Interface assignment
        'Press any key to start the manual interface assignment: ' => 'Nhấn phím bất kỳ để bắt đầu gán cổng mạng thủ công: ',
        'Do you want to configure LAGGs now?' => 'Bạn có muốn cấu hình LAGG ngay bây giờ không?',
        'Do you want to configure VLANs now?' => 'Bạn có muốn cấu hình VLAN ngay bây giờ không?',
        'Valid interfaces are:' => 'Các cổng mạng hợp lệ:',
        'No interfaces found!' => 'Không tìm thấy cổng mạng nào!',
        'If you do not know the names of your interfaces, you may choose to use' => 'Nếu bạn không biết tên các cổng mạng, bạn có thể chọn sử dụng',
        'auto-detection. In that case, disconnect all interfaces now before' => 'tự động phát hiện. Trong trường hợp đó, hãy ngắt kết nối tất cả các cổng mạng trước',
        "hitting 'a' to initiate auto detection." => "khi nhấn 'a' để bắt đầu tự động phát hiện.",
        "Enter the WAN interface name or 'a' for auto-detection: " => "Nhập tên cổng WAN hoặc 'a' để tự động phát hiện: ",
        "Invalid interface name '%s'" => "Tên cổng mạng không hợp lệ '%s'",
        "Enter the LAN interface name or 'a' for auto-detection" => "Nhập tên cổng LAN hoặc 'a' để tự động phát hiện",
        'NOTE: this enables full Firewalling/NAT mode.' => 'LƯU Ý: điều này bật chế độ Tường lửa/NAT đầy đủ.',
        '(or nothing if finished): ' => '(hoặc để trống nếu hoàn tất): ',
        "Enter the Optional interface %s name or 'a' for auto-detection" => "Nhập tên cổng Tùy chọn %s hoặc 'a' để tự động phát hiện",
        'Error: you cannot assign the same interface name twice!' => 'Lỗi: bạn không thể gán cùng một tên cổng mạng hai lần!',
        'The interfaces will be assigned as follows:' => 'Các cổng mạng sẽ được gán như sau:',
        'No interfaces will be assigned!' => 'Không có cổng mạng nào được gán!',
        'Connect the %s interface now and make sure that the link is up.' => 'Kết nối cổng %s ngay bây giờ và đảm bảo đường link đã lên.',
        'Then press ENTER to continue.' => 'Sau đó nhấn ENTER để tiếp tục.',
        'Detected link-up: %s' => 'Phát hiện link-up: %s',
        'No link-up detected.' => 'Không phát hiện link-up.',
        
        // console.inc - LAGG setup
        'WARNING: all existing LAGGs will be cleared if you proceed!' => 'CẢNH BÁO: tất cả LAGG hiện có sẽ bị xóa nếu bạn tiếp tục!',
        'LAGG-capable interfaces:' => 'Các cổng mạng hỗ trợ LAGG:',
        'No LAGG-capable interfaces detected.' => 'Không phát hiện cổng mạng hỗ trợ LAGG.',
        'Enter the LAGG members to aggregate (or nothing if finished): ' => 'Nhập các thành viên LAGG để tổng hợp (hoặc để trống nếu hoàn tất): ',
        'Invalid interfaces: %s' => 'Cổng mạng không hợp lệ: %s',
        'Enter the LAGG protocol (default:none,lacp,failover,fec,loadbalance,roundrobin): ' => 'Nhập giao thức LAGG (mặc định:none,lacp,failover,fec,loadbalance,roundrobin): ',
        'Do you want to enable LACP fast timeout?' => 'Bạn có muốn bật LACP fast timeout không?',
        'Enter the LAGG MTU (leave blank for auto): ' => 'Nhập MTU LAGG (để trống để tự động): ',
        
        // console.inc - VLAN setup
        'WARNING: all existing VLANs will be cleared if you proceed!' => 'CẢNH BÁO: tất cả VLAN hiện có sẽ bị xóa nếu bạn tiếp tục!',
        'VLAN-capable interfaces:' => 'Các cổng mạng hỗ trợ VLAN:',
        'Enter the parent interface name for the new VLAN (or nothing if finished): ' => 'Nhập tên cổng cha cho VLAN mới (hoặc để trống nếu hoàn tất): ',
        'Enter the VLAN tag (1-4094): ' => 'Nhập tag VLAN (1-4094): ',
        "Invalid VLAN tag '%s'" => "Tag VLAN không hợp lệ '%s'",
    ]
];

/**
 * Translation helper function
 * @param string $key The text to translate
 * @param mixed ...$args Optional sprintf arguments
 * @return string Translated text or original if no translation found
 */
function __($key, ...$args)
{
    global $SHELL_TRANSLATIONS;
    $lang = get_shell_lang_mode();
    
    if ($lang === 'vi' && isset($SHELL_TRANSLATIONS['vi'][$key])) {
        $text = $SHELL_TRANSLATIONS['vi'][$key];
    } else {
        $text = $key;
    }
    
    return empty($args) ? $text : sprintf($text, ...$args);
}

/**
 * Get yes/no input based on language
 * @param string $input User input
 * @return string Normalized input ('y' or 'n')
 */
function normalize_yes_no($input)
{
    $input = strtolower(trim($input));
    // Vietnamese: c = có (yes), k = không (no)
    if ($input === 'c' || $input === 'có') {
        return 'y';
    }
    if ($input === 'k' || $input === 'không') {
        return 'n';
    }
    return $input;
}

// Command line interface - only run when this file is executed directly
if (php_sapi_name() === 'cli' && isset($argv[0]) && basename($argv[0]) === 'langmode.php') {
    if (isset($argv[1])) {
        $action = $argv[1];
        
        switch ($action) {
            case 'get':
                echo get_shell_lang_mode() . "\n";
                exit(0);
                break;
                
            case 'set':
                if (!isset($argv[2])) {
                    echo "Usage: {$argv[0]} set <vi|en>\n";
                    exit(1);
                }
                
                $lang_mode = $argv[2];
                if (set_shell_lang_mode($lang_mode)) {
                    echo "Language mode set to: {$lang_mode}\n";
                    exit(0);
                } else {
                    echo "Error: Invalid language mode. Use 'vi' or 'en'.\n";
                    exit(1);
                }
                break;
                
            case 'toggle':
                $current = get_shell_lang_mode();
                $new = ($current === 'vi') ? 'en' : 'vi';
                
                if (set_shell_lang_mode($new)) {
                    echo $new . "\n";
                    exit(0);
                } else {
                    echo "Error: Failed to toggle language mode.\n";
                    exit(1);
                }
                break;
                
            default:
                echo "Usage: {$argv[0]} <get|set|toggle> [lang_mode]\n";
                exit(1);
        }
    } else {
        echo "Usage: {$argv[0]} <get|set|toggle> [lang_mode]\n";
        exit(1);
    }
}

