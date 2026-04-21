//
//  TasksCompleteView.swift
//  DailyTasks
//
//  Created by Spencer Dearman on 4/20/26.
//


import SwiftUI
import SwiftData

struct TasksCompleteView: View {
    var totalTasks: Int
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Standard 100% ProgressView scaled accurately
                ProgressView(value: 1.0)
                    .progressViewStyle(.circular)
                    .tint(.accentColor)
                    .glassEffect()
                    .scaleEffect(1.7)
                
                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 90, height: 90)
            .padding(6)
            
            Text("All Done")
                .font(.headline)
                .bold()
                .foregroundColor(.white)
            
            Text("\(totalTasks) tasks completed")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}