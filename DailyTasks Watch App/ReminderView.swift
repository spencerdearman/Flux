//
//  ReminderView.swift
//  DailyTasks
//
//  Created by Spencer Dearman on 4/13/26.
//

import SwiftUI

struct ReminderView: View {
    @State var smartRemindersEnabled: Bool = false
    @State var dailyRemindersEnabled: Bool = false
    @State private var selectedTime = Date.now
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $smartRemindersEnabled) {
                        Text("Smart Reminders")
                    }
                    .tint(.accentColor)
                } footer: {
                    Text("Get nudged when you still have tasks left after checking one off.")
                }
                
                Section {
                    Toggle(isOn: $dailyRemindersEnabled) {
                        Text("Daily Reminders")
                    }
                    .tint(.accentColor)
                    
                    if dailyRemindersEnabled {
                        NavigationLink {
                            DatePicker(
                                "Time",
                                selection: $selectedTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .navigationTitle("Time")
                            .tint(.orange)
                        } label: {
                            HStack {
                                Text("Select Time")
                                Spacer()
                                Text(selectedTime, style: .time)
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
        }
    }
}
