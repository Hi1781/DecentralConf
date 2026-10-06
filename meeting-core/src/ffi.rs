//! C ABI（供 iOS / Android 原生侧调用）。
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::thread;

use crate::run_room;

/// 事件回调类型：把一行事件文本（UTF-8，C 字符串）回传给原生层。
pub type MeetingLogCb = extern "C" fn(*const c_char);

/// 启动一个去中心化会议室（后台线程，无中央服务器）。
/// 成功返回 0，参数为空返回 1。
#[no_mangle]
pub extern "C" fn oneapp_meeting_start(
    room: *const c_char,
    nick: *const c_char,
    cb: MeetingLogCb,
) -> i32 {
    if room.is_null() || nick.is_null() {
        return 1;
    }
    let room = unsafe { CStr::from_ptr(room) }
        .to_str()
        .unwrap_or("oneapp")
        .to_string();
    let nick = unsafe { CStr::from_ptr(nick) }
        .to_str()
        .unwrap_or("guest")
        .to_string();

    thread::spawn(move || {
        let rt = match tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
        {
            Ok(rt) => rt,
            Err(_) => return,
        };
        rt.block_on(async move {
            let _ = run_room(room, nick, move |line| {
                if let Ok(c) = CString::new(line) {
                    cb(c.as_ptr());
                }
            })
            .await;
        });
    });
    0
}

/// 返回核心版本号。
#[no_mangle]
pub extern "C" fn oneapp_meeting_version() -> *mut c_char {
    let c = CString::new(crate::VERSION).unwrap_or_default();
    c.into_raw()
}

/// 释放 oneapp_meeting_version 返回的字符串。
#[no_mangle]
pub extern "C" fn oneapp_meeting_str_free(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            drop(CString::from_raw(s));
        }
    }
}
