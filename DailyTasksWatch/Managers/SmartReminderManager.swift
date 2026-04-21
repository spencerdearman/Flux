//
//  SmartReminderManager.swift
//  DailyTasks Watch App
//
//  Created by Spencer Dearman.
//

import Foundation
import UserNotifications

struct SmartReminderManager {
    static func scheduleSmartReminder(total: Int, remaining: Int) {
        let center = UNUserNotificationCenter.current()
        let identifier = "smart_reminder"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        if remaining <= 0 || total == 0 {